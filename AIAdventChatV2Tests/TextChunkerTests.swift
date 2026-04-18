//
//  TextChunkerTests.swift
//  AIAdventChatV2Tests
//

import XCTest
@testable import AIAdventChatV2

final class TextChunkerTests: XCTestCase {

    var chunker: TextChunker!

    override func setUp() {
        super.setUp()
        chunker = TextChunker(config: .default)
    }

    override func tearDown() {
        chunker = nil
        super.tearDown()
    }

    // MARK: - Empty / whitespace

    func testEmptyTextReturnsNoChunks() {
        XCTAssertTrue(chunker.chunkText("").isEmpty)
    }

    func testWhitespaceOnlyReturnsNoChunks() {
        XCTAssertTrue(chunker.chunkText("   \n\t  ").isEmpty)
    }

    // MARK: - Short text → single chunk

    func testShortTextReturnsSingleChunk() {
        let text = "Hello world. This is a short text."
        let chunks = chunker.chunkText(text)
        XCTAssertEqual(chunks.count, 1)
    }

    func testSingleChunkContainsFullText() {
        let text = "Hello world"
        let chunks = chunker.chunkText(text)
        XCTAssertEqual(chunks[0].content, text)
    }

    func testSingleChunkIndexIsZero() {
        let chunks = chunker.chunkText("Short text")
        XCTAssertEqual(chunks[0].index, 0)
        XCTAssertEqual(chunks[0].startPosition, 0)
    }

    func testSingleChunkEndPositionMatchesLength() {
        let text = "Short text"
        let chunks = chunker.chunkText(text)
        XCTAssertEqual(chunks[0].endPosition, text.count)
    }

    func testTextLengthProperty() {
        let text = "Hello World"
        let chunks = chunker.chunkText(text)
        XCTAssertEqual(chunks[0].length, text.count)
    }

    // MARK: - Long text → multiple chunks

    func testLongTextProducesMultipleChunks() {
        let longText = String(repeating: "A", count: 2500)
        let chunks = chunker.chunkText(longText)
        XCTAssertGreaterThan(chunks.count, 1)
    }

    func testChunkIndicesAreSequential() {
        let longText = String(repeating: "Word sentence end. ", count: 200)
        let chunks = chunker.chunkText(longText)

        for (i, chunk) in chunks.enumerated() {
            XCTAssertEqual(chunk.index, i, "Chunk \(i) should have index \(i)")
        }
    }

    func testChunkSizeDoesNotExceedConfigPlusSearchWindow() {
        let longText = String(repeating: "A", count: 3000)
        let chunks = chunker.chunkText(longText)
        let maxAllowed = TextChunker.ChunkingConfig.default.chunkSize + 200

        for (i, chunk) in chunks.enumerated() {
            XCTAssertLessThanOrEqual(chunk.content.count, maxAllowed,
                "Chunk \(i) size \(chunk.content.count) exceeds max \(maxAllowed)")
        }
    }

    // MARK: - Overlap

    func testOverlapMakesSecondChunkStartBeforeFirstEnds() {
        let text = String(repeating: "X", count: 2500)
        let chunks = chunker.chunkText(text)

        guard chunks.count >= 2 else {
            XCTFail("Need at least 2 chunks to verify overlap")
            return
        }

        // With overlap: chunk[1].startPosition < chunk[0].endPosition
        XCTAssertLessThan(chunks[1].startPosition, chunks[0].endPosition,
            "Second chunk must start before end of first chunk (overlap)")
    }

    // MARK: - Token estimate

    func testTokenEstimateIsPositiveForNonEmptyChunk() {
        let text = String(repeating: "word ", count: 10)
        let chunks = chunker.chunkText(text)
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertGreaterThan(chunks[0].tokenEstimate, 0)
    }

    func testTokenEstimateApproximatelyOnePerFourChars() {
        // 400 chars → ~100 tokens
        let text = String(repeating: "A", count: 400)
        let chunks = chunker.chunkText(text)
        XCTAssertEqual(chunks[0].tokenEstimate, 100)
    }

    // MARK: - ChunkingConfig

    func testCodeConfigHasLargerChunkSizeThanDefault() {
        XCTAssertGreaterThan(
            TextChunker.ChunkingConfig.code.chunkSize,
            TextChunker.ChunkingConfig.default.chunkSize
        )
    }

    func testLargeConfigHasLargerOverlapThanDefault() {
        XCTAssertGreaterThan(
            TextChunker.ChunkingConfig.large.overlapSize,
            TextChunker.ChunkingConfig.default.overlapSize
        )
    }

    func testCodeChunkerProducesFewerOrEqualChunksThanDefault() {
        let text = String(repeating: "func test() { return; }\n", count: 200)

        let defaultChunks = TextChunker(config: .default).chunkText(text)
        let codeChunks = TextChunker(config: .code).chunkText(text)

        XCTAssertLessThanOrEqual(codeChunks.count, defaultChunks.count,
            "Code config produces \(codeChunks.count) chunks vs default \(defaultChunks.count)")
    }

    func testDefaultConfigHasSentenceRespect() {
        XCTAssertTrue(TextChunker.ChunkingConfig.default.respectSentences)
    }

    func testCodeConfigDoesNotRespectSentences() {
        XCTAssertFalse(TextChunker.ChunkingConfig.code.respectSentences)
    }
}
