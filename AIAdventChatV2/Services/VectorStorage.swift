//
//  VectorStorage.swift
//  AIAdventChatV2
//
//  SQLite-based vector storage for document embeddings
//

import Foundation
import SQLite3

// MARK: - Vector Storage

class VectorStorage {

    enum StorageError: Error {
        case databaseError(String)
        case serializationError
        case notFound
        case invalidData
    }

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.aiadventchat.vectorstorage", qos: .userInitiated)
    private let dbPath: String

    // MARK: - Init

    init(databasePath: String? = nil) {
        if let path = databasePath {
            self.dbPath = path
        } else {
            // Use default path in Application Support
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDirectory = appSupport.appendingPathComponent("AIAdventChatV2", isDirectory: true)

            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

            self.dbPath = appDirectory.appendingPathComponent("vectors.db").path
        }
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Management

    func openDatabase() throws {
        var db: OpaquePointer?

        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            self.db = db
            try createTables()
        } else {
            throw StorageError.databaseError("Failed to open database at \(dbPath)")
        }
    }

    func closeDatabase() {
        dbQueue.sync {
            if let db = db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    private func createTables() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS document_chunks (
            id TEXT PRIMARY KEY,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            content TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            embedding BLOB,
            file_type TEXT NOT NULL,
            start_line INTEGER,
            end_line INTEGER,
            token_count INTEGER NOT NULL,
            language TEXT,
            created_at REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_file_path ON document_chunks(file_path);
        CREATE INDEX IF NOT EXISTS idx_file_name ON document_chunks(file_name);
        CREATE INDEX IF NOT EXISTS idx_created_at ON document_chunks(created_at);
        """

        try dbQueue.sync {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, createTableSQL, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to create tables: \(error)")
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to execute table creation: \(error)")
            }
        }
    }

    // MARK: - Storage Operations

    /// Store a single document chunk
    func storeChunk(_ chunk: DocumentChunk) throws {
        let insertSQL = """
        INSERT OR REPLACE INTO document_chunks
        (id, file_path, file_name, content, chunk_index, embedding, file_type, start_line, end_line, token_count, language, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        try dbQueue.sync {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to prepare insert: \(error)")
            }

            // Bind parameters
            sqlite3_bind_text(statement, 1, (chunk.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (chunk.filePath as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (chunk.fileName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (chunk.content as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 5, Int32(chunk.chunkIndex))

            // Serialize embedding as BLOB
            if let embedding = chunk.embedding {
                let embeddingData = try serializeEmbedding(embedding)
                embeddingData.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, 6, bytes.baseAddress, Int32(embeddingData.count), nil)
                }
            } else {
                sqlite3_bind_null(statement, 6)
            }

            sqlite3_bind_text(statement, 7, (chunk.metadata.fileType.rawValue as NSString).utf8String, -1, nil)

            if let startLine = chunk.metadata.startLine {
                sqlite3_bind_int(statement, 8, Int32(startLine))
            } else {
                sqlite3_bind_null(statement, 8)
            }

            if let endLine = chunk.metadata.endLine {
                sqlite3_bind_int(statement, 9, Int32(endLine))
            } else {
                sqlite3_bind_null(statement, 9)
            }

            sqlite3_bind_int(statement, 10, Int32(chunk.metadata.tokenCount))

            if let language = chunk.metadata.language {
                sqlite3_bind_text(statement, 11, (language as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 11)
            }

            sqlite3_bind_double(statement, 12, chunk.createdAt.timeIntervalSince1970)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to insert chunk: \(error)")
            }
        }
    }

    /// Store multiple chunks (batch operation)
    func storeChunks(_ chunks: [DocumentChunk]) throws {
        for chunk in chunks {
            try storeChunk(chunk)
        }
    }

    /// Retrieve all chunks
    func getAllChunks() throws -> [DocumentChunk] {
        let selectSQL = "SELECT * FROM document_chunks ORDER BY file_path, chunk_index;"

        return try dbQueue.sync {
            var chunks: [DocumentChunk] = []
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to prepare select: \(error)")
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                let chunk = try parseChunkFromRow(statement!)
                chunks.append(chunk)
            }

            return chunks
        }
    }

    /// Retrieve chunks by file path
    func getChunks(forFile filePath: String) throws -> [DocumentChunk] {
        let selectSQL = "SELECT * FROM document_chunks WHERE file_path = ? ORDER BY chunk_index;"

        return try dbQueue.sync {
            var chunks: [DocumentChunk] = []
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to prepare select: \(error)")
            }

            sqlite3_bind_text(statement, 1, (filePath as NSString).utf8String, -1, nil)

            while sqlite3_step(statement) == SQLITE_ROW {
                let chunk = try parseChunkFromRow(statement!)
                chunks.append(chunk)
            }

            return chunks
        }
    }

    /// Delete all chunks for a specific file
    func deleteChunks(forFile filePath: String) throws {
        let deleteSQL = "DELETE FROM document_chunks WHERE file_path = ?;"

        try dbQueue.sync {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to prepare delete: \(error)")
            }

            sqlite3_bind_text(statement, 1, (filePath as NSString).utf8String, -1, nil)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to delete chunks: \(error)")
            }
        }
    }

    /// Clear all chunks from database
    func clearAll() throws {
        let deleteSQL = "DELETE FROM document_chunks;"

        try dbQueue.sync {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to prepare clear: \(error)")
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to clear database: \(error)")
            }
        }
    }

    /// Get statistics about stored chunks
    func getStatistics() throws -> IndexingStatistics {
        let statsSQL = """
        SELECT
            COUNT(DISTINCT file_path) as file_count,
            COUNT(*) as chunk_count
        FROM document_chunks;
        """

        return try dbQueue.sync {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, statsSQL, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StorageError.databaseError("Failed to prepare stats query: \(error)")
            }

            var stats = IndexingStatistics()

            if sqlite3_step(statement) == SQLITE_ROW {
                stats.totalDocuments = Int(sqlite3_column_int(statement, 0))
                stats.totalChunks = Int(sqlite3_column_int(statement, 1))
            }

            return stats
        }
    }

    // MARK: - Private Helpers

    private func parseChunkFromRow(_ statement: OpaquePointer) throws -> DocumentChunk {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let filePath = String(cString: sqlite3_column_text(statement, 1))
        let fileName = String(cString: sqlite3_column_text(statement, 2))
        let content = String(cString: sqlite3_column_text(statement, 3))
        let chunkIndex = Int(sqlite3_column_int(statement, 4))

        // Deserialize embedding
        var embedding: [Double]?
        if let blobPointer = sqlite3_column_blob(statement, 5) {
            let blobSize = Int(sqlite3_column_bytes(statement, 5))
            let data = Data(bytes: blobPointer, count: blobSize)
            embedding = try deserializeEmbedding(data)
        }

        let fileTypeRaw = String(cString: sqlite3_column_text(statement, 6))
        let fileType = ChunkMetadata.FileType(rawValue: fileTypeRaw) ?? .text

        let startLine: Int? = sqlite3_column_type(statement, 7) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 7)) : nil
        let endLine: Int? = sqlite3_column_type(statement, 8) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 8)) : nil
        let tokenCount = Int(sqlite3_column_int(statement, 9))

        let language: String? = sqlite3_column_type(statement, 10) != SQLITE_NULL ? String(cString: sqlite3_column_text(statement, 10)) : nil

        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 11))

        let metadata = ChunkMetadata(
            fileType: fileType,
            startLine: startLine,
            endLine: endLine,
            tokenCount: tokenCount,
            language: language
        )

        return DocumentChunk(
            id: id,
            filePath: filePath,
            fileName: fileName,
            content: content,
            chunkIndex: chunkIndex,
            embedding: embedding,
            metadata: metadata,
            createdAt: createdAt
        )
    }

    private func serializeEmbedding(_ embedding: [Double]) throws -> Data {
        var data = Data()
        for value in embedding {
            var val = value
            data.append(Data(bytes: &val, count: MemoryLayout<Double>.size))
        }
        return data
    }

    private func deserializeEmbedding(_ data: Data) throws -> [Double] {
        let count = data.count / MemoryLayout<Double>.size
        var embedding: [Double] = []

        for i in 0..<count {
            let start = i * MemoryLayout<Double>.size
            let end = start + MemoryLayout<Double>.size
            let slice = data[start..<end]
            let value = slice.withUnsafeBytes { $0.load(as: Double.self) }
            embedding.append(value)
        }

        return embedding
    }
}
