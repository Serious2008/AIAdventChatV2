//
//  WeatherWidgetView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 18.04.2026.
//

import SwiftUI

struct WeatherWidgetView: View {
    // MARK: - Properties

    let city: String
    private let weatherService = WeatherService()

    // MARK: - State

    @State private var weatherData: WeatherData?
    @State private var isLoading = true
    @State private var loadError = false

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 60, height: 20)
            } else if let weather = weatherData {
                HStack(spacing: 4) {
                    Image(systemName: weatherIcon(for: weather.weather.first?.main ?? ""))
                        .foregroundColor(weatherIconColor(for: weather.weather.first?.main ?? ""))
                        .font(.callout)
                    Text("\(Int(weather.main.temp))°C")
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(weather.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .help("\(weather.weather.first?.description.capitalized ?? "") • Ощущается как \(Int(weather.main.feels_like))°C • Влажность \(weather.main.humidity)%")
                .onTapGesture { loadWeather() }
            } else if loadError {
                Button(action: loadWeather) {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .help("Обновить погоду")
            }
        }
        .onAppear { loadWeather() }
    }

    // MARK: - Private Methods

    private func loadWeather() {
        isLoading = true
        loadError = false
        print("🌤️ Загрузка погоды для города: \(city)")
        weatherService.fetchWeatherData(for: city) { result in
            isLoading = false
            switch result {
            case .success(let data):
                weatherData = data
                print("✅ Погода получена: \(Int(data.main.temp))°C, \(data.name)")
            case .failure(let error):
                loadError = true
                print("❌ Ошибка получения погоды: \(error.localizedDescription)")
            }
        }
    }

    private func weatherIcon(for condition: String) -> String {
        switch condition {
        case "Clear": return "sun.max.fill"
        case "Clouds": return "cloud.fill"
        case "Rain", "Drizzle": return "cloud.rain.fill"
        case "Thunderstorm": return "cloud.bolt.fill"
        case "Snow": return "cloud.snow.fill"
        case "Mist", "Fog", "Haze": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }

    private func weatherIconColor(for condition: String) -> Color {
        switch condition {
        case "Clear": return .yellow
        case "Clouds": return .gray
        case "Rain", "Drizzle": return .blue
        case "Thunderstorm": return .purple
        case "Snow": return .cyan
        case "Mist", "Fog", "Haze": return .gray
        default: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    WeatherWidgetView(city: "Moscow")
        .padding()
}
