//
//  ChatView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settings: Settings
    @State private var showingSettings = false
    @State private var showingGeneratedDocument = false

    private var canSendMessage: Bool {
        // Проверяем базовые условия
        guard !viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !viewModel.isLoading,
              settings.isConfigured else {
            return false
        }

        // Разрешаем отправку даже при превышении лимита (только предупреждение)
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок с кнопками
            HStack {
                Text(viewModel.conversationMode == .collectingRequirements ? "Сбор требований для ТЗ" : "Claude Chat")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                // Кнопка режима сбора ТЗ
                if viewModel.conversationMode == .normal {
                    Button(action: {
                        viewModel.startRequirementsCollection()
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Создать ТЗ")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        viewModel.switchToNormalMode()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                            Text("Обычный режим")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Кнопка просмотра ТЗ (если есть)
                if viewModel.generatedDocument != nil {
                    Button(action: {
                        showingGeneratedDocument = true
                    }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Список сообщений
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Compression Stats (if enabled and has data)
                        if settings.historyCompressionEnabled &&
                           (viewModel.compressionStats.totalCompressions > 0 ||
                            !viewModel.compressedHistory.summaries.isEmpty) {
                            CompressionStatsView(
                                stats: viewModel.compressionStats,
                                compressedHistory: viewModel.compressedHistory
                            )
                            .padding(.horizontal)
                            .padding(.top)
                        }

                        if viewModel.messages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "message.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Добро пожаловать в Claude Chat!")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Text("Начните разговор, отправив сообщение")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                if !settings.isConfigured {
                                    VStack(spacing: 8) {
                                        Text("⚠️ API ключ не настроен")
                                            .foregroundColor(.orange)
                                            .fontWeight(.medium)
                                        
                                        Button("Настроить API ключ") {
                                            showingSettings = true
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.top, 100)
                        }
                        
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.loadingMessage)
                                        .foregroundColor(.secondary)
                                        .font(.caption)

                                    if let progress = viewModel.summarizationProgress {
                                        Text(progress)
                                            .foregroundColor(.blue)
                                            .font(.caption2)
                                    }
                                }
                            }
                            .padding()
                            .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isLoading) { isLoading in
                    if isLoading {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()

            // Быстрые команды Yandex Tracker
            if settings.isYandexTrackerConfigured && viewModel.conversationMode == .normal {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ChatViewModel.yandexTrackerQuickCommands, id: \.title) { command in
                            Button(action: {
                                viewModel.currentMessage = command.command
                            }) {
                                Text(command.title)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }

            // Индикатор токенов
            if !viewModel.currentMessage.isEmpty {
                TokenIndicatorView(
                    message: viewModel.currentMessage,
                    provider: settings.selectedProvider,
                    model: settings.selectedModel
                )
            }

            // Поле ввода и кнопка отправки
            HStack(spacing: 12) {
                TextField("Введите сообщение...", text: $viewModel.currentMessage, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...10)
                    .onSubmit {
                        if canSendMessage {
                            viewModel.sendMessage()
                        }
                    }

                Button(action: {
                    viewModel.sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!canSendMessage)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Показ ошибок
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                    Spacer()
                    Button("✕") {
                        viewModel.errorMessage = nil
                    }
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showingGeneratedDocument) {
            GeneratedDocumentView(document: viewModel.generatedDocument ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Очистить чат") {
                        viewModel.clearChat()
                    }
                    Button("Настройки") {
                        showingSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}
