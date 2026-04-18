//
//  PeriodicTaskTests.swift
//  AIAdventChatV2Tests
//

import XCTest
@testable import AIAdventChatV2

final class PeriodicTaskTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInitializationValues() {
        let task = PeriodicTask(
            action: "get_weather_summary",
            parameters: ["city": "Moscow"],
            intervalMinutes: 60
        )

        XCTAssertEqual(task.action, "get_weather_summary")
        XCTAssertEqual(task.parameters, ["city": "Moscow"])
        XCTAssertEqual(task.intervalMinutes, 60)
        XCTAssertTrue(task.isActive, "Task should be active by default")
        XCTAssertEqual(task.executionCount, 0)
        XCTAssertNotNil(task.id)
    }

    func testCustomIdIsPreserved() {
        let customId = UUID()
        let task = PeriodicTask(
            id: customId,
            action: "check",
            parameters: [:],
            intervalMinutes: 30
        )
        XCTAssertEqual(task.id, customId)
    }

    func testInactiveTaskInitialization() {
        let task = PeriodicTask(
            action: "action",
            parameters: [:],
            intervalMinutes: 10,
            isActive: false
        )
        XCTAssertFalse(task.isActive)
    }

    func testCustomExecutionCount() {
        let task = PeriodicTask(
            action: "action",
            parameters: [:],
            intervalMinutes: 10,
            executionCount: 5
        )
        XCTAssertEqual(task.executionCount, 5)
    }

    func testEmptyParameters() {
        let task = PeriodicTask(action: "action", parameters: [:], intervalMinutes: 60)
        XCTAssertTrue(task.parameters.isEmpty)
    }

    func testMultipleParameters() {
        let params = ["city": "Moscow", "units": "metric", "lang": "ru"]
        let task = PeriodicTask(action: "weather", parameters: params, intervalMinutes: 60)

        XCTAssertEqual(task.parameters.count, 3)
        XCTAssertEqual(task.parameters["city"], "Moscow")
        XCTAssertEqual(task.parameters["units"], "metric")
        XCTAssertEqual(task.parameters["lang"], "ru")
    }

    func testCreatedAtDefaultIsRecent() {
        let before = Date()
        let task = PeriodicTask(action: "action", parameters: [:], intervalMinutes: 60)
        let after = Date()

        XCTAssertGreaterThanOrEqual(task.createdAt, before)
        XCTAssertLessThanOrEqual(task.createdAt, after)
    }

    // MARK: - Identifiable

    func testEachTaskHasUniqueId() {
        let task1 = PeriodicTask(action: "a", parameters: [:], intervalMinutes: 1)
        let task2 = PeriodicTask(action: "b", parameters: [:], intervalMinutes: 2)
        XCTAssertNotEqual(task1.id, task2.id)
    }

    // MARK: - Codable round-trip

    func testEncodeDecode() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let original = PeriodicTask(
            id: UUID(),
            action: "get_weather",
            parameters: ["city": "Paris", "lang": "fr"],
            intervalMinutes: 120,
            isActive: true,
            createdAt: fixedDate,
            executionCount: 3
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PeriodicTask.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.action, original.action)
        XCTAssertEqual(decoded.parameters, original.parameters)
        XCTAssertEqual(decoded.intervalMinutes, original.intervalMinutes)
        XCTAssertEqual(decoded.isActive, original.isActive)
        XCTAssertEqual(decoded.executionCount, original.executionCount)
        XCTAssertEqual(
            decoded.createdAt.timeIntervalSince1970,
            original.createdAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testArrayEncodeDecode() throws {
        let tasks = [
            PeriodicTask(action: "weather", parameters: ["city": "Moscow"], intervalMinutes: 60),
            PeriodicTask(action: "tracker", parameters: ["project": "TEST"], intervalMinutes: 30),
        ]

        let data = try JSONEncoder().encode(tasks)
        let decoded = try JSONDecoder().decode([PeriodicTask].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].action, "weather")
        XCTAssertEqual(decoded[1].action, "tracker")
        XCTAssertEqual(decoded[1].intervalMinutes, 30)
    }

    func testInactiveTaskSurvivesRoundTrip() throws {
        let original = PeriodicTask(
            action: "paused",
            parameters: [:],
            intervalMinutes: 60,
            isActive: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PeriodicTask.self, from: data)

        XCTAssertFalse(decoded.isActive)
    }

    // MARK: - Edge cases

    func testZeroIntervalMinutes() {
        let task = PeriodicTask(action: "action", parameters: [:], intervalMinutes: 0)
        XCTAssertEqual(task.intervalMinutes, 0)
    }

    func testLargeIntervalMinutes() {
        let oneYear = 525_600
        let task = PeriodicTask(action: "action", parameters: [:], intervalMinutes: oneYear)
        XCTAssertEqual(task.intervalMinutes, oneYear)
    }

    func testActionStringIsPreservedExactly() {
        let action = "get_weather_summary_with_special_chars_123"
        let task = PeriodicTask(action: action, parameters: [:], intervalMinutes: 1)
        XCTAssertEqual(task.action, action)
    }
}
