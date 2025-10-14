//
//  YandexTrackerTestView.swift
//  AIAdventChatV2
//
//  Test view for Yandex Tracker MCP integration with Agent
//

import SwiftUI

struct YandexTrackerTestView: View {
    @StateObject private var settings = Settings()
    @StateObject private var agent: YandexTrackerAgentViewModel = YandexTrackerAgentViewModel()

    @State private var taskQuery: String = "Сколько открытых задач?"
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Header
                Text("🤖 Yandex Tracker Agent Test")
                    .font(.largeTitle)
                    .bold()

                Divider()

                // MARK: - Configuration Section
                configurationSection

                Divider()

                // MARK: - Task Execution Section
                taskExecutionSection

                Divider()

                // MARK: - Result Section
                resultSection

            }
            .padding()
        }
        .navigationTitle("Yandex Tracker Agent")
    }

    // MARK: - Configuration Section

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚙️ Конфигурация")
                .font(.headline)

            if settings.isYandexTrackerConfigured {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Organization ID: \(settings.yandexTrackerOrgId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Token: \(String(settings.yandexTrackerToken.prefix(20)))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Изменить") {
                        showSettings = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚠️ Yandex Tracker не настроен")
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)

                    Text("Перейдите в настройки и заполните Organization ID и OAuth Token")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Открыть настройки") {
                        showSettings = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            Button(action: {
                Task {
                    await agent.configure(
                        orgId: settings.yandexTrackerOrgId,
                        token: settings.yandexTrackerToken
                    )
                }
            }) {
                HStack {
                    if agent.isConfiguring {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 5)
                    }

                    Text(agent.isConfigured ? "✅ Настроено" : "Подключить агента")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!settings.isYandexTrackerConfigured || agent.isConfiguring)

            if let error = agent.errorMessage {
                Text("❌ Ошибка: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
    }

    // MARK: - Task Execution Section

    private var taskExecutionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎯 Выполнение задачи")
                .font(.headline)

            Text("Примеры запросов:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                exampleQuery("Сколько открытых задач?")
                exampleQuery("Получи статистику по всем задачам")
                exampleQuery("Покажи все открытые задачи")
            }
            .font(.caption)
            .foregroundColor(.blue)

            TextField("Задача для агента", text: $taskQuery, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Button(action: {
                Task {
                    await agent.executeTask(task: taskQuery)
                }
            }) {
                HStack {
                    if agent.isExecuting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 5)
                    }

                    Text("▶️ Выполнить задачу")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!agent.isConfigured || taskQuery.isEmpty || agent.isExecuting)
        }
    }

    private func exampleQuery(_ text: String) -> some View {
        Button(action: {
            taskQuery = text
        }) {
            HStack {
                Text("•")
                Text(text)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result Section

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Результат")
                .font(.headline)

            if let result = agent.lastResult {
                ScrollView {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(height: 300)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)
                }) {
                    Label("Копировать результат", systemImage: "doc.on.doc")
                }
            } else {
                Text("Результат появится здесь после выполнения задачи")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

// MARK: - View Model

@MainActor
class YandexTrackerAgentViewModel: ObservableObject {
    @Published var isConfigured = false
    @Published var isConfiguring = false
    @Published var isExecuting = false
    @Published var errorMessage: String?
    @Published var lastResult: String?

    private var agent: YandexTrackerAgent?

    func configure(orgId: String, token: String) async {
        isConfiguring = true
        errorMessage = nil

        do {
            // Получаем API ключ из UserDefaults (или можно запросить у пользователя)
            // Для теста используем заглушку
            let apiKey = "your-api-key-here"

            let newAgent = YandexTrackerAgent(apiKey: apiKey)
            try await newAgent.configure(orgId: orgId, token: token)

            self.agent = newAgent
            self.isConfigured = true

        } catch {
            self.errorMessage = error.localizedDescription
            self.isConfigured = false
        }

        isConfiguring = false
    }

    func executeTask(task: String) async {
        guard let agent = agent else {
            errorMessage = "Агент не настроен"
            return
        }

        isExecuting = true
        errorMessage = nil
        lastResult = nil

        do {
            let result = try await agent.executeTask(task: task)
            self.lastResult = result

        } catch {
            self.errorMessage = error.localizedDescription
            self.lastResult = "❌ Ошибка: \(error.localizedDescription)"
        }

        isExecuting = false
    }
}

// MARK: - Preview

struct YandexTrackerTestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            YandexTrackerTestView()
        }
    }
}
