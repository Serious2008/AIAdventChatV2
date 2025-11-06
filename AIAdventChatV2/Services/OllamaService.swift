//
//  OllamaService.swift
//  AIAdventChatV2
//
//  Service for communicating with local Ollama LLM
//

import Foundation

class OllamaService {
    private let baseURL = "http://localhost:11434"

    // MARK: - Models

    struct OllamaGenerateRequest: Codable {
        let model: String
        let prompt: String
        let stream: Bool
        let options: Options?

        struct Options: Codable {
            let temperature: Double?
        }
    }

    struct OllamaGenerateResponse: Codable {
        let model: String
        let created_at: String
        let response: String
        let done: Bool
    }

    struct OllamaListModelsResponse: Codable {
        let models: [OllamaModel]
    }

    struct OllamaModel: Codable {
        let name: String
        let size: Int64
        let digest: String
        let modified_at: String
    }

    // MARK: - Check if Ollama is running

    func checkAvailability(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }

    // MARK: - List available models

    func listModels(completion: @escaping (Result<[OllamaModel], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            completion(.failure(NSError(domain: "OllamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OllamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }

            do {
                let response = try JSONDecoder().decode(OllamaListModelsResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response.models))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Generate response

    func generate(
        model: String = "llama3.2:3b",
        prompt: String,
        temperature: Double = 0.7,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            completion(.failure(NSError(domain: "OllamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0 // 2 minutes for generation

        let requestBody = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            stream: false,
            options: OllamaGenerateRequest.Options(temperature: temperature)
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        let startTime = Date()

        URLSession.shared.dataTask(with: request) { data, response, error in
            let responseTime = Date().timeIntervalSince(startTime)

            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OllamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }

            do {
                let response = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
                print("🤖 Ollama response time: \(responseTime)s")

                DispatchQueue.main.async {
                    completion(.success(response.response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Generate with metrics (for ChatViewModel integration)

    func generateWithMetrics(
        model: String = "llama3.2:3b",
        prompt: String,
        temperature: Double = 0.7,
        completion: @escaping (Result<(response: String, responseTime: TimeInterval, modelName: String), Error>) -> Void
    ) {
        let startTime = Date()

        generate(model: model, prompt: prompt, temperature: temperature) { result in
            let responseTime = Date().timeIntervalSince(startTime)

            switch result {
            case .success(let response):
                completion(.success((response: response, responseTime: responseTime, modelName: model)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
