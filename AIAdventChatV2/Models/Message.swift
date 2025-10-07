//
//  Message.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import Foundation

struct MessageContent: Codable {
    let response: String
    let confidence: String?
    let additional_info: String?
}

struct Message: Identifiable, Codable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    var parsedContent: MessageContent?
    var temperature: Double?
    var responseTime: TimeInterval?
    var inputTokens: Int?
    var outputTokens: Int?
    var cost: Double?
    var modelName: String?

    init(content: String, isFromUser: Bool, temperature: Double? = nil, metrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?, modelName: String?)? = nil) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.temperature = temperature

        if let metrics = metrics {
            self.responseTime = metrics.responseTime
            self.inputTokens = metrics.inputTokens
            self.outputTokens = metrics.outputTokens
            self.cost = metrics.cost
            self.modelName = metrics.modelName
        }

        // Пытаемся распарсить JSON если это не сообщение пользователя
        if !isFromUser {
            self.parsedContent = Self.parseJSON(from: content)
        }
    }

    private static func parseJSON(from text: String) -> MessageContent? {
        // Пробуем найти JSON в тексте
        guard let jsonData = text.data(using: .utf8) else { return nil }

        do {
            let content = try JSONDecoder().decode(MessageContent.self, from: jsonData)
            return content
        } catch {
            // Если не получилось распарсить весь текст, пробуем найти JSON блок
            if let jsonStart = text.firstIndex(of: "{"),
               let jsonEnd = text.lastIndex(of: "}") {
                let jsonString = String(text[jsonStart...jsonEnd])
                if let jsonData = jsonString.data(using: .utf8),
                   let content = try? JSONDecoder().decode(MessageContent.self, from: jsonData) {
                    return content
                }
            }
            return nil
        }
    }

    var displayText: String {
        if let parsed = parsedContent {
            return parsed.response
        }
        return content
    }
}
