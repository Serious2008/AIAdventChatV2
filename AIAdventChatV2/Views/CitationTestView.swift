//
//  CitationTestView.swift
//  AIAdventChatV2
//
//  View for testing mandatory citations in RAG answers
//

import SwiftUI

struct CitationTestView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var testResults: [CitationTestResult] = []
    @State private var isTesting: Bool = false
    @State private var currentTestIndex: Int = 0

    // Test questions
    let testQuestions = [
        "Как работает векторный поиск?",
        "Где сохраняются сообщения чата?",
        "Какие MCP серверы поддерживаются?",
        "Как реализована индексация документов?",
        "Что делает EmbeddingService?"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Citation Testing")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Тестирование обязательных цитат в RAG ответах")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Test Info
                    GroupBox(label: Label("Информация", systemImage: "info.circle.fill")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Этот тест проверяет, что модель:")
                            Text("✅ Включает маркеры источников [Источник N]")
                            Text("✅ Добавляет секцию 'Источники:'")
                            Text("✅ Упоминает файлы (.swift)")
                            Text("✅ Использует блоки кода ```")
                        }
                        .font(.body)
                        .padding()
                    }
                    .padding(.horizontal)

                    // Test Progress
                    if isTesting {
                        GroupBox {
                            VStack(spacing: 12) {
                                ProgressView(value: Double(currentTestIndex), total: Double(testQuestions.count))

                                Text("Тестирую вопрос \(currentTestIndex + 1) из \(testQuestions.count)")
                                    .font(.headline)

                                Text(testQuestions[safe: currentTestIndex] ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                    }

                    // Start Test Button
                    if !isTesting && testResults.isEmpty {
                        Button(action: runTests) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Запустить тест на 5 вопросах")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    // Test Results
                    if !testResults.isEmpty {
                        VStack(spacing: 16) {
                            // Summary
                            GroupBox(label: Label("Результаты", systemImage: "checkmark.circle.fill")) {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Пройдено:")
                                            .font(.headline)
                                        Spacer()
                                        Text("\(passedCount)/\(testResults.count)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(passedCount == testResults.count ? .green : .orange)
                                    }

                                    Divider()

                                    HStack {
                                        Text("Success Rate:")
                                        Spacer()
                                        Text("\(String(format: "%.0f%%", successRate * 100))")
                                            .fontWeight(.bold)
                                            .foregroundColor(successRate == 1.0 ? .green : .orange)
                                    }

                                    Divider()

                                    HStack {
                                        Text("Среднее цитат:")
                                        Spacer()
                                        Text("\(String(format: "%.1f", averageCitations))")
                                            .fontWeight(.bold)
                                    }
                                }
                                .padding()
                            }
                            .padding(.horizontal)

                            // Individual Results
                            Text("Детальные результаты")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)

                            ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                                CitationTestResultCard(index: index + 1, result: result)
                                    .padding(.horizontal)
                            }

                            // Reset Button
                            Button(action: resetTests) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Запустить заново")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 40)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Citation Testing")
        }
    }

    // MARK: - Actions

    private func runTests() {
        isTesting = true
        currentTestIndex = 0
        testResults = []

        Task {
            for (index, question) in testQuestions.enumerated() {
                await MainActor.run {
                    currentTestIndex = index
                }

                do {
                    let result = try await testQuestion(question)
                    await MainActor.run {
                        testResults.append(result)
                    }
                } catch {
                    await MainActor.run {
                        testResults.append(CitationTestResult(
                            question: question,
                            answer: "Error: \(error.localizedDescription)",
                            validation: CitationValidation(
                                hasSourceMarkers: false,
                                hasSourcesSection: false,
                                hasFileReferences: false,
                                hasCodeBlocks: false,
                                citationCount: 0
                            ),
                            processingTime: 0
                        ))
                    }
                }
            }

            await MainActor.run {
                isTesting = false
            }
        }
    }

    private func testQuestion(_ question: String) async throws -> CitationTestResult {
        // Use ChatViewModel method
        let (answer, validation, processingTime) = try await viewModel.testCitationQuestion(question: question)

        return CitationTestResult(
            question: question,
            answer: answer,
            validation: validation,
            processingTime: processingTime
        )
    }

    private func resetTests() {
        testResults = []
        currentTestIndex = 0
    }

    // MARK: - Computed Properties

    private var passedCount: Int {
        testResults.filter { $0.validation.isValid }.count
    }

    private var successRate: Double {
        guard !testResults.isEmpty else { return 0 }
        return Double(passedCount) / Double(testResults.count)
    }

    private var averageCitations: Double {
        guard !testResults.isEmpty else { return 0 }
        let total = testResults.reduce(0) { $0 + $1.validation.citationCount }
        return Double(total) / Double(testResults.count)
    }
}

// MARK: - Test Result Model

struct CitationTestResult {
    let question: String
    let answer: String
    let validation: CitationValidation
    let processingTime: TimeInterval
}

// MARK: - Result Card

struct CitationTestResultCard: View {
    let index: Int
    let result: CitationTestResult
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: result.validation.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.validation.isValid ? .green : .red)

                Text("Вопрос \(index)")
                    .font(.headline)

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                }
            }

            // Question
            Text(result.question)
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            // Validation Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(result.validation.citationCount) цитат", systemImage: "quote.bubble")
                        .font(.caption)
                    Label("\(String(format: "%.2fs", result.processingTime))", systemImage: "clock")
                        .font(.caption)
                }

                Spacer()

                Text("Качество: \(String(format: "%.0f%%", result.validation.score * 100))")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor.opacity(0.2))
                    .foregroundColor(scoreColor)
                    .cornerRadius(4)
            }

            // Expanded Details
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Проверка:")
                        .font(.headline)

                    Text(result.validation.summary)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    Divider()

                    Text("Ответ:")
                        .font(.headline)

                    ScrollView {
                        Text(result.answer)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(result.validation.isValid ? Color.green : Color.red, lineWidth: 2)
        )
    }

    private var scoreColor: Color {
        let score = result.validation.score
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Preview

#Preview {
    CitationTestView(viewModel: ChatViewModel(settings: Settings()))
}
