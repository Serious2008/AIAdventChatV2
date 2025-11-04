//
//  UserProfile.swift
//  AIAdventChatV2
//
//  User profile model for agent personalization
//

import Foundation

// MARK: - User Profile

struct UserProfile: Codable, Equatable {

    // MARK: - Basic Information

    var name: String = ""
    var role: String = ""
    var occupation: String = ""

    // MARK: - Professional Data

    var skills: [String] = []
    var currentProjects: [String] = []

    // MARK: - Preferences and Habits

    var interests: [String] = []
    var communicationStyle: CommunicationStyle = .balanced
    var workingHours: String = ""
    var preferredLanguage: String = "Русский"

    // MARK: - Context for Agent

    var goals: [String] = []
    var constraints: [String] = []
    var commonTasks: [String] = []

    // MARK: - Communication Style

    enum CommunicationStyle: String, Codable, CaseIterable {
        case concise = "Краткий и технический"
        case balanced = "Сбалансированный"
        case detailed = "Подробный с примерами"

        var description: String {
            switch self {
            case .concise:
                return "Краткие технические ответы без лишних деталей"
            case .balanced:
                return "Оптимальный баланс между теорией и практикой"
            case .detailed:
                return "Подробные объяснения с примерами кода и пояснениями"
            }
        }
    }

    // MARK: - Computed Properties

    var isConfigured: Bool {
        !name.isEmpty || !role.isEmpty || !skills.isEmpty || !interests.isEmpty
    }

    // MARK: - System Prompt Generation

    func toSystemPrompt() -> String {
        guard isConfigured else {
            return ""
        }

        var prompt = "# 👤 О пользователе:\n\n"

        // Basic info
        if !name.isEmpty {
            prompt += "- **Имя:** \(name)\n"
        }
        if !role.isEmpty {
            prompt += "- **Роль:** \(role)\n"
        }
        if !occupation.isEmpty {
            prompt += "- **Профессия:** \(occupation)\n"
        }

        // Skills
        if !skills.isEmpty {
            prompt += "- **Навыки:** \(skills.joined(separator: ", "))\n"
        }

        // Current projects
        if !currentProjects.isEmpty {
            prompt += "- **Текущие проекты:** \(currentProjects.joined(separator: ", "))\n"
        }

        // Interests
        if !interests.isEmpty {
            prompt += "- **Интересы:** \(interests.joined(separator: ", "))\n"
        }

        // Working hours
        if !workingHours.isEmpty {
            prompt += "- **Рабочее время:** \(workingHours)\n"
        }

        // Communication style
        prompt += "- **Стиль общения:** \(communicationStyle.rawValue)\n"
        prompt += "  → \(communicationStyle.description)\n"

        // Goals
        if !goals.isEmpty {
            prompt += "\n## 🎯 Текущие цели пользователя:\n\n"
            goals.forEach { prompt += "- \($0)\n" }
        }

        // Constraints
        if !constraints.isEmpty {
            prompt += "\n## ⚠️ Ограничения:\n\n"
            constraints.forEach { prompt += "- \($0)\n" }
        }

        // Common tasks
        if !commonTasks.isEmpty {
            prompt += "\n## 🔧 Частые задачи:\n\n"
            commonTasks.forEach { prompt += "- \($0)\n" }
        }

        // Instructions for agent
        prompt += "\n---\n\n"
        prompt += "**Инструкции для ассистента:**\n"
        prompt += "- Используй эту информацию для персонализации ответов\n"

        if !name.isEmpty {
            prompt += "- Обращайся к пользователю по имени (\(name))\n"
        }

        if !skills.isEmpty {
            prompt += "- Учитывай навыки пользователя при объяснениях\n"
        }

        prompt += "- Адаптируй сложность и стиль ответа к профилю пользователя\n"

        if !goals.isEmpty {
            prompt += "- Помогай достигать указанных целей\n"
        }

        if !constraints.isEmpty {
            prompt += "- Соблюдай указанные ограничения\n"
        }

        return prompt
    }

    // MARK: - Default Profiles

    static let empty = UserProfile()

    static let example = UserProfile(
        name: "Сергей",
        role: "iOS разработчик",
        occupation: "Senior iOS Developer",
        skills: ["Swift", "SwiftUI", "Python", "Machine Learning"],
        currentProjects: ["AIAdventChatV2"],
        interests: ["AI", "Machine Learning", "iOS разработка", "RAG"],
        communicationStyle: .balanced,
        workingHours: "10:00-19:00 MSK",
        preferredLanguage: "Русский",
        goals: [
            "Изучить RAG и векторный поиск",
            "Создать персонального AI ассистента",
            "Интегрировать голосовой ввод"
        ],
        constraints: [
            "Использовать только нативные macOS/iOS API",
            "Минимизировать зависимости от внешних библиотек"
        ],
        commonTasks: [
            "Код-ревью",
            "Debugging",
            "Архитектурные решения",
            "Оптимизация производительности"
        ]
    )
}
