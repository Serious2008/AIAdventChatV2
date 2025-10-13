import SwiftUI

/// Простой UI для тестирования MCP подключения
struct MCPTestView: View {
    @StateObject private var mcpService = MCPService()
    @State private var serverCommand = "npx"
    @State private var serverArgs = "-y,@modelcontextprotocol/server-memory"
    @State private var isConnecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("MCP Test Client")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Connection Section
                GroupBox("Server Connection") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Status:")
                                .fontWeight(.semibold)
                            Text(mcpService.isConnected ? "Connected" : "Disconnected")
                                .foregroundColor(mcpService.isConnected ? .green : .secondary)
                        }

                        Divider()

                        Text("Server Command:")
                            .fontWeight(.semibold)
                        TextField("Command", text: $serverCommand)
                            .textFieldStyle(.roundedBorder)
                            .disabled(mcpService.isConnected)

                        Text("Arguments (comma-separated):")
                            .fontWeight(.semibold)
                        TextField("Arguments", text: $serverArgs)
                            .textFieldStyle(.roundedBorder)
                            .disabled(mcpService.isConnected)

                        HStack {
                            if !mcpService.isConnected {
                                Button(action: connectToServer) {
                                    if isConnecting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 100)
                                    } else {
                                        Text("Connect")
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isConnecting || serverCommand.isEmpty)
                            } else {
                                Button(action: disconnectFromServer) {
                                    Text("Disconnect")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button(action: refreshTools) {
                                    Text("Refresh Tools")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        if let error = mcpService.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                }

                // Available Tools Section
                if mcpService.isConnected {
                    GroupBox("Available Tools (\(mcpService.availableTools.count))") {
                        if mcpService.availableTools.isEmpty {
                            Text("No tools available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(mcpService.availableTools) { tool in
                                    ToolRow(tool: tool)
                                    if tool.id != mcpService.availableTools.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            mcpService.initializeClient()
        }
    }

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

// MARK: - Tool Row

struct ToolRow: View {
    let tool: MCPTool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tool.name)
                .font(.headline)
                .fontWeight(.semibold)

            if let description = tool.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if tool.inputSchema != nil {
                Text("Has input schema")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    MCPTestView()
}
