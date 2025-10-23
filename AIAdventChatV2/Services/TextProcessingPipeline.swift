//
//  TextProcessingPipeline.swift
//  AIAdventChatV2
//
//  Text processing pipeline: cleaning → compression → search
//

import Foundation

// MARK: - Pipeline Result Models

struct PipelineStageResult {
    let stageName: String
    let input: String
    let output: String
    let processingTime: TimeInterval
    let metadata: [String: Any]
}

struct PipelineResult {
    let originalText: String
    let cleanedText: String
    let compressedText: String
    let stages: [PipelineStageResult]
    let totalProcessingTime: TimeInterval

    var statistics: PipelineStatistics {
        PipelineStatistics(
            originalLength: originalText.count,
            cleanedLength: cleanedText.count,
            compressedLength: compressedText.count,
            cleaningReduction: Double(originalText.count - cleanedText.count) / Double(originalText.count) * 100,
            compressionReduction: Double(cleanedText.count - compressedText.count) / Double(cleanedText.count) * 100,
            totalReduction: Double(originalText.count - compressedText.count) / Double(originalText.count) * 100
        )
    }
}

struct PipelineStatistics {
    let originalLength: Int
    let cleanedLength: Int
    let compressedLength: Int
    let cleaningReduction: Double // %
    let compressionReduction: Double // %
    let totalReduction: Double // %
}

// MARK: - Text Processing Pipeline

class TextProcessingPipeline {
    private let apiService: ClaudeService
    private let settings: Settings

    // Stop words for Russian and English
    private let stopWords: Set<String> = {
        let russian = ["и", "в", "во", "не", "что", "он", "на", "я", "с", "со", "как", "а", "то", "все", "она", "так", "его", "но", "да", "ты", "к", "у", "же", "вы", "за", "бы", "по", "только", "ее", "мне", "было", "вот", "от", "меня", "еще", "нет", "о", "из", "ему", "теперь", "когда", "даже", "ну", "вдруг", "ли", "если", "уже", "или", "ни", "быть", "был", "него", "до", "вас", "нибудь", "опять", "уж", "вам", "ведь", "там", "потом", "себя", "ничего", "ей", "может", "они", "тут", "где", "есть", "надо", "ней", "для", "мы", "тебя", "их", "чем", "была", "сам", "чтоб", "без", "будто", "чего", "раз", "тоже", "себе", "под", "будет", "ж", "тогда", "кто", "этот", "того", "потому", "этого", "какой", "совсем", "ним", "здесь", "этом", "один", "почти", "мой", "тем", "чтобы", "нее", "сейчас", "были", "куда", "зачем", "всех", "никогда", "можно", "при", "наконец", "два", "об", "другой", "хоть", "после", "над", "больше", "тот", "через", "эти", "нас", "про", "всего", "них", "какая", "много", "разве", "три", "эту", "моя", "впрочем", "хорошо", "свою", "этой", "перед", "иногда", "лучше", "чуть", "том", "нельзя", "такой", "им", "более", "всегда", "конечно", "всю", "между"]

        let english = ["the", "be", "to", "of", "and", "a", "in", "that", "have", "i", "it", "for", "not", "on", "with", "he", "as", "you", "do", "at", "this", "but", "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all", "would", "there", "their", "what", "so", "up", "out", "if", "about", "who", "get", "which", "go", "me", "when", "make", "can", "like", "time", "no", "just", "him", "know", "take", "people", "into", "year", "your", "good", "some", "could", "them", "see", "other", "than", "then", "now", "look", "only", "come", "its", "over", "think", "also", "back", "after", "use", "two", "how", "our", "work", "first", "well", "way", "even", "new", "want", "because", "any", "these", "give", "day", "most", "us"]

        return Set(russian + english)
    }()

    init(apiService: ClaudeService, settings: Settings) {
        self.apiService = apiService
        self.settings = settings
    }

    // MARK: - Main Pipeline

    func process(_ text: String) async throws -> PipelineResult {
        let startTime = Date()
        var stages: [PipelineStageResult] = []

        print("🔄 Starting text processing pipeline...")
        print("📊 Original text length: \(text.count) characters")

        // Stage 1: Cleaning
        let cleaningStart = Date()
        let cleanedText = cleanText(text)
        let cleaningTime = Date().timeIntervalSince(cleaningStart)

        stages.append(PipelineStageResult(
            stageName: "Cleaning",
            input: text,
            output: cleanedText,
            processingTime: cleaningTime,
            metadata: [
                "html_removed": text.contains("<") && text.contains(">"),
                "stop_words_removed": true,
                "whitespace_normalized": true
            ]
        ))

        print("✅ Stage 1: Cleaning complete (\(cleaningTime)s)")
        print("📊 Cleaned text length: \(cleanedText.count) characters")

        // Stage 2: Compression (Summary)
        let compressionStart = Date()
        let compressedText = try await compressText(cleanedText)
        let compressionTime = Date().timeIntervalSince(compressionStart)

        stages.append(PipelineStageResult(
            stageName: "Compression",
            input: cleanedText,
            output: compressedText,
            processingTime: compressionTime,
            metadata: [
                "compression_method": "llm_summary",
                "model": settings.selectedModel
            ]
        ))

        print("✅ Stage 2: Compression complete (\(compressionTime)s)")
        print("📊 Compressed text length: \(compressedText.count) characters")

        let totalTime = Date().timeIntervalSince(startTime)

        let result = PipelineResult(
            originalText: text,
            cleanedText: cleanedText,
            compressedText: compressedText,
            stages: stages,
            totalProcessingTime: totalTime
        )

        print("✅ Pipeline complete! Total time: \(totalTime)s")
        print("📊 Statistics:")
        print("   - Cleaning reduction: \(String(format: "%.1f", result.statistics.cleaningReduction))%")
        print("   - Compression reduction: \(String(format: "%.1f", result.statistics.compressionReduction))%")
        print("   - Total reduction: \(String(format: "%.1f", result.statistics.totalReduction))%")

        return result
    }

    // MARK: - Stage 1: Text Cleaning

    private func cleanText(_ text: String) -> String {
        var cleaned = text

        // 1. Remove HTML tags
        cleaned = removeHTML(cleaned)

        // 2. Remove excessive whitespace
        cleaned = normalizeWhitespace(cleaned)

        // 3. Remove stop words (optional - can be too aggressive)
        // cleaned = removeStopWords(cleaned)

        return cleaned
    }

    private func removeHTML(_ text: String) -> String {
        // Remove HTML tags
        var result = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode HTML entities
        let htmlEntities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "..."
        ]

        for (entity, replacement) in htmlEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        return result
    }

    private func normalizeWhitespace(_ text: String) -> String {
        // Replace multiple spaces with single space
        var result = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)

        // Replace multiple newlines with double newline
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    private func removeStopWords(_ text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filteredWords = words.filter { word in
            let lowercased = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            return !stopWords.contains(lowercased) && !lowercased.isEmpty
        }
        return filteredWords.joined(separator: " ")
    }

    // MARK: - Stage 2: Text Compression

    private func compressText(_ text: String) async throws -> String {
        // If text is short enough, return as is
        if text.count < 500 {
            return text
        }

        // Use ClaudeService's summarize method with continuation
        return try await withCheckedThrowingContinuation { continuation in
            apiService.summarize(
                text: text,
                apiKey: settings.apiKey,
                progressCallback: nil
            ) { result in
                switch result {
                case .success(let summary):
                    continuation.resume(returning: summary.trimmingCharacters(in: .whitespacesAndNewlines))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Utility: Search with processed text

    func searchInDocumentation(_ query: String, documentation: String) async throws -> String {
        // Process documentation through pipeline
        let result = try await process(documentation)

        let searchPrompt = """
        Documentation:
        \(result.compressedText)

        Question: \(query)

        Please answer the question based only on the provided documentation. Be precise and concise.
        """

        // Use summarize to generate answer from documentation
        return try await withCheckedThrowingContinuation { continuation in
            apiService.summarize(
                text: searchPrompt,
                apiKey: settings.apiKey,
                progressCallback: nil
            ) { result in
                switch result {
                case .success(let answer):
                    continuation.resume(returning: answer.trimmingCharacters(in: .whitespacesAndNewlines))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
