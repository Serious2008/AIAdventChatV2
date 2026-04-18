//
//  ClaudeToolTests.swift
//  AIAdventChatV2Tests
//

import XCTest
@testable import AIAdventChatV2

final class ClaudeToolTests: XCTestCase {

    // MARK: - ClaudeTool Initialization

    func testInitializationSetsFields() {
        let tool = ClaudeTool(
            name: "get_weather",
            description: "Fetches weather for a city",
            properties: [
                "city": ClaudeTool.InputSchema.Property(type: "string", description: "City name")
            ],
            required: ["city"]
        )

        XCTAssertEqual(tool.name, "get_weather")
        XCTAssertEqual(tool.description, "Fetches weather for a city")
        XCTAssertEqual(tool.input_schema.type, "object")
        XCTAssertEqual(tool.input_schema.required, ["city"])
        XCTAssertNotNil(tool.input_schema.properties["city"])
    }

    func testInputSchemaHasCorrectProperty() {
        let tool = ClaudeTool(
            name: "search",
            description: "Search tool",
            properties: [
                "query": ClaudeTool.InputSchema.Property(type: "string", description: "Search query"),
                "limit": ClaudeTool.InputSchema.Property(type: "integer", description: "Max results")
            ]
        )

        XCTAssertEqual(tool.input_schema.properties.count, 2)
        XCTAssertEqual(tool.input_schema.properties["query"]?.type, "string")
        XCTAssertEqual(tool.input_schema.properties["limit"]?.type, "integer")
    }

    func testPropertyWithEnum() {
        let prop = ClaudeTool.InputSchema.Property(
            type: "string",
            description: "Model provider",
            enum: ["claude", "gpt", "ollama"]
        )

        XCTAssertEqual(prop.enum, ["claude", "gpt", "ollama"])
        XCTAssertEqual(prop.type, "string")
    }

    func testPropertyWithoutEnum() {
        let prop = ClaudeTool.InputSchema.Property(type: "string", description: "A text field")
        XCTAssertNil(prop.enum)
    }

    func testRequiredIsNilWhenNotProvided() {
        let tool = ClaudeTool(name: "tool", description: "desc", properties: [:])
        XCTAssertNil(tool.input_schema.required)
    }

    // MARK: - ClaudeTool Codable

    func testEncodeDecodeRoundTrip() throws {
        let original = ClaudeTool(
            name: "analyze_code",
            description: "Analyzes Swift code for issues",
            properties: [
                "code": ClaudeTool.InputSchema.Property(type: "string", description: "Swift source code"),
                "language": ClaudeTool.InputSchema.Property(type: "string", description: "Language", enum: ["swift", "python"])
            ],
            required: ["code"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClaudeTool.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.input_schema.type, "object")
        XCTAssertEqual(decoded.input_schema.required, ["code"])
        XCTAssertEqual(decoded.input_schema.properties["language"]?.enum, ["swift", "python"])
    }

    func testArrayOfToolsEncodeDecode() throws {
        let tools = [
            ClaudeTool(name: "tool1", description: "desc1", properties: [:]),
            ClaudeTool(name: "tool2", description: "desc2", properties: ["x": .init(type: "integer", description: "count")])
        ]

        let data = try JSONEncoder().encode(tools)
        let decoded = try JSONDecoder().decode([ClaudeTool].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].name, "tool1")
        XCTAssertEqual(decoded[1].name, "tool2")
        XCTAssertEqual(decoded[1].input_schema.properties["x"]?.type, "integer")
    }

    // MARK: - ContentBlock

    func testTextBlockIsText() {
        let block = ClaudeToolResponse.ContentBlock(type: "text", text: "Hello", id: nil, name: nil, input: nil)
        XCTAssertTrue(block.isText)
        XCTAssertFalse(block.isToolUse)
    }

    func testToolUseBlockIsToolUse() {
        let block = ClaudeToolResponse.ContentBlock(type: "tool_use", text: nil, id: "call-1", name: "get_weather", input: nil)
        XCTAssertTrue(block.isToolUse)
        XCTAssertFalse(block.isText)
    }

    func testUnknownBlockTypeIsFalseForBoth() {
        let block = ClaudeToolResponse.ContentBlock(type: "image", text: nil, id: nil, name: nil, input: nil)
        XCTAssertFalse(block.isText)
        XCTAssertFalse(block.isToolUse)
    }

    // MARK: - ToolResult

    func testToolResultToMessageContent() {
        let result = ToolResult(tool_use_id: "use-123", content: "Moscow: +20°C", is_error: false)
        let dict = result.toMessageContent() as? [String: Any]

        XCTAssertEqual(dict?["type"] as? String, "tool_result")
        XCTAssertEqual(dict?["tool_use_id"] as? String, "use-123")
        XCTAssertEqual(dict?["content"] as? String, "Moscow: +20°C")
        XCTAssertEqual(dict?["is_error"] as? Bool, false)
    }

    func testToolResultErrorFlagPreserved() {
        let result = ToolResult(tool_use_id: "err-1", content: "API unreachable", is_error: true)
        let dict = result.toMessageContent() as? [String: Any]

        XCTAssertEqual(dict?["is_error"] as? Bool, true)
    }

    // MARK: - AnyCodable

    func testAnyCodableInt() throws {
        let wrapped = AnyCodable(42)
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.value as? Int, 42)
    }

    func testAnyCodableString() throws {
        let wrapped = AnyCodable("hello")
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.value as? String, "hello")
    }

    func testAnyCodableBool() throws {
        let wrapped = AnyCodable(true)
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.value as? Bool, true)
    }

    func testAnyCodableDouble() throws {
        let wrapped = AnyCodable(3.14)
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.value as? Double ?? 0, 3.14, accuracy: 0.001)
    }

    func testAnyCodableArray() throws {
        let wrapped = AnyCodable([1, 2, 3])
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        let arr = decoded.value as? [Any]
        XCTAssertNotNil(arr)
        XCTAssertEqual(arr?.count, 3)
    }

    func testAnyCodableDictionary() throws {
        let wrapped = AnyCodable(["key": "value"])
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        let dict = decoded.value as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["key"] as? String, "value")
    }

    // MARK: - ClaudeToolResponse Codable

    func testClaudeToolResponseDecodeFromJSON() throws {
        let json = """
        {
            "id": "msg-001",
            "type": "message",
            "role": "assistant",
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "stop_sequence": null,
            "content": [
                { "type": "text", "text": "The weather is sunny." }
            ],
            "usage": {
                "input_tokens": 100,
                "output_tokens": 20
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ClaudeToolResponse.self, from: data)

        XCTAssertEqual(response.id, "msg-001")
        XCTAssertEqual(response.role, "assistant")
        XCTAssertEqual(response.model, "claude-sonnet-4-6")
        XCTAssertEqual(response.stop_reason, "end_turn")
        XCTAssertNil(response.stop_sequence)
        XCTAssertEqual(response.content.count, 1)
        XCTAssertEqual(response.content[0].text, "The weather is sunny.")
        XCTAssertEqual(response.usage.input_tokens, 100)
        XCTAssertEqual(response.usage.output_tokens, 20)
    }
}
