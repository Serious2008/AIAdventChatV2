//
//  SettingsView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var showAPIKey = false
    @State private var testResult = ""
    @State private var trackerTestResult = ""
    @State private var isTestingTracker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // API Настройки секция
                    VStack(alignment: .leading, spacing: 16) {
                        Text("API Настройки")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 8)

                        // Temperature настройка
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Temperature (Температура)")
                                .font(.headline)
                                .fontWeight(.semibold)

                            HStack {
                                Text("0.0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $settings.temperature, in: 0.0...1.2, step: 0.1)
                                Text("1.2")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f", settings.temperature))
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .frame(width: 40)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(temperatureDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    Button("0.0") { settings.temperature = 0.0 }
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(settings.temperature == 0.0 ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(settings.temperature == 0.0 ? .white : .primary)
                                        .cornerRadius(4)

                                    Button("0.7") { settings.temperature = 0.7 }
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(settings.temperature == 0.7 ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(settings.temperature == 0.7 ? .white : .primary)
                                        .cornerRadius(4)

                                    Button("1.0") { settings.temperature = 1.0 }
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(settings.temperature == 1.0 ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(settings.temperature == 1.0 ? .white : .primary)
                                        .cornerRadius(4)

                                    Button("1.2") { settings.temperature = 1.2 }
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(settings.temperature == 1.2 ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(settings.temperature == 1.2 ? .white : .primary)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Provider Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI Provider")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Picker("Provider", selection: $settings.selectedProvider) {
                                ForEach(ModelProvider.allCases, id: \.self) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Model Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Модель")
                                .font(.headline)
                                .fontWeight(.semibold)

                            if settings.selectedProvider == .huggingface {
                                Picker("Модель", selection: $settings.selectedModel) {
                                    Text("Arch Router 1.5B (маленькая, быстрая)").tag("katanemo/Arch-Router-1.5B")
                                    Text("Phi-2 (маленькая)").tag("microsoft/phi-2")
                                    Text("Llama 3.1 8B (средняя)").tag("meta-llama/Llama-3.1-8B-Instruct")
                                    Text("Mistral 7B (средняя)").tag("mistralai/Mistral-7B-Instruct-v0.3")
                                    Text("DeepSeek V3 (большая)").tag("deepseek-ai/DeepSeek-V3-0324")
                                    Text("Qwen2.5 72B (большая)").tag("Qwen/Qwen2.5-72B-Instruct")
                                }
                                .pickerStyle(MenuPickerStyle())
                            } else if settings.selectedProvider == .local {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "house.fill")
                                            .foregroundColor(.green)
                                        Text("llama3.2:3b")
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("2GB")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Локальная модель - полная приватность, без затрат")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("Быстрая генерация на вашем Mac")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Text("claude-3-7-sonnet-20250219")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Summarization Toggle (только для Claude)
                        if settings.selectedProvider == .claude {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Суммаризация перед отправкой")
                                            .font(.headline)
                                            .fontWeight(.semibold)

                                        Text("Сжимайте длинные сообщения перед отправкой в Claude для экономии токенов")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $settings.summarizationEnabled)
                                        .labelsHidden()
                                        .disabled(settings.huggingFaceApiKey.isEmpty && settings.apiKey.isEmpty)
                                }

                                if settings.summarizationEnabled {
                                    Divider()
                                        .padding(.vertical, 4)

                                    VStack(alignment: .leading, spacing: 12) {
                                        // Выбор провайдера суммаризации
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Провайдер суммаризации")
                                                .font(.subheadline)
                                                .fontWeight(.medium)

                                            Picker("", selection: $settings.summarizationProvider) {
                                                ForEach(SummarizationProvider.allCases, id: \.self) { provider in
                                                    Text(provider.rawValue).tag(provider)
                                                }
                                            }
                                            .pickerStyle(SegmentedPickerStyle())
                                            .disabled(
                                                (settings.summarizationProvider == .huggingface && settings.huggingFaceApiKey.isEmpty) ||
                                                (settings.summarizationProvider == .claude && settings.apiKey.isEmpty)
                                            )

                                            // Предупреждение если нет ключа для выбранного провайдера
                                            if settings.summarizationProvider == .huggingface && settings.huggingFaceApiKey.isEmpty {
                                                HStack {
                                                    Image(systemName: "exclamationmark.triangle")
                                                        .foregroundColor(.orange)
                                                    Text("Требуется HuggingFace API ключ")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                }
                                            }

                                            if settings.summarizationProvider == .claude && settings.apiKey.isEmpty {
                                                HStack {
                                                    Image(systemName: "exclamationmark.triangle")
                                                        .foregroundColor(.orange)
                                                    Text("Требуется Claude API ключ")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                }
                                            }

                                            // Информация о выбранном провайдере
                                            HStack {
                                                Image(systemName: "info.circle")
                                                    .foregroundColor(.blue)
                                                    .font(.caption)
                                                switch settings.summarizationProvider {
                                                case .local:
                                                    Text("Локальный запуск модели (требует Python + transformers)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                case .huggingface:
                                                    Text("Бесплатная суммаризация через HuggingFace API")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                case .claude:
                                                    Text("Качественная суммаризация через Claude (расход токенов)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }

                                        Divider()
                                            .padding(.vertical, 4)

                                        Text("Минимальная длина для суммаризации")
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        HStack {
                                            Slider(value: Binding(
                                                get: { Double(settings.summarizationMinLength) },
                                                set: { settings.summarizationMinLength = Int($0) }
                                            ), in: 500...5000, step: 500)

                                            Text("\(settings.summarizationMinLength)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                                .frame(width: 50)
                                        }

                                        HStack(spacing: 4) {
                                            Image(systemName: "info.circle")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                            Text("Суммаризация применяется только к текстам длиннее \(settings.summarizationMinLength) символов (~\(settings.summarizationMinLength/4) токенов)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack(spacing: 12) {
                                            Button("500") { settings.summarizationMinLength = 500 }
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(settings.summarizationMinLength == 500 ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundColor(settings.summarizationMinLength == 500 ? .white : .primary)
                                                .cornerRadius(4)

                                            Button("1000") { settings.summarizationMinLength = 1000 }
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(settings.summarizationMinLength == 1000 ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundColor(settings.summarizationMinLength == 1000 ? .white : .primary)
                                                .cornerRadius(4)

                                            Button("2000") { settings.summarizationMinLength = 2000 }
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(settings.summarizationMinLength == 2000 ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundColor(settings.summarizationMinLength == 2000 ? .white : .primary)
                                                .cornerRadius(4)

                                            Button("3000") { settings.summarizationMinLength = 3000 }
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(settings.summarizationMinLength == 3000 ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundColor(settings.summarizationMinLength == 3000 ? .white : .primary)
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }

                        // Claude API Key
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Claude API Key")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Group {
                                    if showAPIKey {
                                        TextField("sk-ant-api03-...", text: $settings.apiKey)
                                    } else {
                                        SecureField("sk-ant-api03-...", text: $settings.apiKey)
                                    }
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                
                                Button(action: {
                                    showAPIKey.toggle()
                                }) {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Получите API ключ на https://console.anthropic.com/")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(.orange)
                                    Text("Нажмите на поле ввода и введите ваш API ключ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // HuggingFace API Key
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HuggingFace API Key")
                                .font(.headline)
                                .fontWeight(.semibold)

                            HStack {
                                Group {
                                    if showAPIKey {
                                        TextField("hf_...", text: $settings.huggingFaceApiKey)
                                    } else {
                                        SecureField("hf_...", text: $settings.huggingFaceApiKey)
                                    }
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )

                                Button(action: {
                                    showAPIKey.toggle()
                                }) {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Получите API ключ на https://huggingface.co/settings/tokens")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // OpenAI API Key
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OpenAI API Key")
                                .font(.headline)
                                .fontWeight(.semibold)

                            HStack {
                                Group {
                                    if showAPIKey {
                                        TextField("sk-proj-...", text: $settings.openAIApiKey)
                                    } else {
                                        SecureField("sk-proj-...", text: $settings.openAIApiKey)
                                    }
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )

                                Button(action: {
                                    showAPIKey.toggle()
                                }) {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Для векторного поиска. Получите ключ на https://platform.openai.com/api-keys")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }

                    // MARK: - Yandex Tracker Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Yandex Tracker")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Organization ID")
                                .font(.headline)
                                .fontWeight(.semibold)

                            TextField("12345678", text: $settings.yandexTrackerOrgId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Organization ID - это ЧИСЛО (например: 12345678)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fontWeight(.semibold)
                                        Text("Найдите в: Yandex Tracker → Settings → About organization")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("OAuth Token")
                                .font(.headline)
                                .fontWeight(.semibold)

                            HStack {
                                Group {
                                    if showAPIKey {
                                        TextField("y0_AgAAAAAA...", text: $settings.yandexTrackerToken)
                                    } else {
                                        SecureField("y0_AgAAAAAA...", text: $settings.yandexTrackerToken)
                                    }
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )

                                Button(action: {
                                    showAPIKey.toggle()
                                }) {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.orange)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.orange)
                                    Text("Создайте OAuth токен на https://oauth.yandex.ru/")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        HStack {
                            Circle()
                                .fill(settings.isYandexTrackerConfigured ? Color.green : Color.orange)
                                .frame(width: 12, height: 12)

                            Text(settings.isYandexTrackerConfigured ? "Yandex Tracker настроен" : "Заполните данные Yandex Tracker")
                                .foregroundColor(settings.isYandexTrackerConfigured ? .green : .orange)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Кнопка проверки соединения с Yandex Tracker
                        Button(action: {
                            testYandexTrackerConnection()
                        }) {
                            HStack {
                                if isTestingTracker {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.shield")
                                }
                                Text(isTestingTracker ? "Проверка..." : "Проверить подключение")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(settings.isYandexTrackerConfigured ? Color.orange : Color.gray)
                        .cornerRadius(8)
                        .disabled(!settings.isYandexTrackerConfigured || isTestingTracker)

                        // Результат теста Yandex Tracker
                        if !trackerTestResult.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if trackerTestResult.hasPrefix("✅") {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    Text(trackerTestResult)
                                        .font(.caption)
                                        .foregroundColor(trackerTestResult.hasPrefix("✅") ? .green : .red)
                                    Spacer()
                                    Button("✕") {
                                        trackerTestResult = ""
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(trackerTestResult.hasPrefix("✅") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }

                    // MARK: - MCP Tools Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MCP Инструменты")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Включайте только необходимые инструменты для экономии токенов")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // iOS Simulator Tools
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "iphone")
                                            .foregroundColor(.orange)
                                        Text("iOS Simulator")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }

                                    Text("Управление iOS симуляторами: запуск, остановка, скриншоты, установка приложений")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: $settings.enableSimulatorTools)
                                    .labelsHidden()
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Periodic Tasks Tools
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.green)
                                        Text("Периодические задачи")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }

                                    Text("Создание автоматических повторяющихся задач (например, ежечасная погода)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: $settings.enablePeriodicTaskTools)
                                    .labelsHidden()
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Yandex Tracker Tools
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "list.bullet.rectangle")
                                            .foregroundColor(.orange)
                                        Text("Yandex Tracker")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }

                                    Text("Работа с задачами Yandex Tracker: получение статистики, поиск, анализ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: $settings.enableYandexTrackerTools)
                                    .labelsHidden()
                                    .disabled(!settings.isYandexTrackerConfigured)
                            }

                            if !settings.isYandexTrackerConfigured {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Требуется настройка Yandex Tracker")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Статистика использования токенов
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Примерное потребление токенов:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            let activeToolsCount = [
                                settings.enableSimulatorTools,
                                settings.enablePeriodicTaskTools,
                                settings.enableYandexTrackerTools && settings.isYandexTrackerConfigured
                            ].filter { $0 }.count

                            let estimatedTokens = activeToolsCount * 500 + 200 // ~500 токенов на набор инструментов + базовый промпт

                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar")
                                    .foregroundColor(.blue)
                                Text("~\(estimatedTokens) токенов на запрос")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: activeToolsCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(activeToolsCount == 0 ? .green : .orange)
                                    .font(.caption)
                                Text(activeToolsCount == 0 ? "Все инструменты выключены - минимум токенов" : "Активно \(activeToolsCount) набор(ов) инструментов")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }

                    // MARK: - History Compression Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Сжатие истории диалога")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 8)

                        // Enable Compression
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundColor(.purple)
                                        Text("Включить сжатие")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }

                                    Text("Автоматически создавать summary для старых сообщений, уменьшая потребление токенов")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: $settings.historyCompressionEnabled)
                                    .labelsHidden()
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Compression Threshold
                        if settings.historyCompressionEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Порог сжатия")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                HStack {
                                    Text("5")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Slider(value: Binding(
                                        get: { Double(settings.compressionThreshold) },
                                        set: { settings.compressionThreshold = Int($0) }
                                    ), in: 5...30, step: 5)
                                    Text("30")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(settings.compressionThreshold)")
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundColor(.purple)
                                        .frame(width: 40)
                                }

                                Text("Сжимать историю каждые \(settings.compressionThreshold) сообщений")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)

                            // Recent Messages to Keep
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Сохранять недавние сообщения")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                HStack {
                                    Text("3")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Slider(value: Binding(
                                        get: { Double(settings.recentMessagesToKeep) },
                                        set: { settings.recentMessagesToKeep = Int($0) }
                                    ), in: 3...10, step: 1)
                                    Text("10")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(settings.recentMessagesToKeep)")
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundColor(.purple)
                                        .frame(width: 40)
                                }

                                Text("Количество последних сообщений, которые остаются без сжатия")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)

                            // Info Box
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Как это работает?")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                Text("При достижении порога старые сообщения автоматически сжимаются в краткий summary с помощью Claude. Это позволяет сохранить контекст разговора, значительно уменьшив потребление токенов.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }

                    // Информация секция
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Информация")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Статус")
                                .font(.headline)
                            
                            HStack {
                                Circle()
                                    .fill(settings.isConfigured ? Color.green : Color.red)
                                    .frame(width: 12, height: 12)
                                
                                Text(settings.isConfigured ? "API ключ настроен" : "API ключ не настроен")
                                    .foregroundColor(settings.isConfigured ? .green : .red)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    
                    // Действия секция
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button("Тест соединения") {
                                testConnection()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                            .disabled(!settings.isConfigured)
                            
                            Button("Очистить API ключ") {
                                settings.apiKey = ""
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(settings.isConfigured ? Color.red : Color.gray)
                            .cornerRadius(8)
                            .disabled(!settings.isConfigured)
                        }
                        
                        if !testResult.isEmpty {
                            Text(testResult)
                                .font(.caption)
                                .foregroundColor(testResult.contains("✅") ? .green : .red)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 800, idealWidth: 900, maxWidth: 1200, minHeight: 600, idealHeight: 700, maxHeight: .infinity)
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Готово") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .frame(minWidth: 800, idealWidth: 900, maxWidth: 1200, minHeight: 600, idealHeight: 700, maxHeight: .infinity)
    }
    
    private func testConnection() {
        testResult = "Проверяем соединение..."
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            testResult = "❌ Неверный URL API"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("anthropic-2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 1,
            "messages": [
                [
                    "role": "user",
                    "content": "test"
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            testResult = "❌ Ошибка создания запроса: \(error.localizedDescription)"
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    switch nsError.code {
                    case -1003:
                        testResult = "❌ Сервер не найден. Проверьте интернет-соединение."
                    case -1001:
                        testResult = "❌ Превышено время ожидания."
                    case -1009:
                        testResult = "❌ Нет подключения к интернету."
                    default:
                        testResult = "❌ Ошибка сети: \(error.localizedDescription)"
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        testResult = "❌ Неверный API ключ"
                    } else if httpResponse.statusCode == 200 {
                        testResult = "✅ Соединение успешно установлено!"
                    } else {
                        testResult = "⚠️ Сервер вернул код: \(httpResponse.statusCode)"
                    }
                } else {
                    testResult = "❌ Неожиданный ответ сервера"
                }
            }
        }.resume()
    }

    private func testYandexTrackerConnection() {
        trackerTestResult = ""
        isTestingTracker = true

        Task {
            do {
                // Создаём агента для проверки
                let agent = YandexTrackerAgent(apiKey: settings.apiKey)

                // Пытаемся подключиться
                try await agent.configure(
                    orgId: settings.yandexTrackerOrgId,
                    token: settings.yandexTrackerToken
                )

                // Пробуем получить статистику (простой запрос)
                let result = try await agent.executeTask(task: "Сколько всего задач?")

                await MainActor.run {
                    if result.contains("Всего задач:") || result.contains("статистика") {
                        trackerTestResult = "✅ Подключение успешно! Данные Yandex Tracker верны."
                    } else {
                        trackerTestResult = "⚠️ Подключение установлено, но получен неожиданный ответ"
                    }
                    isTestingTracker = false
                }

            } catch {
                await MainActor.run {
                    // Анализируем ошибку для более понятного сообщения
                    let errorMessage = error.localizedDescription

                    if errorMessage.contains("620345") || errorMessage.contains("Organization not found") {
                        trackerTestResult = "❌ Organization ID неверный или недоступен. Organization ID должен быть ЧИСЛОМ (например: 12345678). Найдите его в Yandex Tracker → Settings → About organization."
                    } else if errorMessage.contains("401") || errorMessage.contains("Unauthorized") {
                        trackerTestResult = "❌ Неверный OAuth Token. Проверьте токен в настройках Yandex OAuth."
                    } else if errorMessage.contains("403") || errorMessage.contains("Forbidden") {
                        trackerTestResult = "❌ Доступ запрещён (403). Проверьте, что OAuth Token имеет права 'tracker:read' и 'tracker:write', и что Organization ID правильный."
                    } else if errorMessage.contains("404") {
                        trackerTestResult = "❌ Organization ID не найден. Проверьте ID организации."
                    } else if errorMessage.contains("Network") || errorMessage.contains("connection") {
                        trackerTestResult = "❌ Ошибка сети. Проверьте подключение к интернету."
                    } else if errorMessage.contains("Not connected") {
                        trackerTestResult = "❌ MCP сервер не запустился. Проверьте, что mcp-yandex-tracker собран (npm run build)."
                    } else if errorMessage.contains("Transport error") {
                        trackerTestResult = "❌ Ошибка запуска MCP сервера. Проверьте Node.js (node --version)."
                    } else {
                        trackerTestResult = "❌ Ошибка: \(errorMessage)"
                    }

                    isTestingTracker = false
                }
            }
        }
    }

    private var temperatureDescription: String {
        switch settings.temperature {
        case 0.0...0.3:
            return "Детерминированный режим: точные, повторяемые ответы. Идеально для фактов, кода, анализа данных."
        case 0.4...0.6:
            return "Сбалансированный режим: небольшая вариативность с сохранением точности."
        case 0.7...0.8:
            return "Креативный режим: баланс между точностью и креативностью. Рекомендуется для общения."
        case 0.9...1.0:
            return "Высокая креативность: разнообразные, неожиданные ответы. Для творческих задач, мозгового штурма."
        case 1.1...1.2:
            return "Экспериментальный режим: максимальная случайность и непредсказуемость. Для исследований и экспериментов."
        default:
            return "Балансирует между точностью и креативностью ответов."
        }
    }
}
