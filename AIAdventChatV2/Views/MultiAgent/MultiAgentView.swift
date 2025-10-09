//
//  MultiAgentView.swift
//  AIAdventChatV2
//
//  Created by Claude on 10.10.2025.
//

import SwiftUI

struct MultiAgentView: View {
    @ObservedObject var settings: Settings
    @State private var userTask: String = ""
    @State private var isProcessing: Bool = false
    @State private var result: MultiAgentResult?
    @State private var errorMessage: String?

    private let multiAgentService: MultiAgentService

    init(settings: Settings) {
        self.settings = settings
        self.multiAgentService = MultiAgentService(
            apiKey: settings.apiKey,
            temperature: settings.temperature
        )
    }

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
                    // Описание
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Как это работает")
                                .font(.headline)
                                .fontWeight(.bold)
                        }

                        Text("Система использует два специализированных агента:")
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("🤖 1.")
                                    .font(.headline)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Агент-Планировщик")
                                        .fontWeight(.semibold)
                                    Text("Анализирует задачу и создает детальный план действий")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("🛠️ 2.")
                                    .font(.headline)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Агент-Реализатор")
                                        .fontWeight(.semibold)
                                    Text("Использует план для создания конкретного решения")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

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
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )

                        Text("Пример: \"Создай алгоритм сортировки массива чисел\"")
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
                            Text(isProcessing ? "Агенты работают..." : "Запустить Multi-Agent")
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
                    if let result = result {
                        ResultView(result: result)
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

        let service = MultiAgentService(apiKey: settings.apiKey, temperature: settings.temperature)

        service.executeMultiAgentTask(userTask: userTask) { taskResult in
            DispatchQueue.main.async {
                isProcessing = false

                switch taskResult {
                case .success(let data):
                    result = data
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
