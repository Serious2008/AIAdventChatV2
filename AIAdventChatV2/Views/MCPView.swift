import SwiftUI
import MCP

/// Основной View для работы с MCP серверами
struct MCPView: View {
    @StateObject private var mcpService = MCPService()
    @State private var serverCommand = "npx"
    @State private var serverArgs = "-y,@modelcontextprotocol/server-memory"
    @State private var isConnecting = false
    @State private var selectedTool: MCPTool?
    @State private var showToolCallSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Section
                    connectionSection

                    // Tools Section
                    if mcpService.isConnected {
                        toolsSection
                    }

                    // Popular Servers Section
                    if !mcpService.isConnected {
                        popularServersSection
                    }
                }
                .padding()
            }
            .navigationTitle("MCP Серверы")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if mcpService.isConnected {
                        Button("Отключиться") {
                            disconnectFromServer()
                        }
                    }
                }
            }
            .sheet(isPresented: $showToolCallSheet) {
                if let tool = selectedTool {
                    ToolCallView(tool: tool, mcpService: mcpService)
                }
            }
        }
        .onAppear {
            mcpService.initializeClient()
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Status
                HStack {
                    Image(systemName: mcpService.isConnected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(mcpService.isConnected ? .green : .secondary)

                    Text(mcpService.isConnected ? "Подключено" : "Не подключено")
                        .font(.headline)

                    Spacer()
                }

                if !mcpService.isConnected {
                    Divider()

                    // Command Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Команда:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("npx", text: $serverCommand)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Arguments Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Аргументы (через запятую):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("-y,@modelcontextprotocol/server-memory", text: $serverArgs)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Connect Button
                    Button(action: connectToServer) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text(isConnecting ? "Подключение..." : "Подключиться")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConnecting || serverCommand.isEmpty)
                } else {
                    Divider()

                    // Connected Info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Инструментов:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(mcpService.availableTools.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Spacer()

                        Button(action: refreshTools) {
                            Label("Обновить", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Error Message
                if let error = mcpService.errorMessage {
                    Divider()

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        } label: {
            Label("Подключение", systemImage: "network")
        }
    }

    // MARK: - Tools Section

    private var toolsSection: some View {
        GroupBox {
            if mcpService.availableTools.isEmpty {
                ContentUnavailableView(
                    "Нет инструментов",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Сервер не предоставил инструментов")
                )
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(mcpService.availableTools) { tool in
                        ToolCard(tool: tool) {
                            selectedTool = tool
                            showToolCallSheet = true
                        }
                    }
                }
                .padding()
            }
        } label: {
            Label("Доступные инструменты", systemImage: "wrench.and.screwdriver.fill")
        }
    }

    // MARK: - Popular Servers Section

    private var popularServersSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                Text("Популярные серверы")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(popularServers, id: \.name) { server in
                    ServerPresetCard(server: server) {
                        serverCommand = server.command
                        serverArgs = server.args
                    }
                }
            }
            .padding()
        } label: {
            Label("Быстрый выбор", systemImage: "star.fill")
        }
    }

    // MARK: - Actions

    private func connectToServer() {
        isConnecting = true
        let args = serverArgs.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        let command = [serverCommand] + args

        Task {
            do {
                try await mcpService.connect(serverCommand: command)
            } catch {
                print("Connection error: \(error)")
            }
            await MainActor.run {
                isConnecting = false
            }
        }
    }

    private func disconnectFromServer() {
        Task {
            await mcpService.disconnect()
        }
    }

    private func refreshTools() {
        Task {
            do {
                try await mcpService.fetchAvailableTools()
            } catch {
                print("Failed to refresh tools: \(error)")
            }
        }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: MCPTool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "wrench.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let description = tool.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Server Preset Card

struct ServerPresetCard: View {
    let server: ServerPreset
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: server.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(server.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(server.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let tool: MCPTool
    let mcpService: MCPService

    @Environment(\.dismiss) private var dismiss
    @State private var argumentsText = "{\n  \n}"
    @State private var result: String = ""
    @State private var isExecuting = false
    @State private var showSchema = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tool.name)
                                .font(.headline)
                            if let description = tool.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if tool.inputSchema != nil {
                            Button(action: { showSchema.toggle() }) {
                                Label(showSchema ? "Скрыть схему" : "Показать схему",
                                      systemImage: "doc.text.magnifyingglass")
                            }
                        }
                    }
                } header: {
                    Text("Инструмент")
                }

                if showSchema, let schema = tool.inputSchema {
                    Section("Схема аргументов") {
                        Text(formatSchema(schema))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Введите аргументы в формате JSON")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(action: fillExampleArgs) {
                                Label("Пример", systemImage: "lightbulb.fill")
                                    .font(.caption)
                            }
                        }

                        TextEditor(text: $argumentsText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 120)
                            .border(Color.gray.opacity(0.2))
                    }
                } header: {
                    Text("Аргументы")
                }

                Section {
                    Button(action: executeTool) {
                        HStack {
                            if isExecuting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(isExecuting ? "Выполнение..." : "Выполнить инструмент")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isExecuting || argumentsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !result.isEmpty {
                    Section("Результат") {
                        ScrollView {
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                    }
                }
            }
            .navigationTitle("Вызов инструмента")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private func fillExampleArgs() {
        // Заполнить примером в зависимости от имени инструмента
        switch tool.name {
        case "store_memory", "store":
            argumentsText = """
            {
              "key": "test_key",
              "value": "Hello from MCP!"
            }
            """
        case "retrieve_memory", "retrieve", "get":
            argumentsText = """
            {
              "key": "test_key"
            }
            """
        case "read_file":
            argumentsText = """
            {
              "path": "/path/to/file.txt"
            }
            """
        case "write_file":
            argumentsText = """
            {
              "path": "/path/to/file.txt",
              "content": "File content here"
            }
            """
        case "list_directory":
            argumentsText = """
            {
              "path": "/path/to/directory"
            }
            """
        default:
            argumentsText = """
            {
              "param1": "value1",
              "param2": "value2"
            }
            """
        }
    }

    private func formatSchema(_ value: Value) -> String {
        // Простое форматирование Value для отображения
        return String(describing: value)
    }

    private func executeTool() {
        isExecuting = true
        result = ""

        Task {
            do {
                // Парсим JSON и конвертируем в [String: Value]
                let arguments = try parseArguments(argumentsText)

                let toolResult = try await mcpService.callTool(name: tool.name, arguments: arguments)

                await MainActor.run {
                    result = formatResult(toolResult)
                    isExecuting = false
                }
            } catch let error as JSONParsingError {
                await MainActor.run {
                    result = "❌ Ошибка парсинга JSON:\n\(error.message)"
                    isExecuting = false
                }
            } catch {
                await MainActor.run {
                    result = "❌ Ошибка выполнения:\n\(error.localizedDescription)"
                    isExecuting = false
                }
            }
        }
    }

    private func parseArguments(_ jsonString: String) throws -> [String: Value] {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Если пустая строка или только {}, возвращаем nil
        if trimmed.isEmpty || trimmed == "{}" {
            return [:]
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw JSONParsingError(message: "Невозможно преобразовать строку в Data")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JSONParsingError(message: "Невалидный JSON формат")
        }

        var result: [String: Value] = [:]

        for (key, value) in json {
            result[key] = convertToMCPValue(value)
        }

        return result
    }

    private func convertToMCPValue(_ value: Any) -> Value {
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFNumberGetType(number) == .charType {
                return .bool(number.boolValue)
            } else if CFNumberIsFloatType(number) {
                return .double(number.doubleValue)
            } else {
                return .int(number.intValue)
            }
        case let bool as Bool:
            return .bool(bool)
        case let array as [Any]:
            return .array(array.map { convertToMCPValue($0) })
        case let dict as [String: Any]:
            var object: [String: Value] = [:]
            for (k, v) in dict {
                object[k] = convertToMCPValue(v)
            }
            return .object(object)
        default:
            return .null
        }
    }

    struct JSONParsingError: Error {
        let message: String
    }

    private func formatResult(_ toolResult: MCPToolResult) -> String {
        var output = ""

        if toolResult.isError {
            output += "⚠️ Error response\n\n"
        }

        for (index, content) in toolResult.content.enumerated() {
            output += "Content \(index + 1):\n"

            switch content {
            case .text(let text):
                output += text
            case .image(let data, let mimeType, _):
                output += "Image: \(data.count) bytes, type: \(mimeType)"
            case .audio(let data, let mimeType):
                output += "Audio: \(data.count) bytes, type: \(mimeType)"
            case .resource(let uri, let mimeType, let text):
                output += "Resource: \(uri)\nType: \(mimeType)"
                if let text = text {
                    output += "\n\(text)"
                }
            }

            output += "\n\n"
        }

        return output
    }
}

// MARK: - Models

struct ServerPreset {
    let name: String
    let description: String
    let command: String
    let args: String
    let icon: String
    let color: Color
}

let popularServers: [ServerPreset] = [
    ServerPreset(
        name: "Memory",
        description: "Key-value хранилище в памяти",
        command: "npx",
        args: "-y,@modelcontextprotocol/server-memory",
        icon: "brain.head.profile",
        color: .purple
    ),
    ServerPreset(
        name: "Filesystem",
        description: "Работа с файлами",
        command: "npx",
        args: "-y,@modelcontextprotocol/server-filesystem,/tmp",
        icon: "folder.fill",
        color: .blue
    ),
    ServerPreset(
        name: "Fetch",
        description: "HTTP запросы",
        command: "npx",
        args: "-y,@modelcontextprotocol/server-fetch",
        icon: "network",
        color: .green
    ),
    ServerPreset(
        name: "GitHub",
        description: "Работа с GitHub",
        command: "npx",
        args: "-y,@modelcontextprotocol/server-github",
        icon: "chevron.left.forwardslash.chevron.right",
        color: .orange
    ),
]

// MARK: - Preview

#Preview {
    MCPView()
}
