//
//  WeatherService.swift
//  AIAdventChatV2
//
//  Created by Claude on 01.10.2025.
//

import Foundation

struct WeatherData: Codable {
    let name: String
    let main: Main
    let weather: [Weather]
    let wind: Wind

    struct Main: Codable {
        let temp: Double
        let feels_like: Double
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

class WeatherService {
    private let apiKey = "bd5e378503939ddaee76f12ad7a97608" // OpenWeatherMap API key
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"

    func fetchWeather(for city: String, completion: @escaping (Result<String, Error>) -> Void) {
        let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let urlString = "\(baseURL)?q=\(encodedCity)&appid=\(apiKey)&units=metric&lang=ru"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "WeatherService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Нет данных"])))
                return
            }

            do {
                let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
                let weatherInfo = """
                Актуальная погода в городе \(weatherData.name):
                - Температура: \(Int(weatherData.main.temp))°C
                - Ощущается как: \(Int(weatherData.main.feels_like))°C
                - Описание: \(weatherData.weather.first?.description ?? "")
                - Влажность: \(weatherData.main.humidity)%
                - Давление: \(weatherData.main.pressure) гПа
                - Скорость ветра: \(weatherData.wind.speed) м/с
                """
                completion(.success(weatherInfo))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func extractCityName(from message: String) -> String? {
        let message = message.lowercased()

        // Паттерны для поиска города
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

    func isWeatherRequest(_ message: String) -> Bool {
        let keywords = ["погод", "температур", "градус", "тепло", "холодно", "дожд", "снег", "солнечно"]
        let lowerMessage = message.lowercased()
        return keywords.contains { lowerMessage.contains($0) }
    }
}
