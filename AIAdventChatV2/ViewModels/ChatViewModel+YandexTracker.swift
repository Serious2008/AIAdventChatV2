//
//  ChatViewModel+YandexTracker.swift
//  AIAdventChatV2
//
//  Extension for Yandex Tracker integration in chat
//

import Foundation

extension ChatViewModel {

    // MARK: - Yandex Tracker Commands

    /// Проверить, является ли сообщение командой для Yandex Tracker
    func isYandexTrackerCommand(_ message: String) -> Bool {
        let lowercased = message.lowercased()

        let trackerKeywords = [
            "yandex tracker",
            "яндекс трекер",
            "трекер",
            "задач",
            "таск",
            "issue",
            "статистик"
        ]

        return trackerKeywords.contains { lowercased.contains($0) }
    }

    /// Обработать команду Yandex Tracker
    func handleYandexTrackerCommand(_ message: String) async -> String {
        // Проверяем настройки
        guard settings.isYandexTrackerConfigured else {
            return """
            ⚠️ Yandex Tracker не настроен

            Для работы с Yandex Tracker необходимо:
            1. Перейти в настройки (⚙️)
            2. Заполнить Organization ID
            3. Добавить OAuth Token

            После настройки вы сможете спрашивать:
            • "Сколько открытых задач?"
            • "Покажи статистику по задачам"
            • "Какие задачи в работе?"
            """
        }

        do {
            // Создаем агента
            let agent = YandexTrackerAgent(apiKey: settings.apiKey)

            // Конфигурируем
            try await agent.configure(
                orgId: settings.yandexTrackerOrgId,
                token: settings.yandexTrackerToken
            )

            // Выполняем задачу
            let result = try await agent.executeTask(task: message)

            return result

        } catch {
            return """
            ❌ Ошибка при обращении к Yandex Tracker:

            \(error.localizedDescription)

            Проверьте:
            • Правильность Organization ID
            • Валидность OAuth токена
            • Подключение к интернету
            """
        }
    }

    // MARK: - Quick Commands

    /// Быстрые команды для Yandex Tracker
    static let yandexTrackerQuickCommands: [(title: String, command: String)] = [
        ("📊 Статистика", "Сколько открытых задач в Yandex Tracker?"),
        ("✅ Открытые задачи", "Покажи все открытые задачи в Yandex Tracker"),
        ("🚀 В работе", "Какие задачи в работе в Yandex Tracker?"),
        ("👤 Мои задачи", "Покажи мои задачи в Yandex Tracker")
    ]
}
