//
//  ConversationSummaryTests.swift
//  AIAdventChatV2Tests
//

import XCTest
@testable import AIAdventChatV2

final class ConversationSummaryTests: XCTestCase {

    // MARK: - ConversationSummary Initialization

    func testInitializationSetsFields() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = Date(timeIntervalSince1970: 1_003_600)
        let summary = ConversationSummary(
            summary: "Discussed Swift concurrency",
            originalMessagesCount: 20,
            originalTokensEstimate: 1000,
            summaryTokensEstimate: 200,
            startDate: start,
            endDate: end
        )

        XCTAssertEqual(summary.summary, "Discussed Swift concurrency")
        XCTAssertEqual(summary.originalMessagesCount, 20)
        XCTAssertEqual(summary.originalTokensEstimate, 1000)
        XCTAssertEqual(summary.summaryTokensEstimate, 200)
        XCTAssertNotNil(summary.id)
    }

    func testCompressionRatioCalculation() {
        let summary = ConversationSummary(
            summary: "test",
            originalMessagesCount: 10,
            originalTokensEstimate: 1000,
            summaryTokensEstimate: 250,
            startDate: Date(),
            endDate: Date()
        )

        XCTAssertEqual(summary.compressionRatio, 0.25, accuracy: 0.001)
    }

    func testTokensSaved() {
        let summary = ConversationSummary(
            summary: "test",
            originalMessagesCount: 5,
            originalTokensEstimate: 800,
            summaryTokensEstimate: 300,
            startDate: Date(),
            endDate: Date()
        )

        XCTAssertEqual(summary.tokensSaved, 500)
    }

    func testCompressionEfficiency() {
        let summary = ConversationSummary(
            summary: "test",
            originalMessagesCount: 5,
            originalTokensEstimate: 1000,
            summaryTokensEstimate: 200,
            startDate: Date(),
            endDate: Date()
        )

        XCTAssertEqual(summary.compressionEfficiency, 80.0, accuracy: 0.001)
    }

    func testZeroOriginalTokensDoesNotCrash() {
        let summary = ConversationSummary(
            summary: "empty",
            originalMessagesCount: 0,
            originalTokensEstimate: 0,
            summaryTokensEstimate: 0,
            startDate: Date(),
            endDate: Date()
        )

        XCTAssertEqual(summary.compressionRatio, 0.0, accuracy: 0.001)
        XCTAssertEqual(summary.tokensSaved, 0)
    }

    func testEachSummaryHasUniqueId() {
        let s1 = ConversationSummary(summary: "a", originalMessagesCount: 1, originalTokensEstimate: 100, summaryTokensEstimate: 10, startDate: Date(), endDate: Date())
        let s2 = ConversationSummary(summary: "b", originalMessagesCount: 1, originalTokensEstimate: 100, summaryTokensEstimate: 10, startDate: Date(), endDate: Date())
        XCTAssertNotEqual(s1.id, s2.id)
    }

    // MARK: - ConversationSummary Codable

    func testEncodeDecodeRoundTrip() throws {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = Date(timeIntervalSince1970: 1_003_600)
        let original = ConversationSummary(
            summary: "RAG discussion",
            originalMessagesCount: 15,
            originalTokensEstimate: 500,
            summaryTokensEstimate: 100,
            startDate: start,
            endDate: end
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConversationSummary.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.summary, original.summary)
        XCTAssertEqual(decoded.originalMessagesCount, original.originalMessagesCount)
        XCTAssertEqual(decoded.originalTokensEstimate, original.originalTokensEstimate)
        XCTAssertEqual(decoded.summaryTokensEstimate, original.summaryTokensEstimate)
        XCTAssertEqual(decoded.compressionRatio, original.compressionRatio, accuracy: 0.001)
    }

    // MARK: - CompressedConversationHistory

    func testEmptyHistoryHasZeroTokens() {
        let history = CompressedConversationHistory()
        XCTAssertEqual(history.totalTokensEstimate, 0)
        XCTAssertEqual(history.totalTokensSaved, 0)
        XCTAssertEqual(history.compressionRatio, 1.0, accuracy: 0.001)
    }

    func testTotalTokensSavedSumsSummaries() {
        let s1 = ConversationSummary(summary: "s1", originalMessagesCount: 5, originalTokensEstimate: 400, summaryTokensEstimate: 100, startDate: Date(), endDate: Date())
        let s2 = ConversationSummary(summary: "s2", originalMessagesCount: 5, originalTokensEstimate: 600, summaryTokensEstimate: 150, startDate: Date(), endDate: Date())
        let history = CompressedConversationHistory(summaries: [s1, s2])

        XCTAssertEqual(history.totalTokensSaved, 750)
    }

    func testBuildMessageArrayIncludesSummaries() {
        let s = ConversationSummary(summary: "Brief history", originalMessagesCount: 3, originalTokensEstimate: 100, summaryTokensEstimate: 20, startDate: Date(), endDate: Date())
        let history = CompressedConversationHistory(summaries: [s])
        let messages = history.buildMessageArray()

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"], "user")
        XCTAssertTrue(messages[0]["content"]?.contains("Brief history") ?? false)
    }

    func testBuildMessageArraySkipsSystemMessages() {
        let systemMsg = Message(content: "System init", isFromUser: false, isSystemMessage: true)
        let userMsg = Message(content: "Hello", isFromUser: true)
        let history = CompressedConversationHistory(recentMessages: [systemMsg, userMsg])
        let messages = history.buildMessageArray()

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"], "user")
        XCTAssertEqual(messages[0]["content"], "Hello")
    }

    func testBuildMessageArrayRoleMapping() {
        let userMsg = Message(content: "Question", isFromUser: true)
        let assistantMsg = Message(content: "Answer", isFromUser: false)
        let history = CompressedConversationHistory(recentMessages: [userMsg, assistantMsg])
        let messages = history.buildMessageArray()

        XCTAssertEqual(messages[0]["role"], "user")
        XCTAssertEqual(messages[1]["role"], "assistant")
    }

    // MARK: - CompressionStats

    func testInitialStatsAreZero() {
        let stats = CompressionStats()
        XCTAssertEqual(stats.totalCompressions, 0)
        XCTAssertEqual(stats.totalTokensSaved, 0)
        XCTAssertEqual(stats.averageTokensSavedPerCompression, 0.0, accuracy: 0.001)
        XCTAssertNil(stats.lastCompressionDate)
    }

    func testRecordCompressionUpdatesStats() {
        var stats = CompressionStats()
        let summary = ConversationSummary(
            summary: "test",
            originalMessagesCount: 10,
            originalTokensEstimate: 1000,
            summaryTokensEstimate: 200,
            startDate: Date(),
            endDate: Date()
        )

        stats.recordCompression(summary: summary)

        XCTAssertEqual(stats.totalCompressions, 1)
        XCTAssertEqual(stats.totalTokensSaved, 800)
        XCTAssertNotNil(stats.lastCompressionDate)
    }

    func testAverageTokensSavedPerCompression() {
        var stats = CompressionStats()
        let s1 = ConversationSummary(summary: "a", originalMessagesCount: 5, originalTokensEstimate: 400, summaryTokensEstimate: 100, startDate: Date(), endDate: Date())
        let s2 = ConversationSummary(summary: "b", originalMessagesCount: 5, originalTokensEstimate: 600, summaryTokensEstimate: 200, startDate: Date(), endDate: Date())
        stats.recordCompression(summary: s1)
        stats.recordCompression(summary: s2)

        // s1 saves 300, s2 saves 400 → average = 350
        XCTAssertEqual(stats.averageTokensSavedPerCompression, 350.0, accuracy: 0.001)
    }

    func testCompressionEfficiencyInStats() {
        var stats = CompressionStats()
        let summary = ConversationSummary(
            summary: "test",
            originalMessagesCount: 5,
            originalTokensEstimate: 1000,
            summaryTokensEstimate: 250,
            startDate: Date(),
            endDate: Date()
        )
        stats.recordCompression(summary: summary)

        XCTAssertEqual(stats.compressionEfficiency, 75.0, accuracy: 0.001)
    }
}
