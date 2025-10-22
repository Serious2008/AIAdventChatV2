//
//  ConversationListView.swift
//  AIAdventChatV2
//
//  UI for managing saved conversations
//

import SwiftUI

struct ConversationListView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var conversations: [(id: String, title: String, updatedAt: Date, messageCount: Int)] = []
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportedURL: URL?
    @State private var showingDeleteConfirmation = false
    @State private var conversationToDelete: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text("Сохраненные разговоры")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.createNewConversation()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Новый")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button(action: exportCurrent) {
                            Label("Экспорт текущего", systemImage: "square.and.arrow.up")
                        }

                        Button(action: createBackup) {
                            Label("Полный бэкап", systemImage: "archivebox")
                        }

                        Divider()

                        Button(action: { showingImportSheet = true }) {
                            Label("Импорт", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Conversations list
            if conversations.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("Нет сохраненных разговоров")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("Начните новый разговор или импортируйте существующий")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversations, id: \.id) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isActive: conversation.id == viewModel.currentConversationId,
                                onSelect: {
                                    DispatchQueue.main.async {
                                        viewModel.loadConversation(id: conversation.id)
                                        dismiss()
                                    }
                                },
                                onDelete: {
                                    conversationToDelete = conversation.id
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 700, idealWidth: 800, maxWidth: 1000, minHeight: 500, idealHeight: 600, maxHeight: 800)
        .onAppear {
            print("📋 ConversationListView appeared")
            loadConversations()
            print("📊 Loaded \(conversations.count) conversations")
        }
        .alert("Удалить разговор?", isPresented: $showingDeleteConfirmation) {
            Button("Отмена", role: .cancel) {
                conversationToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                if let id = conversationToDelete {
                    deleteConversation(id: id)
                }
            }
        } message: {
            Text("Это действие нельзя отменить")
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportedURL {
                ExportResultView(fileURL: url)
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
    }

    private func loadConversations() {
        print("🔄 ConversationListView: Loading conversations...")
        conversations = viewModel.getAllSavedConversations()
        print("✅ ConversationListView: Loaded \(conversations.count) conversations")
        for conv in conversations {
            print("  - \(conv.title): \(conv.messageCount) messages")
        }
    }

    private func deleteConversation(id: String) {
        _ = viewModel.deleteConversation(id: id)
        loadConversations()
        conversationToDelete = nil
    }

    private func exportCurrent() {
        if let url = viewModel.exportCurrentConversation() {
            exportedURL = url
            showingExportSheet = true
        }
    }

    private func createBackup() {
        if let url = viewModel.createFullBackup() {
            exportedURL = url
            showingExportSheet = true
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if viewModel.importConversation(from: url) {
                loadConversations()
            }
        case .failure(let error):
            print("Import error: \(error)")
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: (id: String, title: String, updatedAt: Date, messageCount: Int)
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(isActive ? .blue : .primary)

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }

                HStack {
                    Image(systemName: "message")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(conversation.messageCount) сообщений")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption)

                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onSelect) {
                    Text(isActive ? "Текущий" : "Открыть")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isActive ? Color.blue.opacity(0.1) : Color.blue)
                        .foregroundColor(isActive ? .blue : .white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isActive)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(isActive ? Color.blue.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Export Result View

struct ExportResultView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Экспорт успешен!")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Файл:")
                        .foregroundColor(.secondary)
                    Text(fileURL.lastPathComponent)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Путь:")
                        .foregroundColor(.secondary)
                    Text(fileURL.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            HStack(spacing: 12) {
                Button("Открыть папку") {
                    NSWorkspace.shared.open(fileURL.deletingLastPathComponent())
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("Готово") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}

// MARK: - Preview

#Preview {
    ConversationListView(viewModel: ChatViewModel(settings: Settings()))
}
