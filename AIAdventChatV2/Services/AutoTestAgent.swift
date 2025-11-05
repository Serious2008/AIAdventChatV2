//
//  AutoTestAgent.swift
//  AIAdventChatV2
//
//  Agent for automatic test generation and execution
//

import Foundation
import Combine

// MARK: - Test Results Model

struct TestResults {
    let totalPassed: Int
    let totalFailed: Int
    let totalTests: Int
    let executionTime: TimeInterval
    let failedTests: [FailedTest]

    var successRate: Double {
        guard totalTests > 0 else { return 0.0 }
        return Double(totalPassed) / Double(totalTests) * 100
    }

    var statusEmoji: String {
        if totalFailed == 0 {
            return "✅"
        } else if totalFailed < totalTests / 2 {
            return "⚠️"
        } else {
            return "❌"
        }
    }
}

struct FailedTest: Identifiable {
    let id = UUID()
    let name: String
    let reason: String
    let file: String
    let line: Int
}

// MARK: - Auto Test Agent

class AutoTestAgent: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var isRunningTests: Bool = false
    @Published var testResults: TestResults?
    @Published var generatedTestCode: String = ""
    @Published var currentStep: String = ""
    @Published var error: String?

    private let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    // MARK: - Main Workflow

    func generateAndRunTests(for filePath: String, projectPath: String) async {
        do {
            // Reset state
            await MainActor.run {
                self.error = nil
                self.testResults = nil
                self.generatedTestCode = ""
            }

            // Step 1: Read source code
            await MainActor.run {
                self.isGenerating = true
                self.currentStep = "Чтение файла..."
            }

            let sourceCode = try String(contentsOfFile: filePath, encoding: .utf8)
            let fileName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent

            // Step 2: Generate tests via Claude
            await MainActor.run {
                self.currentStep = "Генерация тестов с помощью Claude..."
            }

            let testCode = try await generateTests(sourceCode: sourceCode, fileName: fileName)

            await MainActor.run {
                self.generatedTestCode = testCode
                self.isGenerating = false
            }

            // Step 3: Write test file
            await MainActor.run {
                self.currentStep = "Сохранение тестов..."
            }

            let testFilePath = "\(projectPath)/AIAdventChatV2Tests/\(fileName)Tests.swift"
            try testCode.write(toFile: testFilePath, atomically: true, encoding: .utf8)
            print("✅ Test file written to: \(testFilePath)")

            // Step 4: Run tests
            await MainActor.run {
                self.isRunningTests = true
                self.currentStep = "Запуск тестов..."
            }

            let results = try await runTests(projectPath: projectPath)

            await MainActor.run {
                self.testResults = results
                self.isRunningTests = false
            }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isGenerating = false
                self.isRunningTests = false
            }
        }
    }

    // MARK: - Test Generation

    private func generateTests(sourceCode: String, fileName: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let claudeService = ClaudeService()

            let prompt = """
            Проанализируй следующий Swift код и создай для него XCTest тесты.

            Файл: \(fileName).swift

            Код:
            ```swift
            \(sourceCode)
            ```

            Требования к тестам:
            1. Используй XCTest framework
            2. Импортируй необходимые модули (@testable import AIAdventChatV2)
            3. Создай класс тестов наследующий от XCTestCase
            4. Покрой основную функциональность тестами
            5. Используй setUp() и tearDown() если нужно
            6. Добавь edge cases и граничные условия

            Верни ТОЛЬКО код тестов без дополнительных объяснений, markdown или форматирования.
            Начни с импортов и заканчивая закрывающей скобкой класса.
            """

            let url = URL(string: "https://api.anthropic.com/v1/messages")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let requestBody: [String: Any] = [
                "model": settings.selectedModel,
                "max_tokens": 4096,
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data = data else {
                    continuation.resume(throwing: NSError(domain: "AutoTestAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    return
                }

                do {
                    let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
                    guard let text = claudeResponse.content.first?.text else {
                        continuation.resume(throwing: NSError(domain: "AutoTestAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text in response"]))
                        return
                    }

                    // Clean up response - remove markdown code blocks if present
                    var cleanedCode = text
                    if cleanedCode.hasPrefix("```swift") || cleanedCode.hasPrefix("```") {
                        cleanedCode = cleanedCode.replacingOccurrences(of: "```swift", with: "")
                        cleanedCode = cleanedCode.replacingOccurrences(of: "```", with: "")
                    }

                    continuation.resume(returning: cleanedCode.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            task.resume()
        }
    }

    // MARK: - Test Execution

    private func runTests(projectPath: String) async throws -> TestResults {
        let startTime = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "test",
            "-scheme", "AIAdventChatV2",
            "-configuration", "Debug",
            "-destination", "platform=macOS"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let executionTime = Date().timeIntervalSince(startTime)

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        let combinedOutput = output + "\n" + errorOutput

        return parseTestResults(combinedOutput, executionTime: executionTime)
    }

    // MARK: - Test Results Parsing

    private func parseTestResults(_ output: String, executionTime: TimeInterval) -> TestResults {
        print("📊 Parsing test results...")
        print("Output length: \(output.count) characters")

        // Print last 2000 chars for debugging
        let outputTail = String(output.suffix(2000))
        print("📝 Test output (last 2000 chars):")
        print(outputTail)

        var passed = 0
        var failed = 0
        var total = 0
        var failedTests: [FailedTest] = []

        // Dual approach parsing

        // 1. Try to find summary line first
        let summaryPattern = #"Executed (\d+) tests?, with (\d+) failures?"#
        if let summaryRegex = try? NSRegularExpression(pattern: summaryPattern, options: []),
           let match = summaryRegex.firstMatch(in: output, options: [], range: NSRange(output.startIndex..., in: output)) {

            if let totalRange = Range(match.range(at: 1), in: output),
               let failedRange = Range(match.range(at: 2), in: output) {
                total = Int(output[totalRange]) ?? 0
                failed = Int(output[failedRange]) ?? 0
                passed = total - failed

                print("✅ Found summary: \(total) tests, \(failed) failures")
            }
        } else {
            // 2. Fallback: count individual test results
            print("⚠️ No summary found, counting individual tests...")

            let passedPattern = #"Test Case '.*' passed \(\d+\.\d+ seconds\)"#
            let failedPattern = #"Test Case '.*' failed \(\d+\.\d+ seconds\)"#

            if let passedRegex = try? NSRegularExpression(pattern: passedPattern, options: []) {
                passed = passedRegex.numberOfMatches(in: output, options: [], range: NSRange(output.startIndex..., in: output))
            }

            if let failedRegex = try? NSRegularExpression(pattern: failedPattern, options: []) {
                failed = failedRegex.numberOfMatches(in: output, options: [], range: NSRange(output.startIndex..., in: output))
            }

            total = passed + failed
            print("✅ Counted: \(passed) passed, \(failed) failed")
        }

        // Parse failed test details
        let failurePattern = #"(.+?):\d+: error: (.+?) : (.+?)(?:\n|$)"#
        if let failureRegex = try? NSRegularExpression(pattern: failurePattern, options: [.dotMatchesLineSeparators]) {
            let matches = failureRegex.matches(in: output, options: [], range: NSRange(output.startIndex..., in: output))

            for match in matches {
                if match.numberOfRanges >= 4,
                   let fileRange = Range(match.range(at: 1), in: output),
                   let nameRange = Range(match.range(at: 2), in: output),
                   let reasonRange = Range(match.range(at: 3), in: output) {

                    let file = String(output[fileRange])
                    let name = String(output[nameRange])
                    let reason = String(output[reasonRange])

                    let failedTest = FailedTest(
                        name: name,
                        reason: reason,
                        file: file,
                        line: 0
                    )
                    failedTests.append(failedTest)
                }
            }
        }

        print("📊 Final results: \(passed) passed, \(failed) failed, \(total) total")

        return TestResults(
            totalPassed: passed,
            totalFailed: failed,
            totalTests: total,
            executionTime: executionTime,
            failedTests: failedTests
        )
    }
}
