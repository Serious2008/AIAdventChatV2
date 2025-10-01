//
//  ChatViewModel.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let settings: Settings
    private var cancellables = Set<AnyCancellable>()
    
    init(settings: Settings) {
        self.settings = settings
    }
    
    func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard settings.isConfigured else {
            errorMessage = "API ключ не настроен. Пожалуйста, добавьте его в настройках."
            return
        }
        
        let userMessage = Message(content: currentMessage, isFromUser: true)
        messages.append(userMessage)
        
        let messageToSend = currentMessage
        currentMessage = ""
        isLoading = true
        errorMessage = nil
        
        sendToClaude(message: messageToSend)
    }
    
    private func sendToClaude(message: String) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            handleError("Неверный URL API")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(settings.apiKey)", forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 30.0 // Увеличиваем таймаут
        
        let requestBody: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": message
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            handleError("Ошибка при создании запроса: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    let nsError = error as NSError
                    var errorMessage = "Ошибка сети: \(error.localizedDescription)"
                    
                    switch nsError.code {
                    case -1003:
                        errorMessage = "Сервер не найден. Проверьте подключение к интернету и попробуйте снова."
                    case -1001:
                        errorMessage = "Превышено время ожидания. Попробуйте снова."
                    case -1009:
                        errorMessage = "Нет подключения к интернету."
                    case 401:
                        errorMessage = "Неверный API ключ. Проверьте настройки."
                    default:
                        errorMessage = "Ошибка сети: \(error.localizedDescription)"
                    }
                    
                    self?.handleError(errorMessage)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                    print("✅ Response headers: \(httpResponse.allHeaderFields)")
                    
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("📄 Response body: \(errorString)")
                    }
                    
                    if httpResponse.statusCode == 401 {
                        self?.handleError("Неверный API ключ. Проверьте настройки.")
                        return
                    } else if httpResponse.statusCode >= 400 {
                        self?.handleError("Ошибка сервера: \(httpResponse.statusCode)")
                        return
                    }
                }
                
                guard let data = data else {
                    self?.handleError("Нет данных в ответе")
                    return
                }
                
                self?.processClaudeResponse(data: data)
            }
        }.resume()
    }
    
    private func processClaudeResponse(data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    
                    let claudeMessage = Message(content: text, isFromUser: false)
                    messages.append(claudeMessage)
                } else if let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    handleError("Ошибка API: \(message)")
                } else {
                    handleError("Неожиданный формат ответа")
                }
            }
        } catch {
            handleError("Ошибка при обработке ответа: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
    
    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}

