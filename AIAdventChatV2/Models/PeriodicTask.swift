import Foundation

/// Модель периодической задачи
struct PeriodicTask: Codable, Identifiable {
    let id: UUID
    var action: String              // "get_weather_summary"
    var parameters: [String: String] // { "city": "Moscow" }
    var intervalMinutes: Int        // Интервал в минутах (60 = 1 час)
    var isActive: Bool
    var createdAt: Date
    var executionCount: Int

    init(
        id: UUID = UUID(),
        action: String,
        parameters: [String: String],
        intervalMinutes: Int,
        isActive: Bool = true,
        createdAt: Date = Date(),
        executionCount: Int = 0
    ) {
        self.id = id
        self.action = action
        self.parameters = parameters
        self.intervalMinutes = intervalMinutes
        self.isActive = isActive
        self.createdAt = createdAt
        self.executionCount = executionCount
    }
}
