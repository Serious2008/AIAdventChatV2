//
//  EmbeddingService.swift
//  AIAdventChatV2
//
//  Service for generating text embeddings using OpenAI API
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
        case rateLimitExceeded
    }

    private let apiKey: String
    private let model: String
    private let embeddingDimension: Int

    // MARK: - Init

    init(apiKey: String, model: String = "text-embedding-3-small") {
        self.apiKey = apiKey
        self.model = model
        // text-embedding-3-small: 1536 dimensions
        // text-embedding-3-large: 3072 dimensions
        self.embeddingDimension = model == "text-embedding-3-small" ? 1536 : 3072
    }

    // MARK: - Public Methods

    /// Generate embedding for a single text chunk using OpenAI API
    func generateEmbedding(for text: String) async throws -> [Double] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyText
        }

        guard !apiKey.isEmpty else {
            throw EmbeddingError.invalidAPIKey
        }

        return try await callOpenAIEmbeddingAPI(for: text)
    }

    /// Generate embeddings for multiple chunks (batch processing)
    /// OpenAI supports up to 2048 inputs per request
    func generateEmbeddings(for chunks: [DocumentChunk]) async throws -> [DocumentChunk] {
        var updatedChunks: [DocumentChunk] = []
        let batchSize = 100 // Process 100 chunks at a time to avoid rate limits

        for batchStart in stride(from: 0, to: chunks.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, chunks.count)
            let batch = Array(chunks[batchStart..<batchEnd])

            // Extract texts for batch
            let texts = batch.map { $0.content }

            // Get embeddings for batch
            let embeddings = try await callOpenAIEmbeddingAPI(for: texts)

            // Create updated chunks
            for (index, chunk) in batch.enumerated() {
                let updatedChunk = DocumentChunk(
                    id: chunk.id,
                    filePath: chunk.filePath,
                    fileName: chunk.fileName,
                    content: chunk.content,
                    chunkIndex: chunk.chunkIndex,
                    embedding: embeddings[index],
                    metadata: chunk.metadata,
                    createdAt: chunk.createdAt
                )

                updatedChunks.append(updatedChunk)
            }

            // Small delay between batches to avoid rate limiting
            if batchEnd < chunks.count {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            }
        }

        return updatedChunks
    }

    /// Generate embedding for search query
    func generateQueryEmbedding(for query: String) async throws -> [Double] {
        return try await generateEmbedding(for: query)
    }

    // MARK: - Private Methods

    /// Call OpenAI API for single embedding
    private func callOpenAIEmbeddingAPI(for text: String) async throws -> [Double] {
        let embeddings = try await callOpenAIEmbeddingAPI(for: [text])
        return embeddings[0]
    }

    /// Call OpenAI API for batch embeddings
    private func callOpenAIEmbeddingAPI(for texts: [String]) async throws -> [[Double]] {
        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "input": texts.count == 1 ? texts[0] : texts,
            "model": model
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.networkError("Invalid response")
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            throw EmbeddingError.rateLimitExceeded
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw EmbeddingError.invalidResponse
        }

        var embeddings: [[Double]] = []
        for item in dataArray {
            guard let embedding = item["embedding"] as? [Double] else {
                throw EmbeddingError.invalidResponse
            }
            embeddings.append(embedding)
        }

        return embeddings
    }
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
