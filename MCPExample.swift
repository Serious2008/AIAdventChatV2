import Foundation
import MCP

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

/// Минимальный пример использования MCP SDK
/// Этот файл демонстрирует базовое подключение к MCP серверу
/// и получение списка доступных инструментов

@main
struct MCPExample {
    static func main() async {
        print("=== MCP SDK Minimal Example ===\n")

        // Шаг 1: Создание клиента
        print("1. Creating MCP client...")
        let client = Client(name: "MCPExample", version: "1.0.0")
        print("   ✓ Client created: MCPExample v1.0.0\n")

        // Шаг 2: Игнорируем SIGPIPE
        print("2. Configuring signal handling...")
        signal(SIGPIPE, SIG_IGN)
        print("   ✓ SIGPIPE handling configured\n")

        // Шаг 3: Запуск MCP сервера как subprocess
        print("3. Starting MCP server process...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["npx", "-y", "@modelcontextprotocol/server-memory"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Обработчик stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("   [Server stderr]: \(output)")
            }
        }

        do {
            try process.run()
            print("   ✓ Server process started")

            // Даем серверу время на инициализацию
            print("   ⏳ Waiting for server initialization...")
            try await Task.sleep(for: .seconds(1))
            print("   ✓ Server ready\n")
        } catch {
            print("   ✗ Failed to start server: \(error)")
            return
        }

        // Шаг 4: Создание транспорта с правильными дескрипторами
        print("4. Creating stdio transport...")
        let inputFD = FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor)
        let outputFD = FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)
        let transport = StdioTransport(input: inputFD, output: outputFD)
        print("   ✓ Transport created with process pipes\n")

        do {
            // Шаг 5: Подключение к серверу
            print("5. Connecting to MCP server...")
            _ = try await client.connect(transport: transport)
            print("   ✓ Successfully connected to MCP server\n")

            // Шаг 6: Получение списка инструментов
            print("6. Fetching available tools...")
            let (tools, cursor) = try await client.listTools()
            print("   ✓ Received \(tools.count) tools from server")
            if let cursor = cursor {
                print("   Cursor for pagination: \(cursor)")
            }
            print()

            // Шаг 7: Вывод информации о каждом инструменте
            print("7. Available Tools:")
            print("   " + String(repeating: "-", count: 60))
            for (index, tool) in tools.enumerated() {
                print("   [\(index + 1)] \(tool.name)")
                if let description = tool.description {
                    print("       Description: \(description)")
                }
                if tool.inputSchema != nil {
                    print("       Has input schema: yes")
                }
                print()
            }

            // Шаг 8: Пример вызова инструмента (если есть)
            if let firstTool = tools.first {
                print("8. Example tool call:")
                print("   Calling tool: \(firstTool.name)...")

                // Пример: для memory server можно попробовать сохранить что-то
                if firstTool.name.contains("store") || firstTool.name.contains("save") {
                    let arguments: [String: Value] = [
                        "key": .string("test_key"),
                        "value": .string("Hello from MCP Swift SDK!")
                    ]

                    do {
                        let (content, isError) = try await client.callTool(
                            name: firstTool.name,
                            arguments: arguments
                        )
                        print("   ✓ Tool call successful")
                        print("   Error status: \(isError ?? false)")
                        print("   Content items: \(content.count)")
                        for item in content {
                            switch item {
                            case .text(let text):
                                print("   - Text: \(text)")
                            case .image(let data, let mimeType, _):
                                print("   - Image: \(data.count) bytes, type: \(mimeType)")
                            case .audio(let data, let mimeType):
                                print("   - Audio: \(data.count) bytes, type: \(mimeType)")
                            case .resource(let uri, _, _):
                                print("   - Resource: \(uri)")
                            }
                        }
                    } catch {
                        print("   ⚠ Tool call failed: \(error)")
                    }
                } else {
                    print("   ℹ Skipping tool call example (tool requires specific arguments)")
                }
                print()
            }

            // Шаг 9: Отключение
            print("9. Disconnecting from server...")
            await client.disconnect()
            process.terminate()
            try? await Task.sleep(for: .milliseconds(100))
            print("   ✓ Disconnected\n")

            print("=== Example completed successfully! ===")

        } catch {
            process.terminate()
            print("   ✗ Error: \(error.localizedDescription)")
            print("\nTroubleshooting:")
            print("- Make sure Node.js and npm are installed")
            print("- Check that you have internet connection")
            print("- Verify that App Sandbox is disabled in entitlements")
            print("- Try running: npx -y @modelcontextprotocol/server-memory")
        }
    }
}
