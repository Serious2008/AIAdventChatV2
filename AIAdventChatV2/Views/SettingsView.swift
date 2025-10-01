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
}
