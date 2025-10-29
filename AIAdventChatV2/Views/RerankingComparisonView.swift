//
//  RerankingComparisonView.swift
//  AIAdventChatV2
//
//  View for comparing different reranking strategies
//

import SwiftUI

struct RerankingComparisonView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var question: String = ""
    @State private var isComparing: Bool = false
    @State private var comparisonResult: RerankingComparisonResult?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reranking Strategies Comparison")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Сравните качество разных стратегий фильтрации результатов поиска")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Quick Examples
                    GroupBox(label: Label("Примеры вопросов", systemImage: "lightbulb.fill")) {
                        VStack(spacing: 8) {
                            QuickQuestionButton(
                                question: "Как работает векторный поиск?",
                                onTap: { question = $0 }
                            )
                            QuickQuestionButton(
                                question: "Где обрабатываются ошибки API?",
                                onTap: { question = $0 }
                            )
                            QuickQuestionButton(
                                question: "Как сохраняются сообщения чата?",
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

                            Button(action: compareStrategies) {
                                HStack {
                                    if isComparing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .padding(.trailing, 4)
                                    }
                                    Text(isComparing ? "Сравниваем..." : "Сравнить стратегии")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(question.isEmpty ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(question.isEmpty || isComparing)
                        }
                        .padding()
                    }
                    .padding(.horizontal)

                    // Error Message
                    if let error = errorMessage {
                        GroupBox {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                    }

                    // Comparison Results
                    if let result = comparisonResult {
                        VStack(spacing: 20) {
                            // Summary
                            GroupBox(label: Label("Сводка", systemImage: "chart.bar.fill")) {
                                Text(result.summary)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                            }
                            .padding(.horizontal)

                            // Strategy Comparison Grid
                            VStack(spacing: 16) {
                                Text("Ответы по стратегиям")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)

                                // Grid of 4 strategies
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        StrategyResultCard(
                                            title: "1️⃣ Без фильтра",
                                            response: result.noFilterResults,
                                            color: .gray
                                        )

                                        StrategyResultCard(
                                            title: "2️⃣ Threshold (50%)",
                                            response: result.thresholdResults,
                                            color: .blue
                                        )
                                    }

                                    HStack(spacing: 12) {
                                        StrategyResultCard(
                                            title: "3️⃣ Adaptive",
                                            response: result.adaptiveResults,
                                            color: .orange
                                        )

                                        StrategyResultCard(
                                            title: "4️⃣ LLM-based",
                                            response: result.llmResults,
                                            color: .green
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // Filtered Files Comparison
                            GroupBox(label: Label("Что отфильтровано", systemImage: "line.3.horizontal.decrease.circle")) {
                                Text(result.detailedComparison)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                            }
                            .padding(.horizontal)

                            // Answers Comparison
                            VStack(spacing: 16) {
                                Text("Ответы LLM с разной фильтрацией")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)

                                VStack(spacing: 12) {
                                    AnswerComparisonCard(
                                        title: "1️⃣ Без фильтра",
                                        answer: result.noFilterResults.answer,
                                        color: .gray
                                    )

                                    AnswerComparisonCard(
                                        title: "2️⃣ Threshold (50%)",
                                        answer: result.thresholdResults.answer,
                                        color: .blue
                                    )

                                    AnswerComparisonCard(
                                        title: "3️⃣ Adaptive",
                                        answer: result.adaptiveResults.answer,
                                        color: .orange
                                    )

                                    AnswerComparisonCard(
                                        title: "4️⃣ LLM-based",
                                        answer: result.llmResults.answer,
                                        color: .green
                                    )
                                }
                                .padding(.horizontal)
                            }

                            // Analysis
                            GroupBox(label: Label("Анализ", systemImage: "sparkles")) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Рекомендация:")
                                        .font(.headline)

                                    Text(getRecommendation(result: result))
                                        .foregroundColor(.secondary)

                                    Divider()

                                    Text("Выводы:")
                                        .font(.headline)

                                    ForEach(getInsights(result: result), id: \.self) { insight in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("•")
                                            Text(insight)
                                        }
                                    }
                                }
                                .padding()
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 40)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Reranking Comparison")
        }
    }

    // MARK: - Actions

    private func compareStrategies() {
        guard !question.isEmpty else { return }

        isComparing = true
        errorMessage = nil
        comparisonResult = nil

        Task {
            do {
                let result = try await viewModel.compareRerankingStrategies(question: question)
                await MainActor.run {
                    comparisonResult = result
                    isComparing = false
                }
            } catch {
                await MainActor.run {
                    // Extract more detailed error message
                    let errorDetail = "\(error)"
                    if errorDetail.contains("API key not found") {
                        errorMessage = "❌ API ключ Claude не найден. Добавьте его в Settings."
                    } else if errorDetail.contains("HTTP 401") {
                        errorMessage = "❌ Неверный API ключ Claude. Проверьте настройки."
                    } else if errorDetail.contains("HTTP") {
                        errorMessage = "❌ Ошибка API: \(errorDetail)"
                    } else {
                        errorMessage = "❌ Ошибка: \(error.localizedDescription)\n\nДетали: \(errorDetail)"
                    }
                    isComparing = false
                }
            }
        }
    }

    // MARK: - Analysis Helpers

    private func getRecommendation(result: RerankingComparisonResult) -> String {
        let thresholdCount = result.thresholdResults.usedChunks.count
        let adaptiveCount = result.adaptiveResults.usedChunks.count
        let llmCount = result.llmResults.usedChunks.count

        let thresholdAvgSim = result.thresholdResults.usedChunks.map(\.similarity).reduce(0, +) / Double(max(thresholdCount, 1))
        let llmAvgSim = result.llmResults.usedChunks.map(\.similarity).reduce(0, +) / Double(max(llmCount, 1))

        if llmAvgSim > thresholdAvgSim + 0.1 {
            return "🏆 LLM-based показал лучшую релевантность. Рекомендуется для критически важных запросов."
        } else if thresholdCount == llmCount && abs(thresholdAvgSim - llmAvgSim) < 0.05 {
            return "⚡ Threshold дал сопоставимый результат с LLM, но быстрее и дешевле. Рекомендуется для продакшена."
        } else if adaptiveCount > thresholdCount {
            return "📊 Adaptive нашёл больше релевантных результатов. Подходит для динамических запросов."
        } else {
            return "✅ Threshold (50%) показал хороший баланс точности и производительности."
        }
    }

    private func getInsights(result: RerankingComparisonResult) -> [String] {
        var insights: [String] = []

        // Compare counts
        let counts = [
            result.noFilterResults.usedChunks.count,
            result.thresholdResults.usedChunks.count,
            result.adaptiveResults.usedChunks.count,
            result.llmResults.usedChunks.count
        ]

        if counts.allSatisfy({ $0 == counts[0] }) {
            insights.append("Все стратегии выбрали одинаковое количество результатов")
        } else {
            insights.append("Стратегии отфильтровали разное количество результатов: \(counts[0]) → \(counts[1]) → \(counts[2]) → \(counts[3])")
        }

        // Compare processing times
        let llmTime = result.llmResults.processingTime
        let thresholdTime = result.thresholdResults.processingTime
        if llmTime > thresholdTime * 1.5 {
            let diff = llmTime - thresholdTime
            insights.append("LLM-based медленнее на \(String(format: "%.2f", diff))s из-за дополнительного запроса к API")
        }

        // Check similarity threshold effectiveness
        let noFilterMin = result.noFilterResults.usedChunks.last?.similarity ?? 0
        let thresholdMin = result.thresholdResults.usedChunks.last?.similarity ?? 0
        if noFilterMin < 0.5 && thresholdMin >= 0.5 {
            insights.append("Threshold успешно отсек результаты с similarity < 50%")
        }

        return insights
    }
}

// MARK: - Strategy Result Card

struct StrategyResultCard: View {
    let title: String
    let response: RAGResponse
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(response.usedChunks.count) sources")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Stats
            VStack(alignment: .leading, spacing: 6) {
                StatRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Avg similarity",
                    value: String(format: "%.1f%%", avgSimilarity * 100),
                    color: similarityColor
                )

                StatRow(
                    icon: "clock",
                    label: "Time",
                    value: String(format: "%.2fs", response.processingTime),
                    color: .secondary
                )

                StatRow(
                    icon: "doc.text",
                    label: "Answer length",
                    value: "\(response.answer.count) chars",
                    color: .secondary
                )
            }

            Divider()

            // Sources preview
            if !response.usedChunks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sources:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(response.usedChunks.prefix(3), id: \.chunk.id) { result in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                            Text(result.chunk.fileName)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(result.similarity * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if response.usedChunks.count > 3 {
                        Text("+\(response.usedChunks.count - 3) more...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }

    private var avgSimilarity: Double {
        guard !response.usedChunks.isEmpty else { return 0 }
        return response.usedChunks.map(\.similarity).reduce(0, +) / Double(response.usedChunks.count)
    }

    private var similarityColor: Color {
        if avgSimilarity > 0.7 {
            return .green
        } else if avgSimilarity > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Answer Comparison Card

struct AnswerComparisonCard: View {
    let title: String
    let answer: String
    let color: Color
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(color)
                }
            }

            Divider()

            // Answer preview or full
            if isExpanded {
                ScrollView {
                    Text(answer)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            } else {
                Text(answer.prefix(200) + (answer.count > 200 ? "..." : ""))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            // Stats
            HStack {
                Label("\(answer.count) символов", systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(isExpanded ? "Свернуть" : "Развернуть") {
                    isExpanded.toggle()
                }
                .font(.caption)
                .foregroundColor(color)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    RerankingComparisonView(viewModel: ChatViewModel(settings: Settings()))
}
