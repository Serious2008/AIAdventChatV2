//
//  Settings.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import Foundation

class Settings: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "ClaudeAPIKey")
        }
    }

    @Published var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: "ClaudeTemperature")
        }
    }

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "ClaudeAPIKey") ?? ""
        self.temperature = UserDefaults.standard.object(forKey: "ClaudeTemperature") as? Double ?? 0.7
    }

    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
}

