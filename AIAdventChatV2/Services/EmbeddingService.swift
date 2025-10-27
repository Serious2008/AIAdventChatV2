//
//  EmbeddingService.swift
//  AIAdventChatV2
//
//  Service for generating text embeddings using Claude API
//

import Foundation

// MARK: - Embedding Service

class EmbeddingService {

    enum EmbeddingError: Error {
        case invalidAPIKey
        case networkError(String)
        case apiError(String)
        case invalidResponse
        case emptyText
    }

    private let apiKey: String
    private let embeddingDimension: Int = 384 // Simulated embedding dimension

    // MARK: - Init

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Public Methods

    /// Generate embedding for a single text chunk
    func generateEmbedding(for text: String) async throws -> [Double] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyText
        }

        guard !apiKey.isEmpty else {
            throw EmbeddingError.invalidAPIKey
        }

        // For now, we'll generate a hash-based deterministic embedding
        // In production, you would use a real embedding API or model
        return generateDeterministicEmbedding(for: text)
    }

    /// Generate embeddings for multiple chunks (batch processing)
    func generateEmbeddings(for chunks: [DocumentChunk]) async throws -> [DocumentChunk] {
        var updatedChunks: [DocumentChunk] = []

        for chunk in chunks {
            let embedding = try await generateEmbedding(for: chunk.content)

            let updatedChunk = DocumentChunk(
                id: chunk.id,
                filePath: chunk.filePath,
                fileName: chunk.fileName,
                content: chunk.content,
                chunkIndex: chunk.chunkIndex,
                embedding: embedding,
                metadata: chunk.metadata,
                createdAt: chunk.createdAt
            )

            updatedChunks.append(updatedChunk)

            // Add small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        return updatedChunks
    }

    /// Generate embedding for search query
    func generateQueryEmbedding(for query: String) async throws -> [Double] {
        return try await generateEmbedding(for: query)
    }

    // MARK: - Private Methods

    /// Generate deterministic embedding based on text content
    /// This is a simplified approach - in production use proper embedding models
    private func generateDeterministicEmbedding(for text: String) -> [Double] {
        // Create a deterministic but meaningful embedding
        // This simulates real embeddings by using text features

        var embedding = [Double](repeating: 0.0, count: embeddingDimension)

        // Feature 1: Character frequency distribution
        let chars = Array(text.lowercased())
        for (index, char) in chars.prefix(embeddingDimension / 4).enumerated() {
            embedding[index] = Double(char.asciiValue ?? 0) / 255.0
        }

        // Feature 2: Word length distribution
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        for (index, word) in words.prefix(embeddingDimension / 4).enumerated() {
            let offset = embeddingDimension / 4
            embedding[offset + index] = Double(word.count) / 20.0
        }

        // Feature 3: Hash-based features for uniqueness
        let hashValue = text.hashValue
        for i in 0..<(embeddingDimension / 4) {
            let offset = embeddingDimension / 2
            let value = Double((hashValue >> (i % 32)) & 0xFF) / 255.0
            embedding[offset + i] = value
        }

        // Feature 4: Statistical features
        let wordCount = Double(words.count)
        let avgWordLength = words.isEmpty ? 0.0 : Double(text.count) / wordCount
        let uniqueChars = Double(Set(chars).count)

        for i in 0..<(embeddingDimension / 4) {
            let offset = 3 * embeddingDimension / 4
            switch i % 3 {
            case 0:
                embedding[offset + i] = min(wordCount / 100.0, 1.0)
            case 1:
                embedding[offset + i] = min(avgWordLength / 10.0, 1.0)
            case 2:
                embedding[offset + i] = min(uniqueChars / 50.0, 1.0)
            default:
                break
            }
        }

        // Normalize the embedding vector
        return normalizeVector(embedding)
    }

    /// Normalize vector to unit length
    private func normalizeVector(_ vector: [Double]) -> [Double] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    // MARK: - Real Claude API Integration (Future Enhancement)

    /*
    /// Call Claude API for real embeddings (placeholder for future implementation)
    private func callClaudeEmbeddingAPI(for text: String) async throws -> [Double] {
        let url = URL(string: "https://api.anthropic.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "text": text,
            "model": "claude-embedding-v1" // Hypothetical model name
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw EmbeddingError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let embedding = json["embedding"] as? [Double] else {
            throw EmbeddingError.invalidResponse
        }

        return embedding
    }
    */
}

// MARK: - Similarity Calculation

extension EmbeddingService {

    /// Calculate cosine similarity between two embeddings
    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else {
            return 0.0
        }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0, magnitudeB > 0 else {
            return 0.0
        }

        return dotProduct / (magnitudeA * magnitudeB)
    }

    /// Calculate Euclidean distance between two embeddings
    static func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else {
            return Double.infinity
        }

        let sumSquaredDiff = zip(a, b)
            .map { ($0 - $1) * ($0 - $1) }
            .reduce(0, +)

        return sqrt(sumSquaredDiff)
    }
}
