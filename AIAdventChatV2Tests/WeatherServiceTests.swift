//
//  WeatherServiceTests.swift
//  AIAdventChatV2Tests
//
//  Created by Sergey Markov on 19.04.2026.
//

import XCTest
@testable import AIAdventChatV2

final class WeatherServiceTests: XCTestCase {

    var sut: WeatherService!

    override func setUp() {
        super.setUp()
        sut = WeatherService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - extractCityName (TASK-09)

    func testExtractCityNameFromDirectRequest() {
        XCTAssertEqual(sut.extractCityName(from: "погода в москве"), "москве")
    }

    func testExtractCityNameFromAccusative() {
        XCTAssertEqual(sut.extractCityName(from: "покажи погоду в питере"), "питере")
    }

    func testExtractCityNameFromDative() {
        XCTAssertEqual(sut.extractCityName(from: "что там по погоде в казани"), "казани")
    }

    func testExtractCityNameWithQuestion() {
        XCTAssertEqual(sut.extractCityName(from: "какая погода в новосибирске"), "новосибирске")
    }

    func testExtractCityNameWithoutPreposition() {
        XCTAssertNotNil(sut.extractCityName(from: "погода екатеринбург"))
    }

    func testExtractCityNameReturnsNilForNonWeather() {
        XCTAssertNil(sut.extractCityName(from: "как дела"))
    }

    func testExtractCityNameReturnsNilForEmptyString() {
        XCTAssertNil(sut.extractCityName(from: ""))
    }

    func testExtractCityNameIsCaseInsensitive() {
        XCTAssertEqual(sut.extractCityName(from: "Погода в Москве"), "москве")
    }

    // MARK: - isWeatherRequest (TASK-10)

    func testIsWeatherRequestWithPogoda() {
        XCTAssertTrue(sut.isWeatherRequest("какая погода сегодня"))
    }

    func testIsWeatherRequestWithTemperatura() {
        XCTAssertTrue(sut.isWeatherRequest("какая температура на улице"))
    }

    func testIsWeatherRequestWithGradus() {
        XCTAssertTrue(sut.isWeatherRequest("сколько градусов на улице"))
    }

    func testIsWeatherRequestWithDozd() {
        XCTAssertTrue(sut.isWeatherRequest("будет ли дождь завтра"))
    }

    func testIsWeatherRequestWithSneg() {
        XCTAssertTrue(sut.isWeatherRequest("идёт ли снег"))
    }

    func testIsWeatherRequestReturnsFalseForUnrelated() {
        XCTAssertFalse(sut.isWeatherRequest("напиши код на Swift"))
    }

    func testIsWeatherRequestReturnsFalseForEmptyString() {
        XCTAssertFalse(sut.isWeatherRequest(""))
    }

    func testIsWeatherRequestIsCaseInsensitive() {
        XCTAssertTrue(sut.isWeatherRequest("ПОГОДА в городе"))
    }
}

// MARK: - WeatherDataTests (TASK-11)

final class WeatherDataTests: XCTestCase {

    func testDecodeWeatherDataFromJSON() throws {
        let json = """
        {
            "name": "Moscow",
            "main": { "temp": 15.5, "feelsLike": 13.0, "humidity": 70, "pressure": 1013 },
            "weather": [{ "description": "ясно", "main": "Clear" }],
            "wind": { "speed": 3.5 }
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(WeatherData.self, from: json)
        XCTAssertEqual(data.name, "Moscow")
        XCTAssertEqual(data.main.temp, 15.5)
        XCTAssertEqual(data.main.feelsLike, 13.0)
        XCTAssertEqual(data.main.humidity, 70)
        XCTAssertEqual(data.main.pressure, 1013)
        XCTAssertEqual(data.weather.first?.main, "Clear")
        XCTAssertEqual(data.weather.first?.description, "ясно")
        XCTAssertEqual(data.wind.speed, 3.5)
    }

    func testDecodeWeatherDataMultipleConditions() throws {
        let json = """
        {
            "name": "SPb",
            "main": { "temp": 5.0, "feelsLike": 2.0, "humidity": 90, "pressure": 998 },
            "weather": [
                { "description": "дождь", "main": "Rain" },
                { "description": "туман", "main": "Mist" }
            ],
            "wind": { "speed": 7.0 }
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(WeatherData.self, from: json)
        XCTAssertEqual(data.weather.count, 2)
        XCTAssertEqual(data.weather[0].main, "Rain")
        XCTAssertEqual(data.weather[1].main, "Mist")
    }

    func testDecodeFailsWithMissingField() {
        let json = """
        { "name": "Moscow" }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(WeatherData.self, from: json))
    }

    func testEncodeDecodeRoundTrip() throws {
        let original = WeatherData(
            name: "Kazan",
            main: .init(temp: 20.0, feelsLike: 18.0, humidity: 60, pressure: 1010),
            weather: [.init(description: "облачно", main: "Clouds")],
            wind: .init(speed: 5.0)
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WeatherData.self, from: encoded)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.main.temp, original.main.temp)
    }
}
