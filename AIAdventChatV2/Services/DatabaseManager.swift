//
//  DatabaseManager.swift
//  AIAdventChatV2
//
//  SQLite database manager for long-term memory persistence
//

import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.aiadventchat.database", qos: .userInitiated)

    private init() {
        // Create database in Application Support directory
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("AIAdventChatV2", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }

        dbPath = appDirectory.appendingPathComponent("conversations.db").path

        print("📁 Database path: \(dbPath)")

        openDatabase()
        createTables()
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Connection

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ Error opening database")
            return
        }
        print("✅ Database opened successfully")
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
            print("🔒 Database closed")
        }
    }

    // MARK: - Table Creation

    private func createTables() {
        createConversationsTable()
        createMessagesTable()
        createSummariesTable()
        createCompressionStatsTable()
    }

    private func createConversationsTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS conversations (
            id TEXT PRIMARY KEY,
            title TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            message_count INTEGER DEFAULT 0,
            is_archived INTEGER DEFAULT 0
        );
        """

        executeSQL(createTableSQL, errorMessage: "Error creating conversations table")
    }

    private func createMessagesTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            content TEXT NOT NULL,
            is_from_user INTEGER NOT NULL,
            timestamp REAL NOT NULL,
            temperature REAL,
            response_time REAL,
            input_tokens INTEGER,
            output_tokens INTEGER,
            cost REAL,
            model_name TEXT,
            is_system_message INTEGER DEFAULT 0,
            parsed_content_json TEXT,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_messages_conversation
        ON messages(conversation_id, timestamp);
        """

        executeSQL(createTableSQL, errorMessage: "Error creating messages table")
    }

    private func createSummariesTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS summaries (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            summary TEXT NOT NULL,
            original_messages_count INTEGER NOT NULL,
            original_tokens_estimate INTEGER NOT NULL,
            summary_tokens_estimate INTEGER NOT NULL,
            start_date REAL NOT NULL,
            end_date REAL NOT NULL,
            compression_ratio REAL NOT NULL,
            created_at REAL NOT NULL,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_summaries_conversation
        ON summaries(conversation_id, created_at);
        """

        executeSQL(createTableSQL, errorMessage: "Error creating summaries table")
    }

    private func createCompressionStatsTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS compression_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id TEXT NOT NULL,
            total_compressions INTEGER DEFAULT 0,
            total_tokens_saved INTEGER DEFAULT 0,
            total_original_tokens INTEGER DEFAULT 0,
            total_compressed_tokens INTEGER DEFAULT 0,
            average_compression_ratio REAL DEFAULT 0.0,
            last_compression_date REAL,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        );

        CREATE UNIQUE INDEX IF NOT EXISTS idx_stats_conversation
        ON compression_stats(conversation_id);
        """

        executeSQL(createTableSQL, errorMessage: "Error creating compression_stats table")
    }

    private func executeSQL(_ sql: String, errorMessage: String) {
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Table created/verified")
            } else {
                print("❌ \(errorMessage)")
            }
        } else {
            print("❌ SQL preparation failed: \(errorMessage)")
        }

        sqlite3_finalize(statement)
    }

    // MARK: - Conversation Management

    func createConversation(id: String, title: String? = nil) -> Bool {
        return dbQueue.sync {
            let insertSQL = """
            INSERT INTO conversations (id, title, created_at, updated_at, message_count)
            VALUES (?, ?, ?, ?, 0);
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                print("❌ Error preparing insert conversation statement")
                return false
            }

            defer { sqlite3_finalize(statement) }

            let now = Date().timeIntervalSince1970
            let conversationTitle = title ?? "Разговор от \(Date().formatted())"

            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (conversationTitle as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, now)
            sqlite3_bind_double(statement, 4, now)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Conversation created: \(id)")
                return true
            } else {
                print("❌ Error inserting conversation")
                return false
            }
        }
    }

    func updateConversationTimestamp(id: String) {
        dbQueue.async {
            let updateSQL = "UPDATE conversations SET updated_at = ? WHERE id = ?;"
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(self.db, updateSQL, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(statement, 2, (id as NSString).utf8String, -1, nil)

            sqlite3_step(statement)
        }
    }

    func updateConversationTitle(id: String, title: String) -> Bool {
        return dbQueue.sync {
            let updateSQL = "UPDATE conversations SET title = ? WHERE id = ?;"
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
                print("❌ Error preparing update title statement")
                return false
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, (title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (id as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Conversation title updated: \(title)")
                return true
            } else {
                print("❌ Error updating conversation title")
                return false
            }
        }
    }

    func getAllConversations() -> [(id: String, title: String, updatedAt: Date, messageCount: Int)] {
        return dbQueue.sync {
            let querySQL = "SELECT id, title, updated_at, message_count FROM conversations ORDER BY updated_at DESC;"
            var statement: OpaquePointer?
            var conversations: [(String, String, Date, Int)] = []

            guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
                print("❌ Error preparing query")
                return []
            }

            defer { sqlite3_finalize(statement) }

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
                let messageCount = Int(sqlite3_column_int(statement, 3))

                conversations.append((id, title, updatedAt, messageCount))
                print("📦 Found conversation: \(title) with \(messageCount) messages")
            }

            print("📊 Total conversations found: \(conversations.count)")
            return conversations
        }
    }

    func deleteConversation(id: String) -> Bool {
        return dbQueue.sync {
            let deleteSQL = "DELETE FROM conversations WHERE id = ?;"
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
                return false
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)

            return sqlite3_step(statement) == SQLITE_DONE
        }
    }

    // MARK: - Message Persistence

    func saveMessage(_ message: Message, conversationId: String) -> Bool {
        return dbQueue.sync {
            let insertSQL = """
            INSERT INTO messages (
                id, conversation_id, content, is_from_user, timestamp,
                temperature, response_time, input_tokens, output_tokens, cost,
                model_name, is_system_message, parsed_content_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing insert message statement")
            return false
        }

        defer { sqlite3_finalize(statement) }

        // Bind values
        sqlite3_bind_text(statement, 1, (message.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (conversationId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (message.content as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 4, message.isFromUser ? 1 : 0)
        sqlite3_bind_double(statement, 5, message.timestamp.timeIntervalSince1970)

        // Optional fields
        if let temp = message.temperature {
            sqlite3_bind_double(statement, 6, temp)
        } else {
            sqlite3_bind_null(statement, 6)
        }

        if let responseTime = message.responseTime {
            sqlite3_bind_double(statement, 7, responseTime)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let inputTokens = message.inputTokens {
            sqlite3_bind_int(statement, 8, Int32(inputTokens))
        } else {
            sqlite3_bind_null(statement, 8)
        }

        if let outputTokens = message.outputTokens {
            sqlite3_bind_int(statement, 9, Int32(outputTokens))
        } else {
            sqlite3_bind_null(statement, 9)
        }

        if let cost = message.cost {
            sqlite3_bind_double(statement, 10, cost)
        } else {
            sqlite3_bind_null(statement, 10)
        }

        if let modelName = message.modelName {
            sqlite3_bind_text(statement, 11, (modelName as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 11)
        }

        sqlite3_bind_int(statement, 12, message.isSystemMessage ? 1 : 0)

        // Parsed content as JSON
        if let parsedContent = message.parsedContent,
           let jsonData = try? JSONEncoder().encode(parsedContent),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sqlite3_bind_text(statement, 13, (jsonString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 13)
        }

            let success = sqlite3_step(statement) == SQLITE_DONE

            if success {
                // Update conversation message count
                updateMessageCount(conversationId: conversationId)
                updateConversationTimestamp(id: conversationId)
            }

            return success
        }
    }

    private func updateMessageCount(conversationId: String) {
        let updateSQL = """
        UPDATE conversations
        SET message_count = (SELECT COUNT(*) FROM messages WHERE conversation_id = ?)
        WHERE id = ?;
        """
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (conversationId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (conversationId as NSString).utf8String, -1, nil)

        sqlite3_step(statement)
    }

    func loadMessages(conversationId: String) -> [Message] {
        return dbQueue.sync {
            let querySQL = """
            SELECT id, content, is_from_user, timestamp, temperature, response_time,
                   input_tokens, output_tokens, cost, model_name, is_system_message, parsed_content_json
            FROM messages
            WHERE conversation_id = ?
            ORDER BY timestamp ASC;
            """

            var statement: OpaquePointer?
            var messages: [Message] = []

            guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
                print("❌ Error preparing query messages")
                return []
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, (conversationId as NSString).utf8String, -1, nil)

            while sqlite3_step(statement) == SQLITE_ROW {
            // Extract data
            guard let idCString = sqlite3_column_text(statement, 0),
                  let contentCString = sqlite3_column_text(statement, 1) else {
                continue
            }

            let id = UUID(uuidString: String(cString: idCString)) ?? UUID()
            let content = String(cString: contentCString)
            let isFromUser = sqlite3_column_int(statement, 2) == 1
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))

            let temperature = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? sqlite3_column_double(statement, 4) : nil
            let responseTime = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? sqlite3_column_double(statement, 5) : nil
            let inputTokens = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? Int(sqlite3_column_int(statement, 6)) : nil
            let outputTokens = sqlite3_column_type(statement, 7) != SQLITE_NULL
                ? Int(sqlite3_column_int(statement, 7)) : nil
            let cost = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? sqlite3_column_double(statement, 8) : nil

            var modelName: String? = nil
            if sqlite3_column_type(statement, 9) != SQLITE_NULL,
               let modelCString = sqlite3_column_text(statement, 9) {
                modelName = String(cString: modelCString)
            }

            let isSystemMessage = sqlite3_column_int(statement, 10) == 1

            // Parsed content
            var parsedContent: MessageContent? = nil
            if sqlite3_column_type(statement, 11) != SQLITE_NULL,
               let jsonCString = sqlite3_column_text(statement, 11) {
                let jsonString = String(cString: jsonCString)
                if let jsonData = jsonString.data(using: .utf8) {
                    parsedContent = try? JSONDecoder().decode(MessageContent.self, from: jsonData)
                }
            }

            let message = Message(
                id: id,
                content: content,
                isFromUser: isFromUser,
                timestamp: timestamp,
                parsedContent: parsedContent,
                temperature: temperature,
                responseTime: responseTime,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cost: cost,
                modelName: modelName,
                isSystemMessage: isSystemMessage
            )

                messages.append(message)
            }

            print("📥 Loaded \(messages.count) messages for conversation \(conversationId)")
            return messages
        }
    }

    // MARK: - Summary Persistence

    func saveSummary(_ summary: ConversationSummary, conversationId: String) -> Bool {
        return dbQueue.sync {
            let insertSQL = """
            INSERT INTO summaries (
                id, conversation_id, summary, original_messages_count,
                original_tokens_estimate, summary_tokens_estimate,
                start_date, end_date, compression_ratio, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                return false
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, (summary.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (conversationId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (summary.summary as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 4, Int32(summary.originalMessagesCount))
            sqlite3_bind_int(statement, 5, Int32(summary.originalTokensEstimate))
            sqlite3_bind_int(statement, 6, Int32(summary.summaryTokensEstimate))
            sqlite3_bind_double(statement, 7, summary.timeRange.start.timeIntervalSince1970)
            sqlite3_bind_double(statement, 8, summary.timeRange.end.timeIntervalSince1970)
            sqlite3_bind_double(statement, 9, summary.compressionRatio)
            sqlite3_bind_double(statement, 10, summary.timestamp.timeIntervalSince1970)

            return sqlite3_step(statement) == SQLITE_DONE
        }
    }

    func loadSummaries(conversationId: String) -> [ConversationSummary] {
        return dbQueue.sync {
            let querySQL = """
            SELECT id, summary, original_messages_count, original_tokens_estimate,
                   summary_tokens_estimate, start_date, end_date, created_at
            FROM summaries
            WHERE conversation_id = ?
            ORDER BY created_at ASC;
            """

            var statement: OpaquePointer?
            var summaries: [ConversationSummary] = []

            guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
                return []
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, (conversationId as NSString).utf8String, -1, nil)

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let summaryCString = sqlite3_column_text(statement, 1) else { continue }

                let summaryText = String(cString: summaryCString)
                let originalMessagesCount = Int(sqlite3_column_int(statement, 2))
                let originalTokens = Int(sqlite3_column_int(statement, 3))
                let summaryTokens = Int(sqlite3_column_int(statement, 4))
                let startDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
                let endDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))

                let summary = ConversationSummary(
                    summary: summaryText,
                    originalMessagesCount: originalMessagesCount,
                    originalTokensEstimate: originalTokens,
                    summaryTokensEstimate: summaryTokens,
                    startDate: startDate,
                    endDate: endDate
                )

                summaries.append(summary)
            }

            print("📥 Loaded \(summaries.count) summaries for conversation \(conversationId)")
            return summaries
        }
    }

    // MARK: - Compression Stats Persistence

    func saveCompressionStats(_ stats: CompressionStats, conversationId: String) -> Bool {
        return dbQueue.sync {
            let upsertSQL = """
            INSERT INTO compression_stats (
                conversation_id, total_compressions, total_tokens_saved,
                total_original_tokens, total_compressed_tokens,
                average_compression_ratio, last_compression_date
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(conversation_id) DO UPDATE SET
                total_compressions = excluded.total_compressions,
                total_tokens_saved = excluded.total_tokens_saved,
                total_original_tokens = excluded.total_original_tokens,
                total_compressed_tokens = excluded.total_compressed_tokens,
                average_compression_ratio = excluded.average_compression_ratio,
                last_compression_date = excluded.last_compression_date;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, upsertSQL, -1, &statement, nil) == SQLITE_OK else {
                return false
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, (conversationId as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(stats.totalCompressions))
            sqlite3_bind_int(statement, 3, Int32(stats.totalTokensSaved))
            sqlite3_bind_int(statement, 4, Int32(stats.totalOriginalTokens))
            sqlite3_bind_int(statement, 5, Int32(stats.totalCompressedTokens))
            sqlite3_bind_double(statement, 6, stats.averageCompressionRatio)

            if let lastDate = stats.lastCompressionDate {
                sqlite3_bind_double(statement, 7, lastDate.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, 7)
            }

            return sqlite3_step(statement) == SQLITE_DONE
        }
    }

    func loadCompressionStats(conversationId: String) -> CompressionStats? {
        return dbQueue.sync {
            let querySQL = """
            SELECT total_compressions, total_tokens_saved, total_original_tokens,
                   total_compressed_tokens, average_compression_ratio, last_compression_date
            FROM compression_stats
            WHERE conversation_id = ?;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
                return nil
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, (conversationId as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_ROW {
                var stats = CompressionStats()
                stats.totalCompressions = Int(sqlite3_column_int(statement, 0))
                stats.totalTokensSaved = Int(sqlite3_column_int(statement, 1))
                stats.totalOriginalTokens = Int(sqlite3_column_int(statement, 2))
                stats.totalCompressedTokens = Int(sqlite3_column_int(statement, 3))
                stats.averageCompressionRatio = sqlite3_column_double(statement, 4)

                if sqlite3_column_type(statement, 5) != SQLITE_NULL {
                    stats.lastCompressionDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
                }

                return stats
            }

            return nil
        }
    }
}
