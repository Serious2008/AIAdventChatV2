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
                                                if settings.summarizationProvider == .huggingface {
                                                    Text("Бесплатная суммаризация через katanemo/Arch-Router-1.5B")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                } else {
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
            .frame(minWidth: 500, minHeight: 400)
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
        .frame(minWidth: 500, minHeight: 400)
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
