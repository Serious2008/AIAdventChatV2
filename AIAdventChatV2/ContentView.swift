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

            NavigationStack {
                YandexTrackerTestView()
            }
            .tabItem {
                Label("Tracker", systemImage: "checklist")
            }
            .tag(3)

            NavigationStack {
                VectorSearchView(viewModel: chatViewModel, selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Search", systemImage: "doc.text.magnifyingglass")
            }
            .tag(4)

            NavigationStack {
                RAGComparisonView(viewModel: chatViewModel)
            }
            .tabItem {
                Label("RAG Compare", systemImage: "arrow.left.arrow.right.circle.fill")
            }
            .tag(5)

            NavigationStack {
                RerankingComparisonView(viewModel: chatViewModel)
            }
            .tabItem {
                Label("Reranking", systemImage: "slider.horizontal.3")
            }
            .tag(6)

            NavigationStack {
                CitationTestView(viewModel: chatViewModel)
            }
            .tabItem {
                Label("Citations", systemImage: "quote.bubble.fill")
            }
            .tag(7)
        }
    }
}

#Preview {
    ContentView()
}
