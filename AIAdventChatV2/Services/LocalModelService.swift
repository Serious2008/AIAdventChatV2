//
//  LocalModelService.swift
//  AIAdventChatV2
//
//  Created by Claude on 01.10.2025.
//

import Foundation

class LocalModelService {

    // Проверка доступности Python и необходимых библиотек
    func checkPythonAvailability(completion: @escaping (Result<String, Error>) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if process.terminationStatus == 0 {
                    completion(.success(output.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(NSError(domain: "LocalModelService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Python не найден"])))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // Проверка доступности модели
    func checkModelAvailability(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Проверяем наличие необходимых библиотек
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-c", "import transformers; import torch; print('OK')"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), output.contains("OK") {
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        } catch {
            completion(.failure(error))
        }
    }

    // Суммаризация текста локально
    func summarize(
        text: String,
        progressCallback: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Создаем временный файл с текстом
        let tempInputFile = FileManager.default.temporaryDirectory.appendingPathComponent("input_\(UUID().uuidString).txt")
        let tempOutputFile = FileManager.default.temporaryDirectory.appendingPathComponent("output_\(UUID().uuidString).txt")

        do {
            try text.write(to: tempInputFile, atomically: true, encoding: .utf8)
        } catch {
            completion(.failure(error))
            return
        }

        // Создаем Python скрипт для суммаризации
        let pythonScript = """
        import sys
        import os

        try:
            from transformers import AutoTokenizer, AutoModelForCausalLM
            import torch

            # Читаем входной текст
            with open('\(tempInputFile.path)', 'r', encoding='utf-8') as f:
                text = f.read()

            # Загружаем модель и токенизатор
            model_name = "katanemo/Arch-Router-1.5B"

            print("Loading tokenizer...", file=sys.stderr)
            tokenizer = AutoTokenizer.from_pretrained(model_name)

            print("Loading model...", file=sys.stderr)
            model = AutoModelForCausalLM.from_pretrained(
                model_name,
                torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
                low_cpu_mem_usage=True
            )

            # Создаем промпт для суммаризации
            prompt = f\"\"\"Summarize the following text concisely, keeping the main points and key information.
        Keep it brief but informative. Write in the same language as the original text:

        {text}

        Summary:\"\"\"

            # Токенизируем
            print("Tokenizing...", file=sys.stderr)
            inputs = tokenizer(prompt, return_tensors="pt", max_length=2048, truncation=True)

            # Генерируем
            print("Generating summary...", file=sys.stderr)
            with torch.no_grad():
                outputs = model.generate(
                    **inputs,
                    max_new_tokens=500,
                    temperature=0.3,
                    do_sample=True,
                    top_p=0.9
                )

            # Декодируем
            summary = tokenizer.decode(outputs[0], skip_special_tokens=True)

            # Извлекаем только сгенерированную часть (после промпта)
            if "Summary:" in summary:
                summary = summary.split("Summary:")[-1].strip()

            # Записываем результат
            with open('\(tempOutputFile.path)', 'w', encoding='utf-8') as f:
                f.write(summary)

            print("Done!", file=sys.stderr)

        except Exception as e:
            print(f"Error: {str(e)}", file=sys.stderr)
            sys.exit(1)
        """

        // Создаем временный файл со скриптом
        let tempScriptFile = FileManager.default.temporaryDirectory.appendingPathComponent("summarize_\(UUID().uuidString).py")

        do {
            try pythonScript.write(to: tempScriptFile, atomically: true, encoding: .utf8)
        } catch {
            completion(.failure(error))
            return
        }

        // Запускаем Python скрипт
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", tempScriptFile.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Читаем stderr для отслеживания прогресса
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("🐍 Python: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                DispatchQueue.main.async {
                    progressCallback?(output.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        do {
            try process.run()

            // Ждем завершения в фоновом потоке
            DispatchQueue.global().async {
                process.waitUntilExit()

                DispatchQueue.main.async {
                    // Читаем результат
                    do {
                        let summary = try String(contentsOf: tempOutputFile, encoding: .utf8)

                        // Удаляем временные файлы
                        try? FileManager.default.removeItem(at: tempInputFile)
                        try? FileManager.default.removeItem(at: tempOutputFile)
                        try? FileManager.default.removeItem(at: tempScriptFile)

                        if process.terminationStatus == 0 {
                            completion(.success(summary))
                        } else {
                            completion(.failure(NSError(domain: "LocalModelService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Ошибка при выполнении Python скрипта"])))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // Установка зависимостей
    func installDependencies(progressCallback: @escaping (String) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-m", "pip", "install", "transformers", "torch", "accelerate", "--user"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    progressCallback(output.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        do {
            try process.run()

            DispatchQueue.global().async {
                process.waitUntilExit()

                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        completion(.success(()))
                    } else {
                        completion(.failure(NSError(domain: "LocalModelService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Не удалось установить зависимости"])))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
