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
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "ClaudeAPIKey") ?? ""
    }
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
}

