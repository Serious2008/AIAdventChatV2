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
    
    init() {
        let settings = Settings()
        _settings = StateObject(wrappedValue: settings)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(settings: settings))
    }
    
    var body: some View {
        NavigationStack {
            ChatView(viewModel: chatViewModel, settings: settings)
        }
    }
}

#Preview {
    ContentView()
}
