//
//  RAGComparisonView.swift
//  AIAdventChatV2
//
//  View for comparing RAG vs non-RAG responses
//

import SwiftUI

struct RAGComparisonView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var question: String = ""
    @State private var isComparing: Bool = false
    @State private var comparisonResult: RAGComparisonResult?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RAG Comparison")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Сравните ответы модели с RAG и без RAG")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Quick Examples
                    GroupBox(label: Label("Примеры вопросов", systemImage: "lightbulb.fill")) {
                        VStack(spacing: 8) {
                            QuickQuestionButton(
                                question: "Как реализована аутентификация в проекте?",
                                onTap: { question = $0 }
                            )
                            QuickQuestionButton(
                                question: "Какие сервисы используются для работы с базой данных?",
                                onTap: { question = $0 }
                            )
                            QuickQuestionButton(
                                question: "Как работает векторный поиск?",
                                onTap: { question = $0 }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Question Input
                    GroupBox(label: Label("Ваш вопрос", systemImage: "questionmark.circle.fill")) {
                        VStack(spacing: 12) {
                            TextEditor(text: $question)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)

                            Button(action: {
                                compareAnswers()
                            }) {
                                HStack {
                                    if isComparing {
                                        ProgressView()
                                            .controlSize(.small)
                                            .padding(.trailing, 4)
                                    }
                                    Text(isComparing ? "Сравниваем..." : "Сравнить ответы")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(question.isEmpty || isComparing)
                        }
                    }
                    .padding(.horizontal)

                    // Comparison Results
                    if let result = comparisonResult {
                        ComparisonResultView(result: result)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("RAG Comparison")
        }
    }

    private func compareAnswers() {
        isComparing = true

        Task {
            do {
                let result = try await viewModel.compareRAG(question: question)

                await MainActor.run {
                    comparisonResult = result
                    isComparing = false
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = "Ошибка сравнения: \(error.localizedDescription)"
                    isComparing = false
                }
            }
        }
    }
}

// MARK: - Quick Question Button

struct QuickQuestionButton: View {
    let question: String
    let onTap: (String) -> Void

    var body: some View {
        Button(action: { onTap(question) }) {
            HStack {
                Text(question)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.blue)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Comparison Result View

struct ComparisonResultView: View {
    let result: RAGComparisonResult

    var body: some View {
        VStack(spacing: 16) {
            // Statistics
            GroupBox(label: Label("Статистика", systemImage: "chart.bar.fill")) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Время с RAG:")
                        Spacer()
                        Text(String(format: "%.2fs", result.ragProcessingTime))
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Время без RAG:")
                        Spacer()
                        Text(String(format: "%.2fs", result.noRAGProcessingTime))
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Использовано источников:")
                        Spacer()
                        Text("\(result.usedChunks.count)")
                            .fontWeight(.semibold)
                    }
                }
                .font(.body)
            }

            // Used Chunks
            if !result.usedChunks.isEmpty {
                GroupBox(label: Label("Использованные источники", systemImage: "doc.text.fill")) {
                    VStack(spacing: 8) {
                        ForEach(Array(result.usedChunks.enumerated()), id: \.element.id) { index, chunk in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(index + 1). \(chunk.chunk.fileName)")
                                        .font(.caption)
                                        .fontWeight(.medium)

                                    Text(chunk.preview)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Text(String(format: "%.1f%%", chunk.similarity * 100))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(similarityColor(chunk.similarity))
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Side-by-side comparison
            HStack(spacing: 12) {
                // With RAG
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.green)
                        Text("С RAG")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    ScrollView {
                        Text(result.withRAG)
                            .font(.body)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 400)
                }
                .frame(maxWidth: .infinity)

                // Without RAG
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.bubble")
                            .foregroundColor(.orange)
                        Text("Без RAG")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    ScrollView {
                        Text(result.withoutRAG)
                            .font(.body)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.05))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 400)
                }
                .frame(maxWidth: .infinity)
            }

            // Analysis
            GroupBox(label: Label("Анализ", systemImage: "brain.head.profile")) {
                VStack(alignment: .leading, spacing: 12) {
                    AnalysisRow(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        title: "RAG помог",
                        description: result.ragHelpedDescription
                    )

                    if let limitation = result.ragLimitation {
                        AnalysisRow(
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            title: "Ограничение RAG",
                            description: limitation
                        )
                    }
                }
            }
        }
    }

    private func similarityColor(_ similarity: Double) -> Color {
        if similarity > 0.7 {
            return .green
        } else if similarity > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Analysis Row

struct AnalysisRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Comparison Result Model

struct RAGComparisonResult {
    let question: String
    let withRAG: String
    let withoutRAG: String
    let usedChunks: [SearchResult]
    let ragProcessingTime: TimeInterval
    let noRAGProcessingTime: TimeInterval

    var ragHelpedDescription: String {
        if usedChunks.isEmpty {
            return "Не найдено релевантных источников в кодовой базе"
        }

        let avgSimilarity = usedChunks.map(\.similarity).reduce(0, +) / Double(usedChunks.count)

        if avgSimilarity > 0.7 {
            return "RAG предоставил высоко релевантный контекст из \(usedChunks.count) источников. Ответ содержит конкретные детали из кода."
        } else if avgSimilarity > 0.5 {
            return "RAG нашёл частично релевантный контекст. Ответ может быть более точным при лучшем индексировании."
        } else {
            return "RAG нашёл контекст с низкой релевантностью. Возможно, нужно переформулировать вопрос."
        }
    }

    var ragLimitation: String? {
        if usedChunks.isEmpty {
            return "Необходимо проиндексировать больше файлов проекта"
        }

        let avgSimilarity = usedChunks.map(\.similarity).reduce(0, +) / Double(usedChunks.count)
        if avgSimilarity < 0.5 {
            return "Найденный контекст имеет низкую релевантность. Попробуйте более конкретный вопрос."
        }

        return nil
    }
}

// MARK: - Reranking Comparison Result

struct RerankingComparisonResult {
    let question: String
    let originalResults: [SearchResult]
    let noFilterResults: RAGResponse
    let thresholdResults: RAGResponse
    let adaptiveResults: RAGResponse
    let llmResults: RAGResponse

    var summary: String {
        """
        📊 СРАВНЕНИЕ RERANKING СТРАТЕГИЙ

        Вопрос: \(question)
        Исходных кандидатов: \(originalResults.count)

        1️⃣ Без фильтра: \(noFilterResults.usedChunks.count) результатов
           Мин. similarity: \(String(format: "%.1f%%", (noFilterResults.usedChunks.last?.similarity ?? 0) * 100))
           Время: \(String(format: "%.2f", noFilterResults.processingTime))s

        2️⃣ Threshold (50%): \(thresholdResults.usedChunks.count) результатов
           Мин. similarity: \(String(format: "%.1f%%", (thresholdResults.usedChunks.last?.similarity ?? 0) * 100))
           Время: \(String(format: "%.2f", thresholdResults.processingTime))s

        3️⃣ Adaptive: \(adaptiveResults.usedChunks.count) результатов
           Мин. similarity: \(String(format: "%.1f%%", (adaptiveResults.usedChunks.last?.similarity ?? 0) * 100))
           Время: \(String(format: "%.2f", adaptiveResults.processingTime))s

        4️⃣ LLM-based: \(llmResults.usedChunks.count) результатов
           Мин. similarity: \(String(format: "%.1f%%", (llmResults.usedChunks.last?.similarity ?? 0) * 100))
           Время: \(String(format: "%.2f", llmResults.processingTime))s
        """
    }

    // Helper: Get files that were filtered out by a strategy
    func filteredOut(baseline: [SearchResult], filtered: [SearchResult]) -> [SearchResult] {
        let filteredIDs = Set(filtered.map { $0.chunk.id })
        return baseline.filter { !filteredIDs.contains($0.chunk.id) }
    }

    // Detailed comparison showing what each strategy filtered
    var detailedComparison: String {
        let baseFiles = Set(noFilterResults.usedChunks.map { $0.chunk.fileName })
        let thresholdFiles = Set(thresholdResults.usedChunks.map { $0.chunk.fileName })
        let adaptiveFiles = Set(adaptiveResults.usedChunks.map { $0.chunk.fileName })
        let llmFiles = Set(llmResults.usedChunks.map { $0.chunk.fileName })

        let thresholdFiltered = baseFiles.subtracting(thresholdFiles)
        let adaptiveFiltered = baseFiles.subtracting(adaptiveFiles)
        let llmFiltered = baseFiles.subtracting(llmFiles)

        var result = "🎯 ЧТО ОТФИЛЬТРОВАЛА КАЖДАЯ СТРАТЕГИЯ:\n\n"

        if thresholdFiltered.isEmpty {
            result += "Threshold: Ничего не отфильтровал\n"
        } else {
            result += "Threshold отфильтровал: \(thresholdFiltered.joined(separator: ", "))\n"
        }

        if adaptiveFiltered.isEmpty {
            result += "Adaptive: Ничего не отфильтровал\n"
        } else {
            result += "Adaptive отфильтровал: \(adaptiveFiltered.joined(separator: ", "))\n"
        }

        if llmFiltered.isEmpty {
            result += "LLM-based: Ничего не отфильтровал\n"
        } else {
            result += "LLM-based отфильтровал: \(llmFiltered.joined(separator: ", "))\n"
        }

        return result
    }
}

// MARK: - Preview

#Preview {
    RAGComparisonView(viewModel: ChatViewModel(settings: Settings()))
}
