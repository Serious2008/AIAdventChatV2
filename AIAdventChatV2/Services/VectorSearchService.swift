//
//  VectorSearchService.swift
//  AIAdventChatV2
//
//  Main service combining all vector search components
//

import Foundation

// MARK: - Vector Search Service

class VectorSearchService {

    enum SearchError: Error {
        case notInitialized
        case indexingFailed(String)
        case searchFailed(String)
    }

    private let textExtractor: TextExtractor
    private let textChunker: TextChunker
    private let embeddingService: EmbeddingService
    private let vectorStorage: VectorStorage

    private var isInitialized = false

    // MARK: - Init

    init(apiKey: String, databasePath: String? = nil) {
        self.textExtractor = TextExtractor()
        self.textChunker = TextChunker(config: .default)
        self.embeddingService = EmbeddingService(apiKey: apiKey)
        self.vectorStorage = VectorStorage(databasePath: databasePath)
    }

    // MARK: - Initialization

    func initialize() throws {
        try vectorStorage.openDatabase()
        isInitialized = true
    }

    func shutdown() {
        vectorStorage.closeDatabase()
        isInitialized = false
    }

    // MARK: - Document Indexing

    /// Index a single document file
    func indexDocument(at filePath: String, progressCallback: ((String) -> Void)? = nil) async throws -> Int {
        guard isInitialized else {
            throw SearchError.notInitialized
        }

        progressCallback?("Extracting text from \(filePath)...")

        // Step 1: Extract text
        let extractedText = try await textExtractor.extractText(from: filePath)

        progressCallback?("Chunking text (\(extractedText.wordCount) words)...")

        // Step 2: Chunk text with appropriate config for file type
        let chunkConfig: TextChunker.ChunkingConfig
        switch extractedText.metadata.format {
        case .swift, .json, .xml, .html:
            chunkConfig = .code  // Larger chunks for code
        default:
            chunkConfig = .default
        }

        let chunker = TextChunker(config: chunkConfig)
        let chunks = chunker.chunkDocument(extractedText)

        progressCallback?("Generating embeddings for \(chunks.count) chunks...")

        // Step 3: Generate embeddings
        let chunksWithEmbeddings = try await embeddingService.generateEmbeddings(for: chunks)

        progressCallback?("Storing chunks in database...")

        // Step 4: Store in database
        try vectorStorage.storeChunks(chunksWithEmbeddings)

        progressCallback?("✅ Indexed \(chunks.count) chunks from \(filePath)")

        return chunks.count
    }

    /// Index multiple documents
    func indexDocuments(at filePaths: [String], progressCallback: ((String, Int, Int) -> Void)? = nil) async throws -> IndexingStatistics {
        var statistics = IndexingStatistics()
        let startTime = Date()

        for (index, filePath) in filePaths.enumerated() {
            progressCallback?(filePath, index + 1, filePaths.count)

            do {
                let chunkCount = try await indexDocument(at: filePath) { progress in
                    // Individual file progress can be logged if needed
                }
                statistics.addSuccess(file: filePath, chunks: chunkCount)
            } catch {
                print("⚠️ Failed to index \(filePath): \(error)")
                statistics.addFailure(file: filePath)
            }
        }

        statistics.processingTime = Date().timeIntervalSince(startTime)

        return statistics
    }

    /// Index all files in a directory
    func indexDirectory(at directoryPath: String, fileExtensions: [String] = ["swift", "md", "txt"], progressCallback: ((String, Int, Int) -> Void)? = nil) async throws -> IndexingStatistics {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directoryPath)

        var filePaths: [String] = []

        // Directories to skip
        let skipDirectories: Set<String> = [".build", ".git", "build", "DerivedData", "Pods", "node_modules"]

        // Recursively find all matching files
        if let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                // Check if it's a directory we should skip
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                   resourceValues.isDirectory == true {
                    let dirName = fileURL.lastPathComponent
                    if skipDirectories.contains(dirName) {
                        enumerator.skipDescendants()
                        continue
                    }
                }

                // Check file extension
                if fileExtensions.contains(fileURL.pathExtension.lowercased()) {
                    filePaths.append(fileURL.path)
                }
            }
        }

        print("📁 Found \(filePaths.count) files to index in \(directoryPath)")

        return try await indexDocuments(at: filePaths, progressCallback: progressCallback)
    }

    // MARK: - Search Operations

    /// Search for similar chunks using query text
    func search(query: String, topK: Int = 5) async throws -> [SearchResult] {
        guard isInitialized else {
            throw SearchError.notInitialized
        }

        // Step 1: Generate query embedding
        let queryEmbedding = try await embeddingService.generateQueryEmbedding(for: query)

        // Step 2: Get all chunks from database
        let allChunks = try vectorStorage.getAllChunks()

        guard !allChunks.isEmpty else {
            return []
        }

        // Step 3: Calculate similarity for each chunk
        var results: [(chunk: DocumentChunk, similarity: Double)] = []

        for chunk in allChunks {
            guard let chunkEmbedding = chunk.embedding else {
                continue
            }

            let similarity = EmbeddingService.cosineSimilarity(queryEmbedding, chunkEmbedding)
            results.append((chunk: chunk, similarity: similarity))
        }

        // Step 4: Sort by similarity and take top K
        results.sort { $0.similarity > $1.similarity }
        let topResults = results.prefix(topK)

        // Step 5: Create SearchResult objects
        return topResults.enumerated().map { index, result in
            SearchResult(
                id: result.chunk.id + "_\(index)",
                chunk: result.chunk,
                similarity: result.similarity,
                rank: index + 1
            )
        }
    }

    /// Search with filtering by file type
    func search(query: String, fileType: ChunkMetadata.FileType, topK: Int = 5) async throws -> [SearchResult] {
        let allResults = try await search(query: query, topK: topK * 2)

        let filtered = allResults.filter { $0.chunk.metadata.fileType == fileType }

        return Array(filtered.prefix(topK))
    }

    // MARK: - Management Operations

    /// Remove all indexed documents
    func clearIndex() throws {
        guard isInitialized else {
            throw SearchError.notInitialized
        }

        try vectorStorage.clearAll()
    }

    /// Remove chunks for a specific file
    func removeDocument(at filePath: String) throws {
        guard isInitialized else {
            throw SearchError.notInitialized
        }

        try vectorStorage.deleteChunks(forFile: filePath)
    }

    /// Get statistics about indexed documents
    func getStatistics() throws -> IndexingStatistics {
        guard isInitialized else {
            throw SearchError.notInitialized
        }

        return try vectorStorage.getStatistics()
    }

    /// Get all chunks for a specific file
    func getChunks(forFile filePath: String) throws -> [DocumentChunk] {
        guard isInitialized else {
            throw SearchError.notInitialized
        }

        return try vectorStorage.getChunks(forFile: filePath)
    }
}

// MARK: - Convenience Extensions

extension VectorSearchService {

    /// Index common project files
    func indexProjectDocumentation(projectPath: String, progressCallback: ((String, Int, Int) -> Void)? = nil) async throws -> IndexingStatistics {
        let commonDocs = [
            "README.md",
            "CHANGELOG.md",
            "CONTRIBUTING.md",
            "LICENSE.md",
            "docs/"
        ]

        var filePaths: [String] = []
        let fileManager = FileManager.default

        for docPath in commonDocs {
            let fullPath = (projectPath as NSString).appendingPathComponent(docPath)

            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Index directory
                    let stats = try await indexDirectory(at: fullPath, progressCallback: progressCallback)
                    continue
                } else {
                    // Index file
                    filePaths.append(fullPath)
                }
            }
        }

        return try await indexDocuments(at: filePaths, progressCallback: progressCallback)
    }

    /// Index all Swift source files in a project
    func indexSwiftCode(projectPath: String, progressCallback: ((String, Int, Int) -> Void)? = nil) async throws -> IndexingStatistics {
        return try await indexDirectory(
            at: projectPath,
            fileExtensions: ["swift"],
            progressCallback: progressCallback
        )
    }
}
