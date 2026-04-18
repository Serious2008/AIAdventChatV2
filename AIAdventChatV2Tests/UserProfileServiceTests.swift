//
//  UserProfileServiceTests.swift
//  AIAdventChatV2Tests
//

import XCTest
import Combine
@testable import AIAdventChatV2

final class UserProfileServiceTests: XCTestCase {

    var sut: UserProfileService!
    var tempDir: URL!
    var fileURL: URL!
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("test_profile.json")
        sut = UserProfileService(fileURL: fileURL, autoSaveEnabled: false)
    }

    override func tearDown() {
        cancellables.removeAll()
        sut = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertTrue(sut.isLoaded)
        XCTAssertEqual(sut.profile.name, "")
        XCTAssertTrue(sut.profile.skills.isEmpty)
        XCTAssertTrue(sut.profile.interests.isEmpty)
        XCTAssertNil(sut.lastSaved)
    }

    // MARK: - Save / Load

    func testSaveCreatesFile() {
        sut.profile.name = "Test User"
        sut.save()

        XCTAssertNotNil(sut.lastSaved)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSaveAndLoadRoundTrip() {
        sut.profile.name = "Test User"
        sut.profile.role = "Developer"
        sut.save()

        let loaded = UserProfileService(fileURL: fileURL, autoSaveEnabled: false)
        XCTAssertEqual(loaded.profile.name, "Test User")
        XCTAssertEqual(loaded.profile.role, "Developer")
    }

    // MARK: - Reset / LoadExample

    func testReset() {
        sut.profile.name = "Test User"
        sut.profile.role = "Developer"

        sut.reset()

        XCTAssertEqual(sut.profile.name, "")
        XCTAssertEqual(sut.profile.role, "")
    }

    func testLoadExample() {
        sut.loadExample()

        XCTAssertEqual(sut.profile.name, UserProfile.example.name)
        XCTAssertEqual(sut.profile.role, UserProfile.example.role)
        XCTAssertEqual(sut.profile.skills, UserProfile.example.skills)
    }

    // MARK: - CRUD Methods

    func testUpdateName() {
        sut.updateName("John Doe")
        XCTAssertEqual(sut.profile.name, "John Doe")
    }

    func testUpdateRole() {
        sut.updateRole("Designer")
        XCTAssertEqual(sut.profile.role, "Designer")
    }

    func testAddSkillIgnoresDuplicate() {
        sut.addSkill("Swift")
        sut.addSkill("Swift")
        XCTAssertEqual(sut.profile.skills.count, 1)
    }

    func testAddSkillIgnoresEmpty() {
        sut.addSkill("")
        XCTAssertTrue(sut.profile.skills.isEmpty)
    }

    func testRemoveSkill() {
        sut.addSkill("Swift")
        sut.removeSkill("Swift")
        XCTAssertTrue(sut.profile.skills.isEmpty)
    }

    func testRemoveNonExistentSkillIsNoOp() {
        sut.removeSkill("Python")
        XCTAssertTrue(sut.profile.skills.isEmpty)
    }

    func testAddAndRemoveInterest() {
        sut.addInterest("AI")
        XCTAssertEqual(sut.profile.interests.count, 1)
        sut.addInterest("AI")
        XCTAssertEqual(sut.profile.interests.count, 1)
        sut.removeInterest("AI")
        XCTAssertTrue(sut.profile.interests.isEmpty)
    }

    func testAddAndRemoveGoal() {
        sut.addGoal("Learn Swift")
        XCTAssertEqual(sut.profile.goals.count, 1)
        sut.removeGoal("Learn Swift")
        XCTAssertTrue(sut.profile.goals.isEmpty)
    }

    func testAddAndRemoveConstraint() {
        sut.addConstraint("Time limited")
        XCTAssertEqual(sut.profile.constraints.count, 1)
        sut.removeConstraint("Time limited")
        XCTAssertTrue(sut.profile.constraints.isEmpty)
    }

    func testAddAndRemoveProject() {
        sut.addProject("iOS App")
        XCTAssertEqual(sut.profile.currentProjects.count, 1)
        sut.removeProject("iOS App")
        XCTAssertTrue(sut.profile.currentProjects.isEmpty)
    }

    func testAddAndRemoveCommonTask() {
        sut.addCommonTask("Write code")
        XCTAssertEqual(sut.profile.commonTasks.count, 1)
        sut.removeCommonTask("Write code")
        XCTAssertTrue(sut.profile.commonTasks.isEmpty)
    }

    // MARK: - Export / Import JSON

    func testExportToJSON() {
        sut.profile.name = "Test User"
        sut.profile.role = "Developer"

        let json = sut.exportToJSON()

        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("Test User"))
        XCTAssertTrue(json!.contains("Developer"))
    }

    func testImportFromValidJSON() {
        sut.updateName("Original")

        let json = """
        {
            "name": "Imported User",
            "role": "Tester",
            "occupation": "QA Engineer",
            "skills": ["Testing", "Automation"],
            "interests": ["Quality"],
            "preferredLanguage": "en",
            "communicationStyle": "Сбалансированный",
            "workingHours": "9-5",
            "goals": [],
            "constraints": [],
            "currentProjects": [],
            "commonTasks": []
        }
        """

        let result = sut.importFromJSON(json)

        XCTAssertTrue(result)
        XCTAssertEqual(sut.profile.name, "Imported User")
        XCTAssertEqual(sut.profile.role, "Tester")
        XCTAssertEqual(sut.profile.skills, ["Testing", "Automation"])
    }

    func testImportFromInvalidJSON() {
        let result = sut.importFromJSON("{ invalid json }")
        XCTAssertFalse(result)
    }

    // MARK: - Statistics

    func testStatisticsEmptyProfile() {
        let stats = sut.getStatistics()
        XCTAssertEqual(stats.totalFields, 12)
        XCTAssertFalse(stats.isWellConfigured)
        XCTAssertNil(stats.lastModified)
    }

    func testStatisticsWellConfigured() {
        sut.updateName("Test")
        sut.updateRole("Dev")
        sut.addSkill("Swift")
        sut.addInterest("AI")
        sut.addGoal("Learn")
        sut.addConstraint("Time")
        sut.addProject("App")

        let stats = sut.getStatistics()
        XCTAssertGreaterThan(stats.completionPercentage, 50.0)
        XCTAssertTrue(stats.isWellConfigured)
    }

    func testStatisticsCompletionText() {
        let stats = sut.getStatistics()
        XCTAssertTrue(stats.completionText.hasSuffix("%"))
    }
}
