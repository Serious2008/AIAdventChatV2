//
//  ContentView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var settings = Settings()
    @StateObject private var chatViewModel: ChatViewModel
    @State private var selectedTab = 0

    init() {
        let settings = Settings()
        _settings = StateObject(wrappedValue: settings)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(settings: settings))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ChatView(viewModel: chatViewModel, settings: settings)
            }
            .tabItem {
                Label("Чат", systemImage: "message.fill")
            }
            .tag(0)

            NavigationStack {
                MultiAgentView(settings: settings)
            }
            .tabItem {
                Label("Multi-Agent", systemImage: "person.2.fill")
            }
            .tag(1)

            NavigationStack {
                MCPView()
            }
            .tabItem {
                Label("MCP", systemImage: "network")
            }
            .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
