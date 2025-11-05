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

            print("📍 About to call runTests...")
            let results = try await runTests(projectPath: projectPath)
            print("📍 runTests returned! Got results: \(results.totalPassed) passed, \(results.totalFailed) failed")

            print("📍 About to update UI on MainActor...")
            await MainActor.run {
                print("📍 Inside MainActor.run - updating UI...")
                self.testResults = results
                self.isRunningTests = false
                print("📍 UI updated! testResults set, isRunningTests = false")
            }
            print("📍 MainActor.run completed!")

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

            // Use Claude 3.7 Sonnet for test generation (not router models)
            let claudeModel = "claude-3-7-sonnet-20250219"

            let requestBody: [String: Any] = [
                "model": claudeModel,
                "max_tokens": 4096,
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ]

            print("🤖 Using model: \(claudeModel) for test generation")

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

                // Debug: print response
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Claude API Response:")
                    print(responseString)
                }

                do {
                    let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
                    guard let text = claudeResponse.content.first?.text else {
                        continuation.resume(throwing: NSError(domain: "AutoTestAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text in response"]))
                        return
                    }

                    print("✅ Successfully extracted test code from Claude response")

                    // Clean up response - remove markdown code blocks if present
                    var cleanedCode = text
                    if cleanedCode.hasPrefix("```swift") || cleanedCode.hasPrefix("```") {
                        cleanedCode = cleanedCode.replacingOccurrences(of: "```swift", with: "")
                        cleanedCode = cleanedCode.replacingOccurrences(of: "```", with: "")
                    }

                    continuation.resume(returning: cleanedCode.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                } catch {
                    print("❌ Failed to decode Claude response: \(error)")
                    if let decodingError = error as? DecodingError {
                        print("Decoding error details: \(decodingError)")
                    }
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
            "-destination", "platform=macOS",
            "-enableCodeCoverage", "NO"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        print("🚀 Starting xcodebuild test...")

        // Collect output in background
        var outputData = Data()
        var errorData = Data()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputData.append(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorData.append(data)
            }
        }

        try process.run()

        print("🔄 Process started, PID: \(process.processIdentifier)")

        // Poll for process completion
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                print("🔄 Starting polling loop...")
                var hasResumed = false
                let maxWaitTime: TimeInterval = 120 // 2 minutes timeout
                let pollInterval: TimeInterval = 0.5
                var elapsedTime: TimeInterval = 0

                while process.isRunning && elapsedTime < maxWaitTime {
                    Thread.sleep(forTimeInterval: pollInterval)
                    elapsedTime += pollInterval
                    if Int(elapsedTime) % 5 == 0 {
                        print("⏱ Still running... \(Int(elapsedTime))s elapsed")
                    }
                }

                print("🛑 Process stopped running. isRunning: \(process.isRunning), elapsed: \(elapsedTime)s")

                if process.isRunning {
                    print("⏰ Test execution timeout - terminating process")
                    process.terminate()
                    Thread.sleep(forTimeInterval: 1) // Give it time to terminate
                }

                let executionTime = Date().timeIntervalSince(startTime)

                print("✅ xcodebuild completed with exit code: \(process.terminationStatus)")
                print("📊 Execution time: \(executionTime)s")

                // Stop reading handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                // Give a moment for final data to be captured
                Thread.sleep(forTimeInterval: 0.2)

                print("📦 Output data size: \(outputData.count) bytes")
                print("📦 Error data size: \(errorData.count) bytes")

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                let combinedOutput = output + "\n" + errorOutput

                print("🔍 About to parse test results...")
                let results = self.parseTestResults(combinedOutput, executionTime: executionTime)
                print("✅ Parsed results: \(results.totalPassed) passed, \(results.totalFailed) failed")
                print("📊 Results object created successfully")

                print("🔄 About to resume continuation...")
                print("📊 hasResumed flag: \(hasResumed)")

                if !hasResumed {
                    hasResumed = true
                    print("🔄 Calling continuation.resume...")
                    continuation.resume(returning: results)
                    print("✅ Continuation resumed!")
                } else {
                    print("⚠️ Already resumed, skipping")
                }
            }
        }
    }

    // MARK: - Test Results Parsing

    private func parseTestResults(_ output: String, executionTime: TimeInterval) -> TestResults {
        print("📊 Parsing test results...")
        print("Output length: \(output.count) characters")

        // Print full output for debugging (first 3000 and last 3000 chars)
        print("📝 Test output (first 3000 chars):")
        print(String(output.prefix(3000)))
        print("\n" + String(repeating: "=", count: 80) + "\n")
        print("📝 Test output (last 3000 chars):")
        print(String(output.suffix(3000)))

        var passed = 0
        var failed = 0
        var total = 0
        var failedTests: [FailedTest] = []

        // Multiple parsing strategies

        // Strategy 1: Try different summary patterns
        let summaryPatterns = [
            #"Executed (\d+) tests?, with (\d+) failures?"#,
            #"Test Suite .+ finished at .+\n\s+Executed (\d+) tests?, with (\d+) failures?"#,
            #"(\d+) tests?, (\d+) failures?"#
        ]

        for summaryPattern in summaryPatterns {
            if let summaryRegex = try? NSRegularExpression(pattern: summaryPattern, options: [.caseInsensitive]),
               let match = summaryRegex.firstMatch(in: output, options: [], range: NSRange(output.startIndex..., in: output)) {

                if let totalRange = Range(match.range(at: 1), in: output),
                   let failedRange = Range(match.range(at: 2), in: output) {
                    total = Int(output[totalRange]) ?? 0
                    failed = Int(output[failedRange]) ?? 0
                    passed = total - failed

                    print("✅ Found summary with pattern '\(summaryPattern)': \(total) tests, \(failed) failures")
                    break
                }
            }
        }

        // Strategy 2: If no summary found, count individual test results
        if total == 0 {
            print("⚠️ No summary found, counting individual tests...")

            let passedPatterns = [
                #"Test case '.+' passed on '.+' \(\d+\.\d+ seconds\)"#,  // Modern Xcode format
                #"Test Case '-\[.+\]' passed \(\d+\.\d+ seconds\)"#,
                #"✓ .+ \(\d+\.\d+s\)"#,
                #"Test Case '.*' passed"#,
                #"\[PASS\]"#
            ]

            let failedPatterns = [
                #"Test case '.+' failed on '.+' \(\d+\.\d+ seconds\)"#,  // Modern Xcode format
                #"Test Case '-\[.+\]' failed \(\d+\.\d+ seconds\)"#,
                #"✗ .+ \(\d+\.\d+s\)"#,
                #"Test Case '.*' failed"#,
                #"\[FAIL\]"#
            ]

            for (index, passedPattern) in passedPatterns.enumerated() {
                if let passedRegex = try? NSRegularExpression(pattern: passedPattern, options: []) {
                    let count = passedRegex.numberOfMatches(in: output, options: [], range: NSRange(output.startIndex..., in: output))
                    if count > 0 {
                        passed = count
                        print("✅ Found \(passed) passed tests with pattern #\(index+1): '\(passedPattern)'")
                        break
                    }
                }
            }

            for (index, failedPattern) in failedPatterns.enumerated() {
                if let failedRegex = try? NSRegularExpression(pattern: failedPattern, options: []) {
                    let count = failedRegex.numberOfMatches(in: output, options: [], range: NSRange(output.startIndex..., in: output))
                    if count > 0 {
                        failed = count
                        print("✅ Found \(failed) failed tests with pattern #\(index+1): '\(failedPattern)'")
                        break
                    }
                }
            }

            total = passed + failed
            print("✅ Counted: \(passed) passed, \(failed) failed, \(total) total")
        }

        print("🔍 About to parse failed test details...")

        // Parse failed test details - but only if we have failed tests and reasonable output size
        if failed > 0 && output.count < 100000 {
            print("🔍 Attempting to parse \(failed) failed test details from \(output.count) chars")

            let failurePattern = #"(.+?):\d+: error: (.+?) : (.+?)(?:\n|$)"#
            print("🔍 Created failure pattern")

            if let failureRegex = try? NSRegularExpression(pattern: failurePattern, options: []) {
                print("🔍 Created failureRegex, about to call matches()...")

                let matches = failureRegex.matches(in: output, options: [], range: NSRange(output.startIndex..., in: output))
                print("🔍 Got \(matches.count) failure matches")

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
                print("🔍 Finished processing failure matches")
            } else {
                print("🔍 Failed to create failureRegex")
            }
        } else {
            print("🔍 Skipping failed test parsing (failed=\(failed), output.count=\(output.count))")
        }

        print("🔍 About to print final results...")
        print("📊 Final results: \(passed) passed, \(failed) failed, \(total) total")

        print("🔍 Creating TestResults object...")
        let results = TestResults(
            totalPassed: passed,
            totalFailed: failed,
            totalTests: total,
            executionTime: executionTime,
            failedTests: failedTests
        )
        print("🔍 TestResults object created, about to return...")

        return results
    }
}
