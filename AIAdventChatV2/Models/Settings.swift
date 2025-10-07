//
//  Settings.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import Foundation

enum ModelProvider: String, Codable, CaseIterable {
    case claude = "Claude"
    case huggingface = "HuggingFace"
}

class Settings: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "ClaudeAPIKey")
        }
    }

    @Published var huggingFaceApiKey: String {
        didSet {
            UserDefaults.standard.set(huggingFaceApiKey, forKey: "HuggingFaceAPIKey")
        }
    }

    @Published var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: "ClaudeTemperature")
        }
    }

    @Published var selectedProvider: ModelProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "SelectedProvider")
        }
    }

    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "SelectedModel")
        }
    }

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "ClaudeAPIKey") ?? ""
        self.huggingFaceApiKey = UserDefaults.standard.string(forKey: "HuggingFaceAPIKey") ?? ""
        self.temperature = UserDefaults.standard.object(forKey: "ClaudeTemperature") as? Double ?? 0.7

        if let providerString = UserDefaults.standard.string(forKey: "SelectedProvider"),
           let provider = ModelProvider(rawValue: providerString) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .claude
        }

        let defaultModel = UserDefaults.standard.string(forKey: "SelectedModel") ?? "katanemo/Arch-Router-1.5B"
        self.selectedModel = defaultModel
    }

    var isConfigured: Bool {
        switch selectedProvider {
        case .claude:
            return !apiKey.isEmpty
        case .huggingface:
            return !huggingFaceApiKey.isEmpty
        }
    }
}

