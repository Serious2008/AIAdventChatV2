//
//  MultiAgentView.swift
//  AIAdventChatV2
//
//  Created by Claude on 10.10.2025.
//

import SwiftUI

enum AgentMode: String, CaseIterable, Identifiable {
    case plannerImplementer = "Планировщик → Реализатор"
    case solverReviewer = "Решатель → Проверяющий"

    var id: String { self.rawValue }

    var description: String {
        switch self {
        case .plannerImplementer:
            return "Агент 1 создает план, Агент 2 реализует его"
        case .solverReviewer:
            return "Агент 1 решает задачу, Агент 2 проверяет решение"
        }
    }

    var example: String {
        switch self {
        case .plannerImplementer:
            return "\"Создай систему аутентификации пользователей\""
        case .solverReviewer:
            return "\"Реши уравнение: 2x + 6 = 14\""
        }
    }
}

struct MultiAgentView: View {
    @ObservedObject var settings: Settings
    @State private var userTask: String = ""
    @State private var isProcessing: Bool = false
    @State private var plannerResult: MultiAgentResult?
    @State private var solverResult: SolverReviewerResult?
    @State private var errorMessage: String?
    @State private var selectedMode: AgentMode = .solverReviewer

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Multi-Agent System")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Выбор режима
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Выберите режим работы")
                            .font(.headline)
                            .fontWeight(.bold)

                        Picker("Режим", selection: $selectedMode) {
                            ForEach(AgentMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedMode) { _ in
                            // Очищаем результаты при смене режима
                            plannerResult = nil
                            solverResult = nil
                            errorMessage = nil
                        }

                        // Описание режима
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text(selectedMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)

                    // Описание системы
                    if selectedMode == .plannerImplementer {
                        PlannerImplementerInfoView()
                    } else {
                        SolverReviewerInfoView()
                    }

                    // Поле ввода задачи
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Введите задачу")
                            .font(.headline)
                            .fontWeight(.bold)

                        TextEditor(text: $userTask)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )

                        Text("Пример: \(selectedMode.example)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Кнопка запуска
                    Button(action: {
                        executeTask()
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text(isProcessing ? "Агенты работают..." : "🚀 Запустить Multi-Agent")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(userTask.isEmpty || isProcessing ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(userTask.isEmpty || isProcessing || !settings.isConfigured)
                    .buttonStyle(.plain)

                    // Результаты
                    if let result = plannerResult {
                        PlannerResultView(result: result)
                    }

                    if let result = solverResult {
                        SolverResultView(result: result)
                    }

                    // Ошибки
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }

    private func executeTask() {
        errorMessage = nil
        isProcessing = true
        plannerResult = nil
        solverResult = nil

        switch selectedMode {
        case .plannerImplementer:
            let service = MultiAgentService(apiKey: settings.apiKey, temperature: settings.temperature)
            service.executeMultiAgentTask(userTask: userTask) { taskResult in
                DispatchQueue.main.async {
                    isProcessing = false
                    switch taskResult {
                    case .success(let data):
                        plannerResult = data
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }

        case .solverReviewer:
            let service = SolverReviewerService(apiKey: settings.apiKey, temperature: settings.temperature)
            service.executeSolverReviewerTask(userTask: userTask) { taskResult in
                DispatchQueue.main.async {
                    isProcessing = false
                    switch taskResult {
                    case .success(let data):
                        solverResult = data
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Info Views

struct PlannerImplementerInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.circle.fill")
                    .foregroundColor(.blue)
                Text("Режим: Планировщик → Реализатор")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 8) {
                AgentDescriptionRow(
                    emoji: "🤖",
                    title: "Агент-Планировщик",
                    description: "Анализирует задачу и создает детальный план"
                )

                AgentDescriptionRow(
                    emoji: "🛠️",
                    title: "Агент-Реализатор",
                    description: "Использует план для создания решения"
                )
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SolverReviewerInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.circle.fill")
                    .foregroundColor(.green)
                Text("Режим: Решатель → Проверяющий")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 8) {
                AgentDescriptionRow(
                    emoji: "💡",
                    title: "Агент-Решатель",
                    description: "Решает задачу и дает полное решение"
                )

                AgentDescriptionRow(
                    emoji: "🔍",
                    title: "Агент-Проверяющий",
                    description: "Проверяет решение, находит ошибки, дает рекомендации"
                )
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AgentDescriptionRow: View {
    let emoji: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji)
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Planner Result View (existing)

struct PlannerResultView: View {
    let result: MultiAgentResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Общая информация
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Задача выполнена!")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(String(format: "%.2fs", result.totalTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            // Агент 1: Планировщик
            AgentResultCard(
                title: "🤖 Агент-Планировщик",
                subtitle: "Анализ и планирование",
                content: result.plannerResponse,
                metrics: result.plannerMetrics,
                color: .blue
            )

            // План (если распарсен)
            if let plan = result.plannerPlan {
                PlanCard(plan: plan)
            }

            // Агент 2: Реализатор
            AgentResultCard(
                title: "🛠️ Агент-Реализатор",
                subtitle: "Реализация решения",
                content: result.implementerResponse,
                metrics: result.implementerMetrics,
                color: .purple
            )

            // Реализация (если распарсена)
            if let implementation = result.implementation {
                ImplementationCard(implementation: implementation)
            }
        }
    }
}

// MARK: - Solver Result View (new)

struct SolverResultView: View {
    let result: SolverReviewerResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Общая информация
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Задача проверена!")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(String(format: "%.2fs", result.totalTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            // Агент 1: Решатель
            AgentResultCard(
                title: "💡 Агент-Решатель",
                subtitle: "Решение задачи",
                content: result.solverResponse,
                metrics: result.solverMetrics,
                color: .blue
            )

            // Решение (если распарсено)
            if let solution = result.solution {
                SolutionCard(solution: solution)
            }

            // Агент 2: Проверяющий
            AgentResultCard(
                title: "🔍 Агент-Проверяющий",
                subtitle: "Проверка и критика",
                content: result.reviewerResponse,
                metrics: result.reviewerMetrics,
                color: .orange
            )

            // Проверка (если распарсена)
            if let review = result.review {
                ReviewCard(review: review)
            }
        }
    }
}

// MARK: - Solution Card

struct SolutionCard: View {
    let solution: AgentSolution

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 Решение агента")
                .font(.headline)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                SectionView(title: "Ответ", content: solution.solution)

                Divider()

                SectionView(title: "Подход", content: solution.approach)

                Divider()

                SectionView(title: "Объяснение", content: solution.explanation)

                if let code = solution.code {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Код")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlColor))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: AgentReview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔍 Проверка решения")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                VerdictBadge(verdict: review.verdict)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Общая оценка
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.quote")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Общая оценка")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(review.overall_assessment)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)

                // Сильные стороны
                if !review.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Сильные стороны")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        ForEach(review.strengths, id: \.self) { strength in
                            HStack(alignment: .top, spacing: 8) {
                                Text("✓")
                                    .foregroundColor(.green)
                                Text(strength)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                }

                // Слабые стороны
                if !review.weaknesses.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Слабые стороны")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        ForEach(review.weaknesses, id: \.self) { weakness in
                            HStack(alignment: .top, spacing: 8) {
                                Text("⚠")
                                    .foregroundColor(.orange)
                                Text(weakness)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }

                // Ошибки
                if let errors = review.errors_found, !errors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Найденные ошибки")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        ForEach(errors, id: \.self) { error in
                            HStack(alignment: .top, spacing: 8) {
                                Text("✗")
                                    .foregroundColor(.red)
                                Text(error)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(8)
                }

                // Предложения
                if !review.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.blue)
                            Text("Предложения по улучшению")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        ForEach(review.suggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Text("💡")
                                Text(suggestion)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }

                // Исправленное решение
                if let corrected = review.corrected_solution {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Исправленное решение")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text(corrected)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlColor))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

struct VerdictBadge: View {
    let verdict: String

    var color: Color {
        switch verdict.lowercased() {
        case "correct":
            return .green
        case "incorrect":
            return .red
        case "partially_correct":
            return .orange
        default:
            return .gray
        }
    }

    var icon: String {
        switch verdict.lowercased() {
        case "correct":
            return "checkmark.circle.fill"
        case "incorrect":
            return "xmark.circle.fill"
        case "partially_correct":
            return "exclamationmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    var text: String {
        switch verdict.lowercased() {
        case "correct":
            return "Правильно"
        case "incorrect":
            return "Неправильно"
        case "partially_correct":
            return "Частично правильно"
        default:
            return verdict
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}




