//
//  AutoTestView.swift
//  AIAdventChatV2
//
//  UI for automatic test generation and execution
//

import SwiftUI
import UniformTypeIdentifiers

struct AutoTestView: View {
    @ObservedObject var agent: AutoTestAgent
    @Environment(\.dismiss) var dismiss

    @State private var selectedFilePath: String = ""
    @State private var selectedFileName: String = ""
    @State private var showingFilePicker = false
    @State private var projectPath: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.largeTitle)
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Test Agent")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Агент-сотрудник для автоматического тестирования")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Step 1: File Selection
                    GroupBox(label: Label("1. Выберите файл для тестирования", systemImage: "doc.fill")) {
                        VStack(spacing: 12) {
                            if !selectedFileName.isEmpty {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.blue)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedFileName)
                                            .font(.headline)

                                        Text(selectedFilePath)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Button("Изменить") {
                                        showingFilePicker = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)

                                    Text("Выберите Swift файл для генерации тестов")
                                        .font(.headline)
                                        .foregroundColor(.secondary)

                                    Button(action: {
                                        showingFilePicker = true
                                    }) {
                                        HStack {
                                            Image(systemName: "folder")
                                            Text("Выбрать файл...")
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        }
                        .padding()
                    }

                    // Step 2: Generation Status
                    if agent.isGenerating {
                        GroupBox(label: Label("2. Генерация тестов", systemImage: "gearshape.fill")) {
                            VStack(spacing: 12) {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)

                                    Text(agent.currentStep)
                                        .font(.callout)
                                }

                                Text("Claude анализирует код и создаёт тесты...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }

                    // Generated Tests Preview
                    if !agent.generatedTestCode.isEmpty {
                        GroupBox(label: Label("Сгенерированные тесты", systemImage: "doc.text.fill")) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("\(agent.generatedTestCode.components(separatedBy: "\n").count) строк кода")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(agent.generatedTestCode, forType: .string)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.doc")
                                            Text("Копировать")
                                        }
                                        .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                ScrollView {
                                    Text(agent.generatedTestCode)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                .frame(height: 200)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                            }
                            .padding()
                        }
                    }

                    // Step 3: Test Running Status
                    if agent.isRunningTests {
                        GroupBox(label: Label("3. Запуск тестов", systemImage: "play.circle.fill")) {
                            VStack(spacing: 12) {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)

                                    Text("Выполняются тесты...")
                                        .font(.callout)
                                }

                                Text("xcodebuild test выполняет сгенерированные тесты")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }

                    // Results
                    if let results = agent.testResults {
                        TestResultsView(results: results)
                    }

                    // Error display
                    if let error = agent.error {
                        GroupBox(label: Label("Ошибка", systemImage: "exclamationmark.triangle.fill")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(error)
                                    .font(.callout)
                                    .foregroundColor(.red)

                                Button("Попробовать снова") {
                                    agent.error = nil
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer with action button
            HStack {
                if !agent.isGenerating && !agent.isRunningTests && agent.testResults != nil {
                    Button("Очистить") {
                        agent.testResults = nil
                        agent.generatedTestCode = ""
                        agent.error = nil
                        selectedFilePath = ""
                        selectedFileName = ""
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(action: {
                    guard !selectedFilePath.isEmpty, !projectPath.isEmpty else { return }

                    Task {
                        await agent.generateAndRunTests(for: selectedFilePath, projectPath: projectPath)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Сгенерировать и запустить тесты")
                    }
                    .frame(minWidth: 250)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFilePath.isEmpty || agent.isGenerating || agent.isRunningTests)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 800, height: 600)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.swiftSource],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFilePath = url.path
                    selectedFileName = url.lastPathComponent

                    // Определяем путь к проекту (ищем .xcodeproj)
                    var currentPath = url.deletingLastPathComponent()
                    while currentPath.path != "/" {
                        let xcodeproj = currentPath.appendingPathComponent("AIAdventChatV2.xcodeproj")
                        if FileManager.default.fileExists(atPath: xcodeproj.path) {
                            projectPath = currentPath.path
                            print("📂 Project path: \(projectPath)")
                            break
                        }
                        currentPath.deleteLastPathComponent()
                    }
                }
            case .failure(let error):
                agent.error = "Ошибка выбора файла: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Test Results View

struct TestResultsView: View {
    let results: TestResults

    var body: some View {
        GroupBox(label: Label("4. Результаты", systemImage: "checkmark.circle.fill")) {
            VStack(spacing: 20) {
                // Summary cards
                HStack(spacing: 20) {
                    ResultCard(
                        value: "\(results.totalPassed)",
                        label: "Passed",
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )

                    ResultCard(
                        value: "\(results.totalFailed)",
                        label: "Failed",
                        color: .red,
                        icon: "xmark.circle.fill"
                    )

                    ResultCard(
                        value: String(format: "%.1f%%", results.successRate),
                        label: "Success Rate",
                        color: results.successRate >= 80 ? .green : .orange,
                        icon: "chart.pie.fill"
                    )

                    ResultCard(
                        value: String(format: "%.1fs", results.executionTime),
                        label: "Time",
                        color: .blue,
                        icon: "clock.fill"
                    )
                }

                // Overall status
                HStack(spacing: 12) {
                    Text(results.statusEmoji)
                        .font(.system(size: 40))

                    VStack(alignment: .leading, spacing: 4) {
                        if results.totalFailed == 0 {
                            Text("Все тесты пройдены успешно!")
                                .font(.headline)
                                .foregroundColor(.green)
                        } else {
                            Text("\(results.totalFailed) \(results.totalFailed == 1 ? "тест провалился" : "тестов провалилось")")
                                .font(.headline)
                                .foregroundColor(.red)
                        }

                        Text("\(results.totalTests) \(results.totalTests == 1 ? "тест выполнен" : "тестов выполнено")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(results.totalFailed == 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)

                // Failed tests details
                if !results.failedTests.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Провалившиеся тесты:")
                            .font(.headline)
                            .foregroundColor(.red)

                        ForEach(results.failedTests) { test in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)

                                    Text(test.name)
                                        .font(.body)
                                        .fontWeight(.medium)

                                    Spacer()
                                }

                                Text(test.reason)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 24)

                                HStack {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)

                                    Text("\(test.file):\(test.line)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                .padding(.leading, 24)
                            }
                            .padding()
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Result Card

struct ResultCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
