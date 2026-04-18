//
//  DocumentChunkTests.swift
//  AIAdventChatV2Tests
//

import XCTest
@testable import AIAdventChatV2

final class DocumentChunkTests: XCTestCase {

    // MARK: - DocumentChunk Initialization

    func testDefaultInitialization() {
        let metadata = ChunkMetadata(fileType: .swift, startLine: 1, endLine: 50, tokenCount: 120, language: "Swift")
        let chunk = DocumentChunk(
            filePath: "/project/Service.swift",
            fileName: "Service.swift",
            content: "class Service {}",
            chunkIndex: 0,
            metadata: metadata
        )

        XCTAssertFalse(chunk.id.isEmpty)
        XCTAssertEqual(chunk.filePath, "/project/Service.swift")
        XCTAssertEqual(chunk.fileName, "Service.swift")
        XCTAssertEqual(chunk.content, "class Service {}")
        XCTAssertEqual(chunk.chunkIndex, 0)
        XCTAssertNil(chunk.embedding)
    }

    func testCustomIdIsPreserved() {
        let customId = "custom-id-123"
        let metadata = ChunkMetadata(fileType: .text, startLine: nil, endLine: nil, tokenCount: 10, language: nil)
        let chunk = DocumentChunk(id: customId, filePath: "/a.txt", fileName: "a.txt", content: "text", chunkIndex: 0, metadata: metadata)
        XCTAssertEqual(chunk.id, customId)
    }

    func testEmbeddingIsStored() {
        let embedding: [Double] = [0.1, 0.2, 0.3, 0.4]
        let metadata = ChunkMetadata(fileType: .code, startLine: nil, endLine: nil, tokenCount: 5, language: nil)
        let chunk = DocumentChunk(filePath: "/f.py", fileName: "f.py", content: "x = 1", chunkIndex: 0, embedding: embedding, metadata: metadata)

        XCTAssertEqual(chunk.embedding, embedding)
        XCTAssertEqual(chunk.embedding?.count, 4)
    }

    func testEachChunkHasUniqueDefaultId() {
        let metadata = ChunkMetadata(fileType: .text, startLine: nil, endLine: nil, tokenCount: 1, language: nil)
        let c1 = DocumentChunk(filePath: "/a", fileName: "a", content: "a", chunkIndex: 0, metadata: metadata)
        let c2 = DocumentChunk(filePath: "/b", fileName: "b", content: "b", chunkIndex: 1, metadata: metadata)
        XCTAssertNotEqual(c1.id, c2.id)
    }

    func testCreatedAtIsRecent() {
        let before = Date()
        let metadata = ChunkMetadata(fileType: .markdown, startLine: nil, endLine: nil, tokenCount: 10, language: nil)
        let chunk = DocumentChunk(filePath: "/doc.md", fileName: "doc.md", content: "# Header", chunkIndex: 0, metadata: metadata)
        let after = Date()

        XCTAssertGreaterThanOrEqual(chunk.createdAt, before)
        XCTAssertLessThanOrEqual(chunk.createdAt, after)
    }

    // MARK: - ChunkMetadata

    func testAllFileTypes() {
        let types: [ChunkMetadata.FileType] = [.swift, .markdown, .text, .pdf, .code, .documentation]
        XCTAssertEqual(types.count, 6)
        XCTAssertEqual(ChunkMetadata.FileType.swift.rawValue, "swift")
        XCTAssertEqual(ChunkMetadata.FileType.markdown.rawValue, "markdown")
        XCTAssertEqual(ChunkMetadata.FileType.pdf.rawValue, "pdf")
    }

    func testMetadataLineRange() {
        let metadata = ChunkMetadata(fileType: .swift, startLine: 10, endLine: 40, tokenCount: 200, language: "Swift")
        XCTAssertEqual(metadata.startLine, 10)
        XCTAssertEqual(metadata.endLine, 40)
    }

    func testMetadataOptionalFields() {
        let metadata = ChunkMetadata(fileType: .text, startLine: nil, endLine: nil, tokenCount: 50, language: nil)
        XCTAssertNil(metadata.startLine)
        XCTAssertNil(metadata.endLine)
        XCTAssertNil(metadata.language)
    }

    // MARK: - DocumentChunk Codable

    func testEncodeDecodeRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata = ChunkMetadata(fileType: .swift, startLine: 1, endLine: 30, tokenCount: 100, language: "Swift")
        let original = DocumentChunk(
            id: "test-id",
            filePath: "/src/Model.swift",
            fileName: "Model.swift",
            content: "struct Model: Codable {}",
            chunkIndex: 2,
            embedding: [0.5, 0.6],
            metadata: metadata,
            createdAt: fixedDate
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DocumentChunk.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.filePath, original.filePath)
        XCTAssertEqual(decoded.fileName, original.fileName)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.chunkIndex, original.chunkIndex)
        XCTAssertEqual(decoded.embedding, original.embedding)
        XCTAssertEqual(decoded.metadata.fileType, original.metadata.fileType)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, original.createdAt.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - SearchResult

    func testSearchResultPreviewShortContent() {
        let metadata = ChunkMetadata(fileType: .text, startLine: nil, endLine: nil, tokenCount: 5, language: nil)
        let chunk = DocumentChunk(filePath: "/f", fileName: "f", content: "Short text", chunkIndex: 0, metadata: metadata)
        let result = SearchResult(id: "1", chunk: chunk, similarity: 0.95, rank: 1)

        XCTAssertEqual(result.preview, "Short text")
    }

    func testSearchResultPreviewLongContent() {
        let longContent = String(repeating: "a", count: 400)
        let metadata = ChunkMetadata(fileType: .text, startLine: nil, endLine: nil, tokenCount: 100, language: nil)
        let chunk = DocumentChunk(filePath: "/f", fileName: "f", content: longContent, chunkIndex: 0, metadata: metadata)
        let result = SearchResult(id: "1", chunk: chunk, similarity: 0.9, rank: 1)

        XCTAssertTrue(result.preview.contains("..."))
        XCTAssertLessThan(result.preview.count, 400)
    }

    func testSearchResultPreviewNormalizesWhitespace() {
        let metadata = ChunkMetadata(fileType: .text, startLine: nil, endLine: nil, tokenCount: 5, language: nil)
        let chunk = DocumentChunk(filePath: "/f", fileName: "f", content: "hello   world\n  foo", chunkIndex: 0, metadata: metadata)
        let result = SearchResult(id: "1", chunk: chunk, similarity: 0.8, rank: 1)

        XCTAssertFalse(result.preview.contains("  "))
        XCTAssertFalse(result.preview.contains("\n"))
        XCTAssertEqual(result.preview, "hello world foo")
    }

    func testSearchResultProperties() {
        let metadata = ChunkMetadata(fileType: .code, startLine: nil, endLine: nil, tokenCount: 10, language: nil)
        let chunk = DocumentChunk(filePath: "/f", fileName: "f", content: "code", chunkIndex: 0, metadata: metadata)
        let result = SearchResult(id: "res-1", chunk: chunk, similarity: 0.75, rank: 3)

        XCTAssertEqual(result.id, "res-1")
        XCTAssertEqual(result.similarity, 0.75, accuracy: 0.001)
        XCTAssertEqual(result.rank, 3)
    }

    // MARK: - IndexingStatistics

    func testInitialStatisticsAreZero() {
        let stats = IndexingStatistics()
        XCTAssertEqual(stats.totalDocuments, 0)
        XCTAssertEqual(stats.totalChunks, 0)
        XCTAssertTrue(stats.indexedFiles.isEmpty)
        XCTAssertTrue(stats.failedFiles.isEmpty)
        XCTAssertEqual(stats.processingTime, 0.0, accuracy: 0.001)
    }

    func testAddSuccess() {
        var stats = IndexingStatistics()
        stats.addSuccess(file: "Model.swift", chunks: 5)

        XCTAssertEqual(stats.totalDocuments, 1)
        XCTAssertEqual(stats.totalChunks, 5)
        XCTAssertEqual(stats.indexedFiles, ["Model.swift"])
        XCTAssertTrue(stats.failedFiles.isEmpty)
    }

    func testAddFailure() {
        var stats = IndexingStatistics()
        stats.addFailure(file: "broken.pdf")

        XCTAssertEqual(stats.totalDocuments, 0)
        XCTAssertEqual(stats.totalChunks, 0)
        XCTAssertTrue(stats.indexedFiles.isEmpty)
        XCTAssertEqual(stats.failedFiles, ["broken.pdf"])
    }

    func testMultipleSuccessesAccumulate() {
        var stats = IndexingStatistics()
        stats.addSuccess(file: "a.swift", chunks: 3)
        stats.addSuccess(file: "b.swift", chunks: 7)

        XCTAssertEqual(stats.totalDocuments, 2)
        XCTAssertEqual(stats.totalChunks, 10)
        XCTAssertEqual(stats.indexedFiles.count, 2)
    }

    func testMixedSuccessAndFailure() {
        var stats = IndexingStatistics()
        stats.addSuccess(file: "ok.md", chunks: 2)
        stats.addFailure(file: "bad.bin")
        stats.addSuccess(file: "ok2.txt", chunks: 1)

        XCTAssertEqual(stats.totalDocuments, 2)
        XCTAssertEqual(stats.failedFiles.count, 1)
        XCTAssertEqual(stats.totalChunks, 3)
    }
}
