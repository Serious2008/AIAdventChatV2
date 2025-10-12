//
//  TokenManager.swift
//  AIAdventChatV2
//
//  Created by Claude on 10.10.2025.
//

import Foundation

enum TokenStatus {
    case ok
    case warning
    case exceeded
}

class TokenManager {

    // Лимиты для разных моделей
    static let modelLimits: [String: Int] = [
        "claude-3-7-sonnet-20250219": 200000,
        "claude-3-5-sonnet-20241022": 200000,
        "katanemo/Arch-Router-1.5B": 8192,
        "microsoft/phi-2": 2048,
        "meta-llama/Llama-3.1-8B-Instruct": 8192,
        "mistralai/Mistral-7B-Instruct-v0.3": 8192,
        "deepseek-ai/DeepSeek-V3-0324": 64000,
        "Qwen/Qwen2.5-72B-Instruct": 32768
    ]

    // Простая оценка токенов (примерно 4 символа = 1 токен)
    static func estimateTokens(_ text: String) -> Int {
        // Более точная оценка с учетом пробелов и пунктуации
        let words = text.split(separator: " ")
        let wordTokens = words.count
        let charTokens = text.count / 4

        // Среднее между подсчетом по словам и символам
        return max(wordTokens, charTokens)
    }

    // Получить лимит для модели
    static func getLimit(for model: String, provider: ModelProvider) -> Int {
        switch provider {
        case .claude:
            return modelLimits["claude-3-7-sonnet-20250219"] ?? 200000
        case .huggingface:
            return modelLimits[model] ?? 8192
        }
    }

    // Проверить статус токенов
    static func checkStatus(tokens: Int, limit: Int) -> TokenStatus {
        let percentage = Double(tokens) / Double(limit)

        if percentage >= 1.0 {
            return .exceeded
        } else if percentage >= 0.8 {
            return .warning
        } else {
            return .ok
        }
    }

    // Получить цвет для статуса
    static func getColor(for status: TokenStatus) -> (r: Double, g: Double, b: Double) {
        switch status {
        case .ok:
            return (0.0, 0.8, 0.0) // Зеленый
        case .warning:
            return (1.0, 0.65, 0.0) // Оранжевый
        case .exceeded:
            return (1.0, 0.0, 0.0) // Красный
        }
    }
}
