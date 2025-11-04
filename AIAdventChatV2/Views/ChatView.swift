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
    @State private var showingConversationList = false
    @State private var showingUserProfile = false
    @State private var enableRAG = false

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
                // Conversation title and history button
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.conversationMode == .collectingRequirements ? "Сбор требований для ТЗ" : viewModel.conversationTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if viewModel.messages.count > 0 {
                        Text("\(viewModel.messages.count) сообщений")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Conversation history button
                Button(action: {
                    showingConversationList = true
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .help("История разговоров")

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

                // User Profile button
                Button(action: {
                    showingUserProfile = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)

                        // Show indicator if profile is configured
                        if viewModel.userProfileService.profile.isConfigured {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Мой профиль")

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

            // RAG Mode Toggle
            HStack(spacing: 12) {
                Toggle(isOn: $enableRAG) {
                    HStack(spacing: 6) {
                        Image(systemName: enableRAG ? "doc.text.magnifyingglass.fill" : "doc.text.magnifyingglass")
                            .foregroundColor(enableRAG ? .green : .gray)
                        Text(enableRAG ? "RAG включён" : "RAG выключен")
                            .font(.caption)
                            .foregroundColor(enableRAG ? .green : .secondary)
                    }
                }
                .toggleStyle(.switch)
                .help("Включить поиск по документам с историей диалога")

                Spacer()

                if enableRAG {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Ответы с цитатами из кодовой базы")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Поле ввода и кнопка отправки
            HStack(spacing: 12) {
                // Pipeline button
                Button(action: {
                    if !viewModel.currentMessage.isEmpty {
                        viewModel.processTextThroughPipeline(viewModel.currentMessage)
                    }
                }) {
                    Image(systemName: viewModel.isProcessingText ? "hourglass" : "wand.and.stars")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentMessage.isEmpty || viewModel.isProcessingText)
                .help("Process text through pipeline")

                TextField("Введите сообщение...", text: $viewModel.currentMessage, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...10)
                    .onSubmit {
                        if canSendMessage {
                            if enableRAG {
                                viewModel.sendMessageWithRAG(enableRAG: true)
                            } else {
                                viewModel.sendMessage()
                            }
                        }
                    }

                // Voice Input Button
                Button(action: {
                    viewModel.toggleVoiceInput()
                }) {
                    Image(systemName: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title)
                        .foregroundColor(viewModel.isListening ? .red : .blue)
                }
                .buttonStyle(.plain)
                .help(viewModel.isListening ? "Остановить запись и отправить" : "Голосовой ввод")

                Button(action: {
                    if enableRAG {
                        viewModel.sendMessageWithRAG(enableRAG: true)
                    } else {
                        viewModel.sendMessage()
                    }
                }) {
                    HStack(spacing: 4) {
                        if enableRAG {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.caption)
                        }
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                    }
                    .foregroundColor(canSendMessage ? (enableRAG ? .green : .blue) : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!canSendMessage)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // Voice input indicator
            if viewModel.isListening {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundColor(.red)
                        .font(.body)

                    Text("Слушаю... (нажмите снова чтобы отправить)")
                        .font(.caption)
                        .foregroundColor(.red)

                    if !viewModel.speechRecognitionService.recognizedText.isEmpty {
                        Divider()
                            .frame(height: 20)

                        Text("Распознано: \"\(viewModel.speechRecognitionService.recognizedText)\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
            }

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
        .sheet(isPresented: $showingConversationList) {
            ConversationListView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView(service: viewModel.userProfileService)
        }
        .sheet(isPresented: $viewModel.showingPipelineResult) {
            if let result = viewModel.pipelineResult {
                VStack(spacing: 0) {
                    TextPipelineView(result: result)

                    Divider()

                    HStack {
                        Button("Use Compressed Text") {
                            viewModel.useProcessedText()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Close") {
                            viewModel.showingPipelineResult = false
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
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
