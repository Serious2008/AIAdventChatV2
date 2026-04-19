//
//  WeatherService.swift
//  AIAdventChatV2
//
//  Created by Claude on 01.10.2025.
//

import Foundation

// MARK: - WeatherError (TASK-07)

enum WeatherError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL для запроса погоды"
        case .noData: return "Сервер не вернул данные"
        case .decodingFailed(let e): return "Ошибка декодирования: \(e.localizedDescription)"
        }
    }
}

// MARK: - WeatherData

struct WeatherData: Codable {
    let name: String
    let main: Main
    let weather: [Weather]
    let wind: Wind

    struct Main: Codable {
        let temp: Double
        let feelsLike: Double
        let humidity: Int
        let pressure: Int
    }

    struct Weather: Codable {
        let description: String
        let main: String
    }

    struct Wind: Codable {
        let speed: Double
    }
}

// MARK: - WeatherService

class WeatherService {

    // MARK: - Properties

    private let apiKey = "bd5e378503939ddaee76f12ad7a97608"
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"

    // MARK: - Public Methods

    /// Загружает данные о погоде для указанного города
    /// - Parameters:
    ///   - city: Название города
    ///   - completion: Результат с WeatherData или ошибкой
    func fetchWeatherData(for city: String, completion: @escaping (Result<WeatherData, Error>) -> Void) {
        guard let url = buildURL(for: city) else {
            print("❌ WeatherService: неверный URL для города '\(city)'")
            completion(.failure(WeatherError.invalidURL))
            return
        }
        print("🌤️ WeatherService: загрузка погоды для '\(city)'")
        performRequest(url: url) { result in
            switch result {
            case .success(let data):
                do {
                    let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
                    print("✅ WeatherService: погода получена — \(Int(weatherData.main.temp))°C, \(weatherData.name)")
                    completion(.success(weatherData))
                } catch {
                    print("❌ WeatherService: ошибка декодирования — \(error)")
                    completion(.failure(WeatherError.decodingFailed(error)))
                }
            case .failure(let error):
                print("❌ WeatherService: сетевая ошибка — \(error)")
                completion(.failure(error))
            }
        }
    }

    /// Загружает погоду и возвращает форматированную строку
    /// - Parameters:
    ///   - city: Название города
    ///   - completion: Результат с форматированной строкой или ошибкой
    func fetchWeather(for city: String, completion: @escaping (Result<String, Error>) -> Void) {
        fetchWeatherData(for: city) { result in
            switch result {
            case .success(let weatherData):
                let info = """
                Актуальная погода в городе \(weatherData.name):
                - Температура: \(Int(weatherData.main.temp))°C
                - Описание: \(weatherData.weather.first?.description ?? "")
                - Влажность: \(weatherData.main.humidity)%
                - Давление: \(weatherData.main.pressure) гПа
                - Скорость ветра: \(weatherData.wind.speed) м/с
                """
                completion(.success(info))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Извлекает название города из сообщения пользователя
    func extractCityName(from message: String) -> String? {
        let message = message.lowercased()
        let patterns = [
            "погода в ([а-яё\\-]+)",
            "погоду в ([а-яё\\-]+)",
            "погоде в ([а-яё\\-]+)",
            "какая погода в ([а-яё\\-]+)",
            "погода ([а-яё\\-]+)"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: message, options: [], range: NSRange(message.startIndex..., in: message)),
               let range = Range(match.range(at: 1), in: message) {
                return String(message[range])
            }
        }
        return nil
    }

    /// Определяет является ли сообщение запросом о погоде
    func isWeatherRequest(_ message: String) -> Bool {
        let keywords = ["погод", "температур", "градус", "тепло", "холодно", "дожд", "снег", "солнечно"]
        return keywords.contains { message.lowercased().contains($0) }
    }

    // MARK: - Private Methods

    private func buildURL(for city: String) -> URL? {
        let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        return URL(string: "\(baseURL)?q=\(encoded)&appid=\(apiKey)&units=metric&lang=ru")
    }

    private func performRequest(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(WeatherError.noData))
                    return
                }
                completion(.success(data))
            }
        }.resume()
    }
}
