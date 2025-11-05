import XCTest
@testable import AIAdventChatV2

final class MessageTests: XCTestCase {

    var testDate: Date!
    
    override func setUp() {
        super.setUp()
        testDate = Date()
    }
    
    override func tearDown() {
        testDate = nil
        super.tearDown()
    }
    
    func testRAGSourceInitialization() {
        let source = RAGSource(fileName: "test.txt", similarity: 0.87, chunkContent: "Sample chunk")
        
        XCTAssertEqual(source.fileName, "test.txt")
        XCTAssertEqual(source.similarity, 0.87)
        XCTAssertEqual(source.chunkContent, "Sample chunk")
        XCTAssertNotNil(source.id)
    }
    
    func testMessageContentCoding() throws {
        let original = MessageContent(response: "Test response", confidence: "0.95", additional_info: "Extra info")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MessageContent.self, from: data)
        
        XCTAssertEqual(decoded.response, original.response)
        XCTAssertEqual(decoded.confidence, original.confidence)
        XCTAssertEqual(decoded.additional_info, original.additional_info)
    }
    
    func testMessageConvenienceInitializer() {
        // Basic user message
        let userMessage = Message(content: "Hello", isFromUser: true)
        
        XCTAssertEqual(userMessage.content, "Hello")
        XCTAssertTrue(userMessage.isFromUser)
        XCTAssertNil(userMessage.parsedContent)
        XCTAssertNil(userMessage.temperature)
        XCTAssertNil(userMessage.responseTime)
        XCTAssertFalse(userMessage.isSystemMessage)
        
        // AI message with metrics
        let metrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?, modelName: String?) = 
            (2.5, 10, 50, 0.001, "gpt-4")
        
        let aiMessage = Message(
            content: "AI response",
            isFromUser: false,
            temperature: 0.7,
            metrics: metrics
        )
        
        XCTAssertEqual(aiMessage.content, "AI response")
        XCTAssertFalse(aiMessage.isFromUser)
        XCTAssertEqual(aiMessage.temperature, 0.7)
        XCTAssertEqual(aiMessage.responseTime, 2.5)
        XCTAssertEqual(aiMessage.inputTokens, 10)
        XCTAssertEqual(aiMessage.outputTokens, 50)
        XCTAssertEqual(aiMessage.cost, 0.001)
        XCTAssertEqual(aiMessage.modelName, "gpt-4")
    }
    
    func testMessageFullInitializer() {
        let uuid = UUID()
        let parsedContent = MessageContent(response: "Parsed response", confidence: "0.8", additional_info: nil)
        let ragSource = RAGSource(fileName: "doc.pdf", similarity: 0.92, chunkContent: "Document content")
        
        let message = Message(
            id: uuid,
            content: "Original content",
            isFromUser: false,
            timestamp: testDate,
            parsedContent: parsedContent,
            temperature: 0.5,
            responseTime: 1.2,
            inputTokens: 15,
            outputTokens: 75,
            cost: 0.0015,
            modelName: "gpt-3.5",
            isSystemMessage: true,
            usedRAG: true,
            ragSources: [ragSource],
            citationCount: 3
        )
        
        XCTAssertEqual(message.id, uuid)
        XCTAssertEqual(message.content, "Original content")
        XCTAssertFalse(message.isFromUser)
        XCTAssertEqual(message.timestamp, testDate)
        XCTAssertEqual(message.parsedContent?.response, "Parsed response")
        XCTAssertEqual(message.temperature, 0.5)
        XCTAssertEqual(message.responseTime, 1.2)
        XCTAssertEqual(message.inputTokens, 15)
        XCTAssertEqual(message.outputTokens, 75)
        XCTAssertEqual(message.cost, 0.0015)
        XCTAssertEqual(message.modelName, "gpt-3.5")
        XCTAssertTrue(message.isSystemMessage)
        XCTAssertTrue(message.usedRAG)
        XCTAssertEqual(message.ragSources?.count, 1)
        XCTAssertEqual(message.ragSources?[0].fileName, "doc.pdf")
        XCTAssertEqual(message.citationCount, 3)
    }
    
    func testParseJSONSuccess() {
        let jsonString = """
        {
            "response": "This is a response",
            "confidence": "0.9",
            "additional_info": "Some extra details"
        }
        """
        
        let message = Message(content: jsonString, isFromUser: false)
        
        XCTAssertNotNil(message.parsedContent)
        XCTAssertEqual(message.parsedContent?.response, "This is a response")
        XCTAssertEqual(message.parsedContent?.confidence, "0.9")
        XCTAssertEqual(message.parsedContent?.additional_info, "Some extra details")
    }
    
    func testParseJSONWithSurroundingText() {
        let mixedContent = """
        Some text before the JSON
        {
            "response": "Parsed response",
            "confidence": "0.85",
            "additional_info": null
        }
        Some text after the JSON
        """
        
        let message = Message(content: mixedContent, isFromUser: false)
        
        XCTAssertNotNil(message.parsedContent)
        XCTAssertEqual(message.parsedContent?.response, "Parsed response")
        XCTAssertEqual(message.parsedContent?.confidence, "0.85")
        XCTAssertNil(message.parsedContent?.additional_info)
    }
    
    func testParseJSONFailure() {
        let invalidJSON = "This is not a JSON at all"
        
        let message = Message(content: invalidJSON, isFromUser: false)
        
        XCTAssertNil(message.parsedContent)
    }
    
    func testDisplayText() {
        // Message with parsed content
        let parsedContent = MessageContent(response: "Parsed response", confidence: nil, additional_info: nil)
        let messageWithParsed = Message(
            id: UUID(),
            content: "Original content",
            isFromUser: false,
            timestamp: Date(),
            parsedContent: parsedContent
        )
        
        XCTAssertEqual(messageWithParsed.displayText, "Parsed response")
        
        // Message without parsed content
        let regularMessage = Message(content: "Regular content", isFromUser: true)
        
        XCTAssertEqual(regularMessage.displayText, "Regular content")
    }
    
    func testUserMessageDoesNotAttemptParsing() {
        let jsonString = """
        {
            "response": "This is a response",
            "confidence": "0.9",
            "additional_info": "Some extra details"
        }
        """
        
        let userMessage = Message(content: jsonString, isFromUser: true)
        
        XCTAssertNil(userMessage.parsedContent)
    }
    
    func testEmptyMessageHandling() {
        let emptyMessage = Message(content: "", isFromUser: false)
        
        XCTAssertEqual(emptyMessage.content, "")
        XCTAssertNil(emptyMessage.parsedContent)
        XCTAssertEqual(emptyMessage.displayText, "")
    }
}