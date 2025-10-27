//
//  DocumentChunk.swift
//  AIAdventChatV2
//
//  Vector search: Document chunk with embedding
//

import Foundation

// MARK: - Document Chunk Model

struct DocumentChunk: Identifiable, Codable {
    let id: String
    let filePath: String
    let fileName: String
    let content: String
    let chunkIndex: Int
    let embedding: [Double]?
    let metadata: ChunkMetadata
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        filePath: String,
        fileName: String,
        content: String,
        chunkIndex: Int,
        embedding: [Double]? = nil,
        metadata: ChunkMetadata,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filePath = filePath
        self.fileName = fileName
        self.content = content
        self.chunkIndex = chunkIndex
        self.embedding = embedding
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// MARK: - Chunk Metadata

struct ChunkMetadata: Codable {
    let fileType: FileType
    let startLine: Int?
    let endLine: Int?
    let tokenCount: Int
    let language: String?

    enum FileType: String, Codable {
        case swift
        case markdown
        case text
        case pdf
        case code
        case documentation
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable {
    let id: String
    let chunk: DocumentChunk
    let similarity: Double
    let rank: Int

    var preview: String {
        // Clean up whitespace and newlines
        let cleanedContent = chunk.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let maxLength = 200
        if cleanedContent.count > maxLength {
            return String(cleanedContent.prefix(maxLength)) + "..."
        }
        return cleanedContent
    }
}

// MARK: - Indexing Statistics

struct IndexingStatistics {
    var totalDocuments: Int = 0
    var totalChunks: Int = 0
    var indexedFiles: [String] = []
    var failedFiles: [String] = []
    var processingTime: TimeInterval = 0

    mutating func addSuccess(file: String, chunks: Int) {
        totalDocuments += 1
        totalChunks += chunks
        indexedFiles.append(file)
    }

    mutating func addFailure(file: String) {
        failedFiles.append(file)
    }
}
