//
//  ClaudeTool.swift
//  AIAdventChatV2
//
//  Models for Claude Tool Use API
//

import Foundation

// MARK: - Tool Definition

/// Определение инструмента для Claude API
struct ClaudeTool: Codable {
    let name: String
    let description: String
    let input_schema: InputSchema

    struct InputSchema: Codable {
        let type: String
        let properties: [String: Property]
        let required: [String]?

        struct Property: Codable {
            let type: String
            let description: String
            let `enum`: [String]?

            init(type: String, description: String, enum: [String]? = nil) {
                self.type = type
                self.description = description
                self.enum = `enum`
            }
        }
    }

    init(name: String, description: String, properties: [String: InputSchema.Property], required: [String]? = nil) {
        self.name = name
        self.description = description
        self.input_schema = InputSchema(
            type: "object",
            properties: properties,
            required: required
        )
    }
}

// MARK: - Claude Response with Tool Use

/// Расширенный ответ от Claude с поддержкой tool_use
struct ClaudeToolResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stop_reason: String?
    let stop_sequence: String?
    let usage: Usage

    struct ContentBlock: Codable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: AnyCodable]?

        /// Является ли блок текстовым
        var isText: Bool {
            return type == "text"
        }

        /// Является ли блок tool_use
        var isToolUse: Bool {
            return type == "tool_use"
        }
    }

    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
    }
}

// MARK: - Helper для Any в JSON

/// Обертка для динамических значений в JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Tool Result

/// Результат выполнения инструмента
struct ToolResult {
    let tool_use_id: String
    let content: String
    let is_error: Bool

    /// Преобразовать в формат для отправки Claude
    func toMessageContent() -> [String: Any] {
        return [
            "type": "tool_result",
            "tool_use_id": tool_use_id,
            "content": content,
            "is_error": is_error
        ]
    }
}
