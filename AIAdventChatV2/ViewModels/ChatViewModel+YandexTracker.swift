//
//  ChatViewModel+YandexTracker.swift
//  AIAdventChatV2
//
//  Extension for Yandex Tracker integration in chat
//

import Foundation

extension ChatViewModel {

    // MARK: - Quick Commands

    /// Быстрые команды для Yandex Tracker
    static let yandexTrackerQuickCommands: [(title: String, command: String)] = [
        ("📊 Статистика", "Сколько открытых задач в Yandex Tracker?"),
        ("✅ Открытые задачи", "Покажи все открытые задачи в Yandex Tracker"),
        ("🚀 В работе", "Какие задачи в работе в Yandex Tracker?"),
        ("👤 Мои задачи", "Покажи мои задачи в Yandex Tracker")
    ]
}
