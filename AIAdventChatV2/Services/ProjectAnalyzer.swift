//
//  ProjectAnalyzer.swift
//  AIAdventChatV2
//
//  Created by Claude Code on 20.10.2025.
//

import Foundation

/// Сервис для анализа структуры проекта
class ProjectAnalyzer {

    /// Результат анализа проекта
    struct AnalysisResult {
        let structure: String
        let problems: String
        let statistics: String
        let fileContents: [String: String]
    }

    /// Анализирует проект и возвращает структурированные данные
    static func analyzeProject() -> AnalysisResult {
        let projectPath = findProjectPath()

        // Собираем структуру проекта
        let structure = buildProjectStructure(at: projectPath)

        // Ищем потенциальные проблемы
        let problems = findPotentialProblems(at: projectPath)

        // Собираем статистику
        let statistics = collectStatistics(at: projectPath)

        // Читаем ключевые файлы
        let fileContents = readKeyFiles(at: projectPath)

        return AnalysisResult(
            structure: structure,
            problems: problems,
            statistics: statistics,
            fileContents: fileContents
        )
    }

    /// Находит путь к проекту
    private static func findProjectPath() -> String {
        // Получаем путь к текущему исполняемому файлу
        let bundlePath = Bundle.main.bundlePath

        // Проект находится в родительской директории от .app
        let projectPath = (bundlePath as NSString)
            .deletingLastPathComponent
            .replacingOccurrences(of: "/build/Debug", with: "")
            .replacingOccurrences(of: "/DerivedData", with: "")

        // Если мы в режиме разработки, ищем исходники
        let sourcePath = "\(projectPath)/AIAdventChatV2"

        if FileManager.default.fileExists(atPath: sourcePath) {
            return sourcePath
        }

        // Альтернативный путь
        let altPath = "/Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/AIAdventChatV2"
        if FileManager.default.fileExists(atPath: altPath) {
            return altPath
        }

        return sourcePath
    }

    /// Строит дерево структуры проекта
    private static func buildProjectStructure(at path: String) -> String {
        var result = "# 📁 СТРУКТУРА ПРОЕКТА\n\n"

        let fileManager = FileManager.default

        // Категории файлов
        var models: [String] = []
        var views: [String] = []
        var viewModels: [String] = []
        var services: [String] = []
        var other: [String] = []

        // Рекурсивно ищем все .swift файлы
        if let enumerator = fileManager.enumerator(atPath: path) {
            for case let file as String in enumerator {
                if file.hasSuffix(".swift") {
                    // Категоризируем
                    if file.contains("Models/") {
                        models.append(file)
                    } else if file.contains("Views/") {
                        views.append(file)
                    } else if file.contains("ViewModels/") {
                        viewModels.append(file)
                    } else if file.contains("Services/") {
                        services.append(file)
                    } else {
                        other.append(file)
                    }
                }
            }
        }

        result += "## Models (\(models.count) файлов)\n"
        models.sorted().forEach { result += "- \($0)\n" }

        result += "\n## Views (\(views.count) файлов)\n"
        views.sorted().forEach { result += "- \($0)\n" }

        result += "\n## ViewModels (\(viewModels.count) файлов)\n"
        viewModels.sorted().forEach { result += "- \($0)\n" }

        result += "\n## Services (\(services.count) файлов)\n"
        services.sorted().forEach { result += "- \($0)\n" }

        result += "\n## Другие (\(other.count) файлов)\n"
        other.sorted().forEach { result += "- \($0)\n" }

        return result
    }

    /// Ищет потенциальные проблемы в коде
    private static func findPotentialProblems(at path: String) -> String {
        var result = "# ⚠️ ПОТЕНЦИАЛЬНЫЕ ПРОБЛЕМЫ\n\n"

        var forceUnwraps: [(file: String, count: Int)] = []
        var forceCasts: [(file: String, count: Int)] = []
        var forceTries: [(file: String, count: Int)] = []
        var todos: [(file: String, count: Int)] = []

        let fileManager = FileManager.default

        if let enumerator = fileManager.enumerator(atPath: path) {
            for case let file as String in enumerator {
                if file.hasSuffix(".swift") {
                    let filePath = "\(path)/\(file)"

                    if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                        // Подсчитываем проблемы
                        let unwrapCount = content.components(separatedBy: "!").count - 1
                        let castCount = content.components(separatedBy: "as!").count - 1
                        let tryCount = content.components(separatedBy: "try!").count - 1
                        let todoCount = content.components(separatedBy: "TODO").count - 1 +
                                       content.components(separatedBy: "FIXME").count - 1

                        if unwrapCount > 0 {
                            forceUnwraps.append((file, unwrapCount))
                        }
                        if castCount > 0 {
                            forceCasts.append((file, castCount))
                        }
                        if tryCount > 0 {
                            forceTries.append((file, tryCount))
                        }
                        if todoCount > 0 {
                            todos.append((file, todoCount))
                        }
                    }
                }
            }
        }

        // Force Unwrapping
        result += "## 1. Force Unwrapping (!)\n"
        if !forceUnwraps.isEmpty {
            result += "Найдено \(forceUnwraps.reduce(0) { $0 + $1.count }) использований в \(forceUnwraps.count) файлах:\n\n"
            forceUnwraps.sorted { $0.count > $1.count }.prefix(10).forEach {
                result += "- **\($0.file)**: \($0.count) раз(а)\n"
            }
        } else {
            result += "✅ Не найдено\n"
        }

        // Force Casting
        result += "\n## 2. Force Casting (as!)\n"
        if !forceCasts.isEmpty {
            result += "Найдено \(forceCasts.reduce(0) { $0 + $1.count }) использований в \(forceCasts.count) файлах:\n\n"
            forceCasts.sorted { $0.count > $1.count }.forEach {
                result += "- **\($0.file)**: \($0.count) раз(а)\n"
            }
        } else {
            result += "✅ Не найдено\n"
        }

        // Force Try
        result += "\n## 3. Force Try (try!)\n"
        if !forceTries.isEmpty {
            result += "Найдено \(forceTries.reduce(0) { $0 + $1.count }) использований в \(forceTries.count) файлах:\n\n"
            forceTries.sorted { $0.count > $1.count }.forEach {
                result += "- **\($0.file)**: \($0.count) раз(а)\n"
            }
        } else {
            result += "✅ Не найдено\n"
        }

        // TODO/FIXME
        result += "\n## 4. TODO/FIXME комментарии\n"
        if !todos.isEmpty {
            result += "Найдено \(todos.reduce(0) { $0 + $1.count }) задач в \(todos.count) файлах:\n\n"
            todos.sorted { $0.count > $1.count }.forEach {
                result += "- **\($0.file)**: \($0.count) задач(и)\n"
            }
        } else {
            result += "✅ Не найдено\n"
        }

        return result
    }

    /// Собирает статистику проекта
    private static func collectStatistics(at path: String) -> String {
        var result = "# 📊 СТАТИСТИКА\n\n"

        var totalFiles = 0
        var totalLines = 0
        var largestFiles: [(file: String, lines: Int)] = []

        let fileManager = FileManager.default

        if let enumerator = fileManager.enumerator(atPath: path) {
            for case let file as String in enumerator {
                if file.hasSuffix(".swift") {
                    totalFiles += 1
                    let filePath = "\(path)/\(file)"

                    if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                        let lines = content.components(separatedBy: .newlines).count
                        totalLines += lines
                        largestFiles.append((file, lines))
                    }
                }
            }
        }

        result += "- **Всего .swift файлов**: \(totalFiles)\n"
        result += "- **Всего строк кода**: \(totalLines)\n"
        result += "- **Средний размер файла**: \(totalFiles > 0 ? totalLines / totalFiles : 0) строк\n"

        result += "\n## Самые большие файлы:\n"
        largestFiles.sorted { $0.lines > $1.lines }.prefix(5).forEach {
            result += "- **\($0.file)**: \($0.lines) строк\n"
        }

        return result
    }

    /// Читает содержимое ключевых файлов
    private static func readKeyFiles(at path: String) -> [String: String] {
        var contents: [String: String] = [:]

        let keyFiles = [
            "ViewModels/ChatViewModel.swift",
            "Services/ClaudeService.swift",
            "Models/Settings.swift",
            "AIAdventChatV2App.swift"
        ]

        for file in keyFiles {
            let filePath = "\(path)/\(file)"
            if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                // Ограничиваем размер до 500 строк
                let lines = content.components(separatedBy: .newlines).prefix(500).joined(separator: "\n")
                contents[file] = lines
            }
        }

        return contents
    }

    /// Формирует полный отчет для отправки Claude
    static func generateReport() -> String {
        let result = analyzeProject()

        var report = """
        # АВТОМАТИЧЕСКИЙ АНАЛИЗ ПРОЕКТА AIAdventChatV2

        Проект: macOS приложение на Swift/SwiftUI
        Назначение: AI чат-ассистент с интеграцией Claude API, MCP серверов, Yandex Tracker

        """

        report += result.statistics
        report += "\n\n"
        report += result.structure
        report += "\n\n"
        report += result.problems

        report += "\n\n# 📄 СОДЕРЖИМОЕ КЛЮЧЕВЫХ ФАЙЛОВ\n\n"
        for (file, content) in result.fileContents {
            report += "## \(file)\n"
            report += "```swift\n"
            report += content
            report += "\n```\n\n"
        }

        report += """


        # 🎯 ЗАДАЧА

        На основе предоставленной информации:
        1. Проанализируй архитектуру проекта
        2. Оцени качество кода
        3. Укажи на критические проблемы
        4. Дай конкретные рекомендации по улучшению

        Сосредоточься на:
        - Memory leaks (retain cycles)
        - Неправильное использование async/await
        - Отсутствие обработки ошибок
        - Нарушение принципов SOLID
        - Рефакторинг сложных методов
        """

        return report
    }
}
