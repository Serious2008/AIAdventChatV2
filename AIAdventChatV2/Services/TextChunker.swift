//
//  TextChunker.swift
//  AIAdventChatV2
//
//  Service for splitting text into overlapping chunks
//

import Foundation

// MARK: - Text Chunker

class TextChunker {

    // MARK: - Configuration

    struct ChunkingConfig {
        let chunkSize: Int           // Target size in characters
        let overlapSize: Int         // Overlap between chunks in characters
        let respectParagraphs: Bool  // Try to split at paragraph boundaries
        let respectSentences: Bool   // Try to split at sentence boundaries

        static let `default` = ChunkingConfig(
            chunkSize: 1000,
            overlapSize: 200,
            respectParagraphs: true,
            respectSentences: true
        )

        static let code = ChunkingConfig(
            chunkSize: 3000,  // Larger chunks for code to keep functions together
            overlapSize: 500,
            respectParagraphs: true,  // Respect blank lines in code
            respectSentences: false
        )

        static let large = ChunkingConfig(
            chunkSize: 2000,
            overlapSize: 400,
            respectParagraphs: true,
            respectSentences: true
        )
    }

    private let config: ChunkingConfig

    // MARK: - Init

    init(config: ChunkingConfig = .default) {
        self.config = config
    }

    // MARK: - Public Methods

    /// Split text into chunks with overlap
    func chunkText(_ text: String) -> [TextChunk] {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedText.isEmpty else {
            return []
        }

        // If text is smaller than chunk size, return as single chunk
        if cleanedText.count <= config.chunkSize {
            return [
                TextChunk(
                    content: cleanedText,
                    index: 0,
                    startPosition: 0,
                    endPosition: cleanedText.count,
                    tokenEstimate: estimateTokens(cleanedText)
                )
            ]
        }

        // Split into chunks
        var chunks: [TextChunk] = []
        var currentPosition = 0
        var chunkIndex = 0

        while currentPosition < cleanedText.count {
            let chunkContent = extractChunk(
                from: cleanedText,
                startingAt: currentPosition
            )

            let chunk = TextChunk(
                content: chunkContent,
                index: chunkIndex,
                startPosition: currentPosition,
                endPosition: currentPosition + chunkContent.count,
                tokenEstimate: estimateTokens(chunkContent)
            )

            chunks.append(chunk)

            // Move to next chunk with overlap
            currentPosition += config.chunkSize - config.overlapSize
            chunkIndex += 1

            // Prevent infinite loop
            if currentPosition >= cleanedText.count {
                break
            }
        }

        return chunks
    }

    /// Split extracted text into document chunks with metadata
    func chunkDocument(_ extractedText: ExtractedText) -> [DocumentChunk] {
        let textChunks = chunkText(extractedText.content)

        return textChunks.map { textChunk in
            let metadata = ChunkMetadata(
                fileType: mapFileFormatToChunkType(extractedText.metadata.format),
                startLine: nil, // Could be calculated if needed
                endLine: nil,
                tokenCount: textChunk.tokenEstimate,
                language: extractedText.metadata.language
            )

            return DocumentChunk(
                filePath: extractedText.metadata.filePath,
                fileName: extractedText.metadata.fileName,
                content: textChunk.content,
                chunkIndex: textChunk.index,
                embedding: nil, // Will be filled by EmbeddingService
                metadata: metadata
            )
        }
    }

    // MARK: - Private Methods

    private func extractChunk(from text: String, startingAt position: Int) -> String {
        let startIndex = text.index(text.startIndex, offsetBy: position)

        // Calculate target end position
        let targetEndPosition = min(position + config.chunkSize, text.count)
        var endIndex = text.index(text.startIndex, offsetBy: targetEndPosition)

        // Try to find natural break points
        if config.respectParagraphs {
            if let paragraphBreak = findParagraphBreak(in: text, near: endIndex, searchBackward: true) {
                endIndex = paragraphBreak
            }
        }

        if config.respectSentences && endIndex == text.index(text.startIndex, offsetBy: targetEndPosition) {
            if let sentenceBreak = findSentenceBreak(in: text, near: endIndex, searchBackward: true) {
                endIndex = sentenceBreak
            }
        }

        // Ensure we don't go beyond text boundaries
        if endIndex > text.endIndex {
            endIndex = text.endIndex
        }

        // Ensure valid range (startIndex must be less than endIndex)
        guard startIndex < endIndex else {
            return ""
        }

        return String(text[startIndex..<endIndex])
    }

    private func findParagraphBreak(in text: String, near index: String.Index, searchBackward: Bool) -> String.Index? {
        let searchRange: Range<String.Index>

        if searchBackward {
            let distance = text.distance(from: text.startIndex, to: index)
            let offset = min(200, distance)
            let searchStart = text.index(index, offsetBy: -offset)

            // Ensure valid range
            guard searchStart < index else { return nil }
            searchRange = searchStart..<index
        } else {
            let distance = text.distance(from: index, to: text.endIndex)
            let offset = min(200, distance)
            let searchEnd = text.index(index, offsetBy: offset)

            // Ensure valid range
            guard index < searchEnd else { return nil }
            searchRange = index..<searchEnd
        }

        // Look for double newline (paragraph separator)
        if let range = text.range(of: "\n\n", options: searchBackward ? .backwards : [], range: searchRange) {
            return range.upperBound
        }

        return nil
    }

    private func findSentenceBreak(in text: String, near index: String.Index, searchBackward: Bool) -> String.Index? {
        let searchRange: Range<String.Index>

        if searchBackward {
            let distance = text.distance(from: text.startIndex, to: index)
            let offset = min(100, distance)
            let searchStart = text.index(index, offsetBy: -offset)

            // Ensure valid range
            guard searchStart < index else { return nil }
            searchRange = searchStart..<index
        } else {
            let distance = text.distance(from: index, to: text.endIndex)
            let offset = min(100, distance)
            let searchEnd = text.index(index, offsetBy: offset)

            // Ensure valid range
            guard index < searchEnd else { return nil }
            searchRange = index..<searchEnd
        }

        // Look for sentence endings
        let sentenceEnders = [".", "!", "?"]

        var bestMatch: String.Index?
        var bestDistance = Int.max

        for ender in sentenceEnders {
            let pattern = "\(ender)\\s"
            if let range = text.range(
                of: pattern,
                options: searchBackward ? [.regularExpression, .backwards] : [.regularExpression],
                range: searchRange
            ) {
                let distance = text.distance(from: range.lowerBound, to: index)
                if abs(distance) < bestDistance {
                    bestDistance = abs(distance)
                    bestMatch = range.upperBound
                }
            }
        }

        return bestMatch
    }

    private func estimateTokens(_ text: String) -> Int {
        // Rough estimate: 1 token ≈ 4 characters
        // More accurate would be to use a tokenizer, but this is sufficient for estimates
        return text.count / 4
    }

    private func mapFileFormatToChunkType(_ format: TextExtractor.FileFormat) -> ChunkMetadata.FileType {
        switch format {
        case .swift:
            return .swift
        case .markdown:
            return .markdown
        case .text:
            return .text
        case .pdf:
            return .pdf
        case .json, .xml, .html:
            return .code
        }
    }
}

// MARK: - Text Chunk Model

struct TextChunk {
    let content: String
    let index: Int
    let startPosition: Int
    let endPosition: Int
    let tokenEstimate: Int

    var length: Int {
        return content.count
    }
}
