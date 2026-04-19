//
//  TokenManagerTests.swift
//  AIAdventChatV2Tests
//

import XCTest
@testable import AIAdventChatV2

final class TokenManagerTests: XCTestCase {

    // MARK: - estimateTokens

    func testEstimateTokensEmpty() {
        let tokens = TokenManager.estimateTokens("")
        XCTAssertGreaterThanOrEqual(tokens, 0)
    }

    func testEstimateTokensTwoWords() {
        // "Hello World" → 2 words, 11 chars / 4 = 2 → max(2, 2) = 2
        let tokens = TokenManager.estimateTokens("Hello World")
        XCTAssertEqual(tokens, 2)
    }

    func testEstimateTokensManyWords() {
        // 100 words × "word " = 500 chars → charTokens = 125, wordTokens = 100 → max = 125
        let text = String(repeating: "word ", count: 100)
        let tokens = TokenManager.estimateTokens(text)
        XCTAssertEqual(tokens, 125)
    }

    func testEstimateTokensAlwaysPositiveForNonEmpty() {
        let tokens = TokenManager.estimateTokens("Swift is a great language")
        XCTAssertGreaterThan(tokens, 0)
    }

    func testEstimateTokensGrowsWithLength() {
        let short = TokenManager.estimateTokens("Hello")
        let long = TokenManager.estimateTokens(String(repeating: "Hello ", count: 50))
        XCTAssertLessThan(short, long)
    }

    // MARK: - checkStatus

    func testCheckStatusOkAtZero() {
        XCTAssertEqual(TokenManager.checkStatus(tokens: 0, limit: 100), .ok)
    }

    func testCheckStatusOkBelow80Percent() {
        XCTAssertEqual(TokenManager.checkStatus(tokens: 50, limit: 100), .ok)
        XCTAssertEqual(TokenManager.checkStatus(tokens: 79, limit: 100), .ok)
    }

    func testCheckStatusWarningAt80Percent() {
        XCTAssertEqual(TokenManager.checkStatus(tokens: 80, limit: 100), .warning)
    }

    func testCheckStatusWarningBelow100Percent() {
        XCTAssertEqual(TokenManager.checkStatus(tokens: 99, limit: 100), .warning)
    }

    func testCheckStatusExceededAt100Percent() {
        XCTAssertEqual(TokenManager.checkStatus(tokens: 100, limit: 100), .exceeded)
    }

    func testCheckStatusExceededAbove100Percent() {
        XCTAssertEqual(TokenManager.checkStatus(tokens: 200, limit: 100), .exceeded)
    }

    func testCheckStatusBoundaryExact80() {
        // 8000 / 10000 = 80% → warning
        XCTAssertEqual(TokenManager.checkStatus(tokens: 8000, limit: 10000), .warning)
        // 7999 / 10000 = 79.99% → ok
        XCTAssertEqual(TokenManager.checkStatus(tokens: 7999, limit: 10000), .ok)
    }

    // MARK: - getLimit

    func testGetLimitForClaude() {
        let limit = TokenManager.getLimit(for: "claude-3-7-sonnet-20250219", provider: .claude)
        XCTAssertEqual(limit, 200000)
    }

    func testGetLimitForClaudeAnyModel() {
        // Claude provider always returns 200000 regardless of model string
        let limit = TokenManager.getLimit(for: "some-other-model", provider: .claude)
        XCTAssertEqual(limit, 200000)
    }

    func testGetLimitForLocalModel() {
        let limit = TokenManager.getLimit(for: "llama3", provider: .local)
        XCTAssertEqual(limit, 128000)
    }

    func testGetLimitForHuggingFaceKnownModel() {
        let limit = TokenManager.getLimit(for: "meta-llama/Llama-3.1-8B-Instruct", provider: .huggingface)
        XCTAssertEqual(limit, 8192)
    }

    func testGetLimitForHuggingFaceUnknownModelDefaultsTo8192() {
        let limit = TokenManager.getLimit(for: "totally-unknown-model", provider: .huggingface)
        XCTAssertEqual(limit, 8192)
    }

    func testGetLimitForDeepSeek() {
        let limit = TokenManager.getLimit(for: "deepseek-ai/DeepSeek-V3-0324", provider: .huggingface)
        XCTAssertEqual(limit, 64000)
    }

    // MARK: - getColor

    func testGetColorForOk() {
        let color = TokenManager.getColor(for: .ok)
        XCTAssertEqual(color.r, 0.0, accuracy: 0.001)
        XCTAssertEqual(color.g, 0.8, accuracy: 0.001)
        XCTAssertEqual(color.b, 0.0, accuracy: 0.001)
    }

    func testGetColorForWarning() {
        let color = TokenManager.getColor(for: .warning)
        XCTAssertEqual(color.r, 1.0, accuracy: 0.001)
        XCTAssertEqual(color.g, 0.65, accuracy: 0.001)
        XCTAssertEqual(color.b, 0.0, accuracy: 0.001)
    }

    func testGetColorForExceeded() {
        let color = TokenManager.getColor(for: .exceeded)
        XCTAssertEqual(color.r, 1.0, accuracy: 0.001)
        XCTAssertEqual(color.g, 0.0, accuracy: 0.001)
        XCTAssertEqual(color.b, 0.0, accuracy: 0.001)
    }

    func testAllStatusesHaveUniqueColors() {
        let ok = TokenManager.getColor(for: .ok)
        let warning = TokenManager.getColor(for: .warning)
        let exceeded = TokenManager.getColor(for: .exceeded)

        XCTAssertNotEqual(ok.r + ok.g + ok.b, warning.r + warning.g + warning.b)
        XCTAssertNotEqual(warning.r + warning.g + warning.b, exceeded.r + exceeded.g + exceeded.b)
    }

    // MARK: - modelLimits

    func testModelLimitsContainClaudeModels() {
        XCTAssertNotNil(TokenManager.modelLimits["claude-3-7-sonnet-20250219"])
        XCTAssertNotNil(TokenManager.modelLimits["claude-3-5-sonnet-20241022"])
    }

    func testAllModelLimitsArePositive() {
        for (_, limit) in TokenManager.modelLimits {
            XCTAssertGreaterThan(limit, 0)
        }
    }

    // MARK: - Edge Cases (TASK-12)

    func testGetLimitForEmptyModelString() {
        let limit = TokenManager.getLimit(for: "", provider: .huggingface)
        XCTAssertGreaterThan(limit, 0)
    }

    func testGetLimitForEmptyModelStringClaude() {
        let limit = TokenManager.getLimit(for: "", provider: .claude)
        XCTAssertEqual(limit, 200000)
    }

    func testGetLimitForEmptyModelStringLocal() {
        let limit = TokenManager.getLimit(for: "", provider: .local)
        XCTAssertGreaterThan(limit, 0)
    }

    func testGetLimitReturnsPositiveForAnyInput() {
        let providers: [ModelProvider] = ModelProvider.allCases
        for provider in providers {
            let limit = TokenManager.getLimit(for: "unknown-model-xyz", provider: provider)
            XCTAssertGreaterThan(limit, 0, "Provider \(provider) returned non-positive limit")
        }
    }
}
