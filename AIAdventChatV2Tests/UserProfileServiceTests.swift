import XCTest
import Combine
@testable import AIAdventChatV2

final class UserProfileServiceTests: XCTestCase {
    
    var sut: UserProfileService!
    var tempDirectoryURL: URL!
    var fileURL: URL!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        // Create a temporary directory for test files
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        fileURL = tempDirectoryURL.appendingPathComponent("user_profile.json")
        
        // Create service with auto-save disabled for more controlled testing
        sut = UserProfileService(autoSaveEnabled: false)
        
        // Replace the file URL with our test URL using reflection
        let mirror = Mirror(reflecting: sut)
        if let fileURLProperty = mirror.children.first(where: { $0.label == "fileURL" }) {
            let fileURLPointer = withUnsafePointer(to: &sut.self) { $0 }
                .withMemoryRebound(to: UserProfileService.self, capacity: 1) { $0 }
            let offset = MemoryLayout<UserProfileService>.offset(of: fileURLPointer)!
            let valuePointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: fileURLPointer) + UInt(offset))!
                .assumingMemoryBound(to: URL.self)
            valuePointer.pointee = fileURL
        }
    }
    
    override func tearDown() {
        cancellables.removeAll()
        sut = nil
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(sut.isLoaded)
        XCTAssertEqual(sut.profile.name, "")
        XCTAssertTrue(sut.profile.skills.isEmpty)
        XCTAssertTrue(sut.profile.interests.isEmpty)
        XCTAssertNil(sut.lastSaved)
    }
    
    func testSaveAndLoad() {
        // Given
        sut.profile.name = "Test User"
        sut.profile.role = "Developer"
        
        // When
        sut.save()
        
        // Then
        XCTAssertNotNil(sut.lastSaved)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Create a new instance to test loading
        let newService = UserProfileService(autoSaveEnabled: false)
        
        // Replace the file URL with our test URL using reflection
        let mirror = Mirror(reflecting: newService)
        if let fileURLProperty = mirror.children.first(where: { $0.label == "fileURL" }) {
            let fileURLPointer = withUnsafePointer(to: &newService.self) { $0 }
                .withMemoryRebound(to: UserProfileService.self, capacity: 1) { $0 }
            let offset = MemoryLayout<UserProfileService>.offset(of: fileURLPointer)!
            let valuePointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: fileURLPointer) + UInt(offset))!
                .assumingMemoryBound(to: URL.self)
            valuePointer.pointee = fileURL
        }
        
        // Then
        XCTAssertEqual(newService.profile.name, "Test User")
        XCTAssertEqual(newService.profile.role, "Developer")
    }
    
    func testReset() {
        // Given
        sut.profile.name = "Test User"
        sut.profile.role = "Developer"
        
        // When
        sut.reset()
        
        // Then
        XCTAssertEqual(sut.profile.name, "")
        XCTAssertEqual(sut.profile.role, "")
    }
    
    func testLoadExample() {
        // When
        sut.loadExample()
        
        // Then
        XCTAssertEqual(sut.profile.name, UserProfile.example.name)
        XCTAssertEqual(sut.profile.role, UserProfile.example.role)
    }
    
    func testUpdateName() {
        // When
        sut.updateName("John Doe")
        
        // Then
        XCTAssertEqual(sut.profile.name, "John Doe")
    }
    
    func testUpdateRole() {
        // When
        sut.updateRole("Designer")
        
        // Then
        XCTAssertEqual(sut.profile.role, "Designer")
    }
    
    func testAddAndRemoveSkill() {
        // Given
        XCTAssertTrue(sut.profile.skills.isEmpty)
        
        // When - add
        sut.addSkill("Swift")
        
        // Then
        XCTAssertEqual(sut.profile.skills.count, 1)
        XCTAssertEqual(sut.profile.skills.first, "Swift")
        
        // When - add duplicate
        sut.addSkill("Swift")
        
        // Then - should not add duplicate
        XCTAssertEqual(sut.profile.skills.count, 1)
        
        // When - add empty
        sut.addSkill("")
        
        // Then - should not add empty
        XCTAssertEqual(sut.profile.skills.count, 1)
        
        // When - remove
        sut.removeSkill("Swift")
        
        // Then
        XCTAssertTrue(sut.profile.skills.isEmpty)
        
        // When - remove non-existent
        sut.removeSkill("Python")
        
        // Then - should not change
        XCTAssertTrue(sut.profile.skills.isEmpty)
    }
    
    func testAddAndRemoveInterest() {
        // Given
        XCTAssertTrue(sut.profile.interests.isEmpty)
        
        // When - add
        sut.addInterest("AI")
        
        // Then
        XCTAssertEqual(sut.profile.interests.count, 1)
        XCTAssertEqual(sut.profile.interests.first, "AI")
        
        // When - add duplicate
        sut.addInterest("AI")
        
        // Then - should not add duplicate
        XCTAssertEqual(sut.profile.interests.count, 1)
        
        // When - remove
        sut.removeInterest("AI")
        
        // Then
        XCTAssertTrue(sut.profile.interests.isEmpty)
    }
    
    func testAddAndRemoveGoal() {
        // Given
        XCTAssertTrue(sut.profile.goals.isEmpty)
        
        // When - add
        sut.addGoal("Learn Swift")
        
        // Then
        XCTAssertEqual(sut.profile.goals.count, 1)
        XCTAssertEqual(sut.profile.goals.first, "Learn Swift")
        
        // When - remove
        sut.removeGoal("Learn Swift")
        
        // Then
        XCTAssertTrue(sut.profile.goals.isEmpty)
    }
    
    func testAddAndRemoveConstraint() {
        // Given
        XCTAssertTrue(sut.profile.constraints.isEmpty)
        
        // When - add
        sut.addConstraint("Time limited")
        
        // Then
        XCTAssertEqual(sut.profile.constraints.count, 1)
        XCTAssertEqual(sut.profile.constraints.first, "Time limited")
        
        // When - remove
        sut.removeConstraint("Time limited")
        
        // Then
        XCTAssertTrue(sut.profile.constraints.isEmpty)
    }
    
    func testAddAndRemoveProject() {
        // Given
        XCTAssertTrue(sut.profile.currentProjects.isEmpty)
        
        // When - add
        sut.addProject("iOS App")
        
        // Then
        XCTAssertEqual(sut.profile.currentProjects.count, 1)
        XCTAssertEqual(sut.profile.currentProjects.first, "iOS App")
        
        // When - remove
        sut.removeProject("iOS App")
        
        // Then
        XCTAssertTrue(sut.profile.currentProjects.isEmpty)
    }
    
    func testAddAndRemoveCommonTask() {
        // Given
        XCTAssertTrue(sut.profile.commonTasks.isEmpty)
        
        // When - add
        sut.addCommonTask("Write code")
        
        // Then
        XCTAssertEqual(sut.profile.commonTasks.count, 1)
        XCTAssertEqual(sut.profile.commonTasks.first, "Write code")
        
        // When - remove
        sut.removeCommonTask("Write code")
        
        // Then
        XCTAssertTrue(sut.profile.commonTasks.isEmpty)
    }
    
    func testExportToJSON() {
        // Given
        sut.profile.name = "Test User"
        sut.profile.role = "Developer"
        
        // When
        let json = sut.exportToJSON()
        
        // Then
        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("Test User"))
        XCTAssertTrue(json!.contains("Developer"))
    }
    
    func testImportFromJSON() {
        // Given
        let json = """
        {
            "name": "Imported User",
            "role": "Tester",
            "occupation": "QA Engineer",
            "skills": ["Testing", "Automation"],
            "interests": ["Quality"],
            "preferredLanguage": "en",
            "style": "professional",
            "workingHours": "9-5",
            "goals": [],
            "constraints": [],
            "currentProjects": [],
            "commonTasks": []
        }
        """
        
        // When
        let result = sut.importFromJSON(json)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.profile.name, "Imported User")
        XCTAssertEqual(sut.profile.role, "Tester")
        XCTAssertEqual(sut.profile.skills, ["Testing", "Automation"])
    }
    
    func testImportFromInvalidJSON() {
        // Given
        let invalidJSON = "{ invalid json }"
        
        // When
        let result = sut.importFromJSON(invalidJSON)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testGetStatistics() {
        // Given - empty profile
        var stats = sut.getStatistics()
        
        // Then
        XCTAssertEqual(stats.totalFields, 12)
        XCTAssertEqual(stats.filledFields, 1) // style always has default value
        XCTAssertEqual(stats.completionPercentage, 100.0 / 12.0, accuracy: 0.01)
        XCTAssertFalse(stats.isWellConfigured)
        
        // Given - more complete profile
        sut.updateName("Test User")
        sut.updateRole("Developer")
        sut.addSkill("Swift")
        sut.addInterest("AI")
        sut.addGoal("Learn")
        sut.addConstraint("Time")
        sut.addProject("App")
        
        // When
        stats = sut.getStatistics()
        
        // Then
        XCTAssertEqual(stats.filledFields, 8)
        XCTAssertGreaterThan(stats.completionPercentage, 50.0)
        XCTAssertTrue(stats.isWellConfigured)
    }
}