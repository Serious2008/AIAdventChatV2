import XCTest
@testable import AIAdventChatV2

final class UserProfileTests: XCTestCase {
    
    var profile: UserProfile!
    
    override func setUp() {
        super.setUp()
        profile = UserProfile()
    }
    
    override func tearDown() {
        profile = nil
        super.tearDown()
    }
    
    func testEmptyProfile() {
        XCTAssertEqual(profile, UserProfile.empty)
        XCTAssertFalse(profile.isConfigured)
        XCTAssertEqual(profile.toSystemPrompt(), "")
    }
    
    func testExampleProfile() {
        let example = UserProfile.example
        XCTAssertTrue(example.isConfigured)
        XCTAssertEqual(example.name, "Сергей")
        XCTAssertEqual(example.role, "iOS разработчик")
        XCTAssertEqual(example.occupation, "Senior iOS Developer")
        XCTAssertEqual(example.skills, ["Swift", "SwiftUI", "Python", "Machine Learning"])
        XCTAssertEqual(example.currentProjects, ["AIAdventChatV2"])
        XCTAssertEqual(example.interests, ["AI", "Machine Learning", "iOS разработка", "RAG"])
        XCTAssertEqual(example.communicationStyle, .balanced)
        XCTAssertEqual(example.workingHours, "10:00-19:00 MSK")
        XCTAssertEqual(example.preferredLanguage, "Русский")
        XCTAssertEqual(example.goals.count, 3)
        XCTAssertEqual(example.constraints.count, 2)
        XCTAssertEqual(example.commonTasks.count, 4)
    }
    
    func testIsConfigured() {
        // Empty profile
        XCTAssertFalse(profile.isConfigured)
        
        // Only name
        profile.name = "Имя"
        XCTAssertTrue(profile.isConfigured)
        
        profile = UserProfile() // Reset
        
        // Only role
        profile.role = "Разработчик"
        XCTAssertTrue(profile.isConfigured)
        
        profile = UserProfile() // Reset
        
        // Only skills
        profile.skills = ["Swift"]
        XCTAssertTrue(profile.isConfigured)
        
        profile = UserProfile() // Reset
        
        // Only interests
        profile.interests = ["Программирование"]
        XCTAssertTrue(profile.isConfigured)
    }
    
    func testCommunicationStyleDescription() {
        XCTAssertEqual(UserProfile.CommunicationStyle.concise.description, "Краткие технические ответы без лишних деталей")
        XCTAssertEqual(UserProfile.CommunicationStyle.balanced.description, "Оптимальный баланс между теорией и практикой")
        XCTAssertEqual(UserProfile.CommunicationStyle.detailed.description, "Подробные объяснения с примерами кода и пояснениями")
    }
    
    func testCommunicationStyleRawValues() {
        XCTAssertEqual(UserProfile.CommunicationStyle.concise.rawValue, "Краткий и технический")
        XCTAssertEqual(UserProfile.CommunicationStyle.balanced.rawValue, "Сбалансированный")
        XCTAssertEqual(UserProfile.CommunicationStyle.detailed.rawValue, "Подробный с примерами")
    }
    
    func testSystemPromptGeneration() {
        // Minimal profile
        profile.name = "Иван"
        let prompt = profile.toSystemPrompt()
        XCTAssertTrue(prompt.contains("**Имя:** Иван"))
        XCTAssertTrue(prompt.contains("Обращайся к пользователю по имени (Иван)"))
        
        // More complete profile
        profile.skills = ["Swift", "SwiftUI"]
        profile.goals = ["Изучить SwiftUI"]
        profile.constraints = ["Ограничение времени"]
        
        let fullPrompt = profile.toSystemPrompt()
        XCTAssertTrue(fullPrompt.contains("**Навыки:** Swift, SwiftUI"))
        XCTAssertTrue(fullPrompt.contains("## 🎯 Текущие цели пользователя:"))
        XCTAssertTrue(fullPrompt.contains("- Изучить SwiftUI"))
        XCTAssertTrue(fullPrompt.contains("## ⚠️ Ограничения:"))
        XCTAssertTrue(fullPrompt.contains("- Ограничение времени"))
    }
    
    func testEquality() {
        let profile1 = UserProfile(name: "Имя", role: "Роль")
        let profile2 = UserProfile(name: "Имя", role: "Роль")
        let profile3 = UserProfile(name: "Другое имя", role: "Роль")
        
        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }
    
    func testEdgeCases() {
        // Profile with only optional sections
        profile.constraints = ["Ограничение"]
        profile.commonTasks = ["Задача"]
        
        let prompt = profile.toSystemPrompt()
        XCTAssertEqual(prompt, "")  // Should be empty if not configured
        
        // Profile with communication style but nothing else
        profile = UserProfile()
        profile.communicationStyle = .detailed
        XCTAssertFalse(profile.isConfigured)
        
        // Empty strings in arrays
        profile = UserProfile()
        profile.name = "Тест"
        profile.skills = ["", "  "]
        let skillPrompt = profile.toSystemPrompt()
        XCTAssertTrue(skillPrompt.contains("**Навыки:** ,  "))
    }
    
    func testAllCommunicationStyles() {
        for style in UserProfile.CommunicationStyle.allCases {
            profile.name = "Тест"
            profile.communicationStyle = style
            let prompt = profile.toSystemPrompt()
            XCTAssertTrue(prompt.contains("**Стиль общения:** \(style.rawValue)"))
            XCTAssertTrue(prompt.contains("→ \(style.description)"))
        }
    }
}