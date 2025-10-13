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

enum SummarizationProvider: String, Codable, CaseIterable {
    case local = "Локально (Бесплатно, приватно)"
    case huggingface = "HuggingFace API (Бесплатно)"
    case claude = "Claude API (Платно, выше качество)"
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

    @Published var summarizationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(summarizationEnabled, forKey: "SummarizationEnabled")
        }
    }

    @Published var summarizationMinLength: Int {
        didSet {
            UserDefaults.standard.set(summarizationMinLength, forKey: "SummarizationMinLength")
        }
    }

    @Published var summarizationProvider: SummarizationProvider {
        didSet {
            UserDefaults.standard.set(summarizationProvider.rawValue, forKey: "SummarizationProvider")
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

        self.summarizationEnabled = UserDefaults.standard.object(forKey: "SummarizationEnabled") as? Bool ?? false
        self.summarizationMinLength = UserDefaults.standard.object(forKey: "SummarizationMinLength") as? Int ?? 2000

        if let providerString = UserDefaults.standard.string(forKey: "SummarizationProvider"),
           let provider = SummarizationProvider(rawValue: providerString) {
            self.summarizationProvider = provider
        } else {
            self.summarizationProvider = .huggingface
        }
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

