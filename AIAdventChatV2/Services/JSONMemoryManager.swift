//
//  JSONMemoryManager.swift
//  AIAdventChatV2
//
//  JSON-based export/import for conversations and backups
//

import Foundation
import AppKit

// MARK: - Exportable Models

struct ExportableConversation: Codable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [Message]
    let summaries: [ConversationSummary]
    let compressionStats: CompressionStats?

    var metadata: ConversationMetadata {
        ConversationMetadata(
            messageCount: messages.count,
            summaryCount: summaries.count,
            totalTokensUsed: messages.compactMap { $0.inputTokens }.reduce(0, +) +
                           messages.compactMap { $0.outputTokens }.reduce(0, +),
            totalCost: messages.compactMap { $0.cost }.reduce(0, +)
        )
    }
}

struct ConversationMetadata: Codable {
    let messageCount: Int
    let summaryCount: Int
    let totalTokensUsed: Int
    let totalCost: Double
}

struct ConversationBackup: Codable {
    let version: String
    let exportDate: Date
    let conversations: [ExportableConversation]

    static let currentVersion = "1.0"
}

class JSONMemoryManager {
    static let shared = JSONMemoryManager()

    private let fileManager = FileManager.default
    private let exportDirectory: URL

    private init() {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        exportDirectory = appSupportURL.appendingPathComponent("AIAdventChatV2/Exports", isDirectory: true)

        // Create export directory
        if !fileManager.fileExists(atPath: exportDirectory.path) {
            try? fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        }

        print("📁 Export directory: \(exportDirectory.path)")
    }

    // MARK: - Export Single Conversation

    func exportConversation(
        id: String,
        title: String,
        messages: [Message],
        summaries: [ConversationSummary],
        compressionStats: CompressionStats?,
        createdAt: Date,
        updatedAt: Date
    ) -> URL? {
        let conversation = ExportableConversation(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messages: messages,
            summaries: summaries,
            compressionStats: compressionStats
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(conversation) else {
            print("❌ Failed to encode conversation")
            return nil
        }

        // Generate filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let sanitizedTitle = title.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        let filename = "conversation_\(sanitizedTitle)_\(dateString).json"

        let fileURL = exportDirectory.appendingPathComponent(filename)

        do {
            try jsonData.write(to: fileURL)
            print("✅ Conversation exported to: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to write JSON file: \(error)")
            return nil
        }
    }

    // MARK: - Import Single Conversation

    func importConversation(from fileURL: URL) -> ExportableConversation? {
        guard let jsonData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read JSON file")
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let conversation = try? decoder.decode(ExportableConversation.self, from: jsonData) else {
            print("❌ Failed to decode conversation")
            return nil
        }

        print("✅ Conversation imported: \(conversation.title)")
        return conversation
    }

    // MARK: - Full Backup/Restore

    func createFullBackup() -> URL? {
        let db = DatabaseManager.shared
        let conversations = db.getAllConversations()

        var exportableConversations: [ExportableConversation] = []

        for (id, title, updatedAt, _) in conversations {
            let messages = db.loadMessages(conversationId: id)
            let summaries = db.loadSummaries(conversationId: id)
            let stats = db.loadCompressionStats(conversationId: id)

            // Estimate created date from first message
            let createdAt = messages.first?.timestamp ?? updatedAt

            let exportable = ExportableConversation(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                messages: messages,
                summaries: summaries,
                compressionStats: stats
            )

            exportableConversations.append(exportable)
        }

        let backup = ConversationBackup(
            version: ConversationBackup.currentVersion,
            exportDate: Date(),
            conversations: exportableConversations
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(backup) else {
            print("❌ Failed to encode backup")
            return nil
        }

        // Generate filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "backup_\(dateString).json"

        let fileURL = exportDirectory.appendingPathComponent(filename)

        do {
            try jsonData.write(to: fileURL)
            print("✅ Full backup created: \(fileURL.path)")
            print("📊 Backed up \(exportableConversations.count) conversations")
            return fileURL
        } catch {
            print("❌ Failed to write backup file: \(error)")
            return nil
        }
    }

    func restoreFromBackup(fileURL: URL, mergeWithExisting: Bool = false) -> Bool {
        guard let jsonData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read backup file")
            return false
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(ConversationBackup.self, from: jsonData) else {
            print("❌ Failed to decode backup")
            return false
        }

        print("📦 Restoring backup from \(backup.exportDate)")
        print("📊 Version: \(backup.version)")
        print("📊 Conversations: \(backup.conversations.count)")

        let db = DatabaseManager.shared
        var successCount = 0

        for conversation in backup.conversations {
            // Check if conversation exists
            if !mergeWithExisting {
                _ = db.deleteConversation(id: conversation.id)
            }

            // Create conversation
            if db.createConversation(id: conversation.id, title: conversation.title) {
                // Save all messages
                for message in conversation.messages {
                    _ = db.saveMessage(message, conversationId: conversation.id)
                }

                // Save all summaries
                for summary in conversation.summaries {
                    _ = db.saveSummary(summary, conversationId: conversation.id)
                }

                // Save compression stats
                if let stats = conversation.compressionStats {
                    _ = db.saveCompressionStats(stats, conversationId: conversation.id)
                }

                successCount += 1
                print("✅ Restored: \(conversation.title)")
            }
        }

        print("✅ Restore complete: \(successCount)/\(backup.conversations.count) conversations")
        return successCount > 0
    }

    // MARK: - Quick Save/Load (Single File)

    func quickSave(
        messages: [Message],
        summaries: [ConversationSummary],
        stats: CompressionStats
    ) -> Bool {
        let quickSaveURL = exportDirectory.appendingPathComponent("quicksave.json")

        let conversation = ExportableConversation(
            id: "quicksave",
            title: "Quick Save",
            createdAt: Date(),
            updatedAt: Date(),
            messages: messages,
            summaries: summaries,
            compressionStats: stats
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(conversation) else {
            return false
        }

        do {
            try jsonData.write(to: quickSaveURL)
            print("✅ Quick save successful")
            return true
        } catch {
            print("❌ Quick save failed: \(error)")
            return false
        }
    }

    func quickLoad() -> (messages: [Message], summaries: [ConversationSummary], stats: CompressionStats)? {
        let quickSaveURL = exportDirectory.appendingPathComponent("quicksave.json")

        guard fileManager.fileExists(atPath: quickSaveURL.path),
              let jsonData = try? Data(contentsOf: quickSaveURL) else {
            print("ℹ️ No quick save found")
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let conversation = try? decoder.decode(ExportableConversation.self, from: jsonData) else {
            print("❌ Failed to decode quick save")
            return nil
        }

        print("✅ Quick load successful: \(conversation.messages.count) messages")
        return (
            messages: conversation.messages,
            summaries: conversation.summaries,
            stats: conversation.compressionStats ?? CompressionStats()
        )
    }

    // MARK: - Utility

    func getAllExportedFiles() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: exportDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files.filter { $0.pathExtension == "json" }
            .sorted { (url1, url2) -> Bool in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
    }

    func deleteExport(at url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            print("✅ Deleted export: \(url.lastPathComponent)")
            return true
        } catch {
            print("❌ Failed to delete export: \(error)")
            return false
        }
    }

    func openExportDirectory() {
        NSWorkspace.shared.open(exportDirectory)
    }
}
