//
//  ConversationSummary.swift
//  AIAdventChatV2
//
//  Created for message history compression
//

import Foundation

/// Represents a compressed summary of a conversation segment
struct ConversationSummary: Codable, Identifiable {
    let id: UUID
    let summary: String
    let originalMessagesCount: Int
    let originalTokensEstimate: Int
    let summaryTokensEstimate: Int
    let timeRange: DateInterval
    let compressionRatio: Double
    let timestamp: Date

    init(
        summary: String,
        originalMessagesCount: Int,
        originalTokensEstimate: Int,
        summaryTokensEstimate: Int,
        startDate: Date,
        endDate: Date
    ) {
        self.id = UUID()
        self.summary = summary
        self.originalMessagesCount = originalMessagesCount
        self.originalTokensEstimate = originalTokensEstimate
        self.summaryTokensEstimate = summaryTokensEstimate
        self.timeRange = DateInterval(start: startDate, end: endDate)
        self.compressionRatio = Double(summaryTokensEstimate) / Double(max(originalTokensEstimate, 1))
        self.timestamp = Date()
    }

    /// Token savings achieved by compression
    var tokensSaved: Int {
        return originalTokensEstimate - summaryTokensEstimate
    }

    /// Compression efficiency percentage
    var compressionEfficiency: Double {
        return (1.0 - compressionRatio) * 100
    }
}

/// Compressed conversation history that includes summaries and recent messages
struct CompressedConversationHistory: Codable {
    var summaries: [ConversationSummary]
    var recentMessages: [Message]

    init(summaries: [ConversationSummary] = [], recentMessages: [Message] = []) {
        self.summaries = summaries
        self.recentMessages = recentMessages
    }

    /// Total estimated tokens in the compressed history
    var totalTokensEstimate: Int {
        let summaryTokens = summaries.reduce(0) { $0 + $1.summaryTokensEstimate }
        let recentTokens = recentMessages.reduce(0) { $0 + estimateTokens(for: $1.content) }
        return summaryTokens + recentTokens
    }

    /// Total original tokens before compression
    var originalTokensEstimate: Int {
        let summaryOriginalTokens = summaries.reduce(0) { $0 + $1.originalTokensEstimate }
        let recentTokens = recentMessages.reduce(0) { $0 + estimateTokens(for: $1.content) }
        return summaryOriginalTokens + recentTokens
    }

    /// Total tokens saved across all summaries
    var totalTokensSaved: Int {
        return summaries.reduce(0) { $0 + $1.tokensSaved }
    }

    /// Overall compression ratio
    var compressionRatio: Double {
        guard originalTokensEstimate > 0 else { return 1.0 }
        return Double(totalTokensEstimate) / Double(originalTokensEstimate)
    }

    /// Build message array for API calls
    func buildMessageArray() -> [[String: String]] {
        var result: [[String: String]] = []

        // Add summaries as system-like context
        for summary in summaries {
            result.append([
                "role": "user",
                "content": "[Previous conversation summary]: \(summary.summary)"
            ])
        }

        // Add recent messages
        for message in recentMessages {
            if message.isSystemMessage {
                continue
            }
            result.append([
                "role": message.isFromUser ? "user" : "assistant",
                "content": message.content
            ])
        }

        return result
    }

    /// Simple token estimation (approximation: 1 token ≈ 4 characters)
    private func estimateTokens(for text: String) -> Int {
        return max(1, text.count / 4)
    }
}

/// Statistics about compression performance
struct CompressionStats: Codable {
    var totalCompressions: Int = 0
    var totalTokensSaved: Int = 0
    var totalOriginalTokens: Int = 0
    var totalCompressedTokens: Int = 0
    var averageCompressionRatio: Double = 0.0
    var lastCompressionDate: Date?

    mutating func recordCompression(summary: ConversationSummary) {
        totalCompressions += 1
        totalTokensSaved += summary.tokensSaved
        totalOriginalTokens += summary.originalTokensEstimate
        totalCompressedTokens += summary.summaryTokensEstimate

        if totalOriginalTokens > 0 {
            averageCompressionRatio = Double(totalCompressedTokens) / Double(totalOriginalTokens)
        }

        lastCompressionDate = Date()
    }

    var averageTokensSavedPerCompression: Double {
        guard totalCompressions > 0 else { return 0 }
        return Double(totalTokensSaved) / Double(totalCompressions)
    }

    var compressionEfficiency: Double {
        return (1.0 - averageCompressionRatio) * 100
    }
}
