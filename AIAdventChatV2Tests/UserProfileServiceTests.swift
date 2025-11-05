```swift
import XCTest
@testable import AIAdventChatV2

final class UserProfileServiceTests: XCTestCase {
    
    private var sut: UserProfileService!
    private var testFileURL: URL!
    private var testDirectoryURL: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create a temporary directory for test files
        testDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("AIAdventChatV2Tests", isDirectory: true)
        testFileURL = testDirectoryURL.appendingPathComponent("user_profile_test.json")
        
        // Clean up any existing test files
        try? FileManager.default.removeItem(at: testDirectoryURL)
        try? FileManager.default.createDirectory(at: testDirectoryURL, withIntermediateDirectories: true)
        
        // Create a subclass for testing that uses our test file URL
        sut = TestUserProfileService(testFileURL: testFileURL, autoSaveEnabled: false)
    }
    
    override func tearDown() {
        // Clean up test files
        try? FileManager.default.removeItem(at: testDirectoryURL)
        sut = nil
        
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func test_init_whenFileDoesNotExist_shouldCreateEmptyProfile() {
        // Given file doesn't exist (handled in setUp)
        
        // Then
        XCTAssertTrue(sut.isLoaded)
        XCTAssertEqual(sut.profile.name, "")
        XCTAssertTrue(sut.profile.skills.isEmpty)
        XCTAssertTrue(sut.profile.interests.isEmpty)
    }
    
    func test_init_whenFileExists_shouldLoadProfile() throws {
        // Given
        let profile = UserProfile.example
        let data = try JSONEncoder().encode(profile)
        try data.write(to: testFileURL)
        
        // When
        let service = TestUserProfileService(testFileURL: testFileURL, autoSaveEnabled: false)
        
        // Then
        XCTAssertTrue(service.isLoaded)
        XCTAssertEqual(service.profile.name, profile.name)
        XCTAssertEqual(service.profile.skills, profile.skills)
    }
    
    // MARK: - Save Tests
    
    func test_save_shouldWriteProfileToFile() throws {
        // Given
        sut.profile = UserProfile.example
        
        // When
        sut.save()
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path))
        
        // Verify content
        let savedData = try Data(contentsOf: testFileURL)
        let savedProfile = try JSONDecoder().decode(UserProfile.self, from: savedData)
        XCTAssertEqual(savedProfile.name, UserProfile.example.name)
        XCTAssertEqual(savedProfile.skills, UserProfile.example.skills)
        XCTAssertNotNil(sut.lastSaved)
    }
    
    // MARK: - Reset Tests
    
    func test_reset_shouldResetProfileToEmpty() {
        // Given
        sut.profile = UserProfile.example
        
        // When
        sut.reset()
        
        // Then
        XCTAssertEqual(sut.profile.name, "")
        XCTAssertTrue(sut.profile.skills.isEmpty)
        XCTAssertTrue(sut.profile.interests.isEmpty)
    }
    
    func test_loadExample_shouldLoadExampleProfile() {
        // Given
        sut.profile = UserProfile.empty
        
        // When
        sut.loadExample()
        
        // Then
        XCTAssertEqual(sut.profile.name, UserProfile.example.name)
        XCTAssertEqual(sut.profile.skills, UserProfile.example.skills)
        XCTAssertEqual(sut.profile.interests, UserProfile.example.interests)
    }
    
    // MARK: - Profile Management Tests
    
    func test_updateName_shouldUpdateProfileName() {
        // Given
        let newName = "John Doe"
        
        // When
        sut.updateName(newName)
        
        // Then
        XCTAssertEqual(sut.profile.name, newName)
    }
    
    func test_updateRole_shouldUpdateProfileRole() {
        // Given
        let newRole = "Developer"
        
        // When
        sut.updateRole(newRole)
        
        // Then
        XCTAssertEqual(sut.profile.role, newRole)
    }
    
    func test_addSkill_whenSkillIsValid_shouldAddSkill() {
        // Given
        let skill = "Swift"
        
        // When
        sut.addSkill(skill)
        
        // Then
        XCTAssertTrue(sut.profile.skills.contains(skill))
    }
    
    func test_addSkill_whenSkillIsEmpty_shouldNotAddSkill() {
        // Given
        let emptySkill = ""
        let initialSkillCount = sut.profile.skills.count
        
        // When
        sut.addSkill(emptySkill)
        
        // Then
        XCTAssertEqual(sut.profile.skills.count, initialSkillCount)
    }
    
    func test_addSkill_whenSkillAlreadyExists_shouldNotAddDuplicate() {
        // Given
        let skill = "Swift"
        sut.addSkill(skill)
        let initialSkillCount = sut.profile.skills.count
        
        // When
        sut.addSkill(skill)
        
        // Then
        XCTAssertEqual(sut.profile.skills.count, initialSkillCount)
    }
    
    func test_removeSkill_whenSkillExists_shouldRemoveSkill() {
        // Given
        let skill = "Swift"
        sut.addSkill(skill)
        
        // When
        sut.removeSkill(skill)
        
        // Then
        XCTAssertFalse(sut.profile.skills.contains(skill))
    }
    
    func test_removeSkill_whenSkillDoesNotExist_shouldNotChangeSkills() {
        // Given
        sut.addSkill("Swift")
        let initialSkillCount = sut.profile.skills.count
        
        // When
        sut.removeSkill("Java")
        
        // Then
        XCTAssertEqual(sut.profile.skills.count, initialSkillCount)
    }
    
    func test_addInterest_whenInterestIsValid_shouldAddInterest() {
        // Given
        let interest = "Machine Learning"
        
        // When
        sut.addInterest(interest)
        
        // Then
        XCTAssertTrue(sut.profile.interests.contains(interest))
    }
    
    func test_addInterest_whenInterestIsEmpty_shouldNotAddInterest() {
        // Given
        let emptyInterest = ""
        let initialCount = sut.profile.interests.count
        
        // When
        sut.addInterest(emptyInterest)
        
        // Then
        XCTAssertEqual(sut.profile.interests.count, initialCount)
    }
    
    func test_addInterest_whenInterestAlreadyExists_shouldNotAddDuplicate() {
        // Given
        let interest = "Machine Learning"
        sut.addInterest(interest)
        let initialCount = sut.profile.interests.count
        
        // When
        sut.addInterest(interest)
        
        // Then
        XCTAssertEqual(sut.profile.interests.count, initialCount)
    }
    
    func test_removeInterest_whenInterestExists_shouldRemoveInterest() {
        // Given
        let interest = "Machine Learning"
        sut.addInterest(interest)
        
        // When
        sut.removeInterest(interest)
        
        // Then
        XCTAssertFalse(sut.profile.interests.contains(interest))
    }
    
    func test_removeInterest_whenInterestDoesNotExist_shouldNotChangeInterests() {
        // Given
        sut.addInterest("Machine Learning")
        let initialCount = sut.profile.interests.count
        
        // When
        sut.removeInterest("Cooking")
        
        // Then
        XCTAssertEqual(sut.profile.interests.count, initialCount)
    }
    
    func test_addGoal_whenGoalIsValid_shouldAddGoal() {
        // Given
        let goal = "Learn SwiftUI"
        
        // When
        sut.addGoal(goal)
        
        // Then
        XCTAssertTrue(sut.profile.goals.contains(goal))
    }
    
    func test_addGoal_whenGoalIsEmpty_shouldNotAddGoal() {
        // Given
        let emptyGoal = ""
        let initialCount = sut.profile.goals.count
        
        // When
        sut.addGoal(emptyGoal)
        
        // Then
        XCTAssertEqual(sut.profile.goals.count, initialCount)
    }
    
    func test_addGoal_whenGoalAlreadyExists_shouldNotAddDuplicate() {
        // Given
        let goal = "Learn SwiftUI"
        sut.addGoal(goal)
        let initialCount = sut.profile.goals.count
        
        // When
        sut.addGoal(goal)
        
        // Then
        XCTAssertEqual(sut.profile.goals.count, initialCount)
    }
    
    func test_removeGoal_whenGoalExists_shouldRemoveGoal() {
        // Given
        let goal = "Learn SwiftUI"
        sut.addGoal(goal)
        
        // When
        sut.removeGoal(goal)
        
        // Then
        XCTAssertFalse(sut.profile.goals.contains(goal))
    }
    
    func test_removeGoal_whenGoalDoesNotExist_shouldNotChangeGoals() {
        // Given
        sut.addGoal("Learn SwiftUI")
        let initialCount = sut.profile.goals.count
        
        // When
        sut.removeGoal("Learn UIKit")
        
        // Then
        XCTAssertEqual(sut.profile.goals.count, initialCount)
    }
    
    func test_addConstraint_whenConstraintIsValid_shouldAddConstraint() {
        // Given
        let constraint = "Limited time"
        
        // When
        sut.addConstraint(constraint)
        
        // Then
        XCTAssertTrue(sut.profile.constraints.contains(constraint))
    }
    
    func test_addConstraint_whenConstraintIsEmpty_shouldNotAddConstraint() {
        // Given
        let emptyConstraint = ""
        let initialCount = sut.profile.constraints.count
        
        // When
        sut.addConstraint(emptyConstraint)
        
        // Then
        XCTAssertEqual(sut.profile.constraints.count, initialCount)
    }
    
    func test_addConstraint_whenConstraintAlreadyExists_shouldNotAddDuplicate() {
        // Given
        let constraint = "Limited time"
        sut.addConstraint(constraint)
        let initialCount = sut.profile.constraints.count
        
        // When
        sut.addConstraint(constraint)
        
        // Then
        XCTAssertEqual(sut.profile.constraints.count, initialCount)
    }
    
    func test_removeConstraint_whenConstraintExists_shouldRemoveConstraint() {
        // Given
        let constraint = "Limited time"
        sut.addConstraint(constraint)
        
        // When
        sut.removeConstraint(constraint)
        
        // Then
        XCTAssertFalse(sut.profile.constraints.contains(constraint))
    }
    
    func test_removeConstraint_whenConstraintDoesNotExist_shouldNotChangeConstraints() {
        // Given
        sut.addConstraint("Limited time")
        let initialCount = sut.profile.constraints.count
        
        // When
        sut.removeConstraint("No budget")
        
        // Then
        XCTAssertEqual(sut.profile.constraints.count, initialCount)
    }
    
    func test_addProject_whenProjectIsValid_shouldAddProject() {
        // Given
        let project = "iOS App"
        
        // When
        sut.addProject(project)
        
        // Then
        XCTAssertTrue(sut.profile.currentProjects.contains(project))
    }
    
    func test_addProject_whenProjectIsEmpty_shouldNotAddProject() {
        // Given
        let emptyProject = ""
        let initialCount = sut.profile.currentProjects.count
        
        // When
        sut.addProject(emptyProject)
        
        // Then
        XCTAssertEqual(sut.profile.currentProjects.count, initialCount)
    }
    
    func test_addProject_whenProjectAlreadyExists_shouldNotAddDuplicate() {
        // Given
        let project = "iOS App"
        sut.addProject(project)
        let initialCount = sut.profile.currentProjects.count
        
        // When
        sut.addProject(project)
        
        // Then
        XCTAssertEqual(sut.profile.currentProjects.count, initialCount)
    }
    
    func test_removeProject_whenProjectExists_shouldRemoveProject() {
        // Given
        let project = "iOS App"
        sut.addProject(project)
        
        // When
        sut.removeProject(project)
        
        // Then
        XCTAssertFalse(sut.profile.currentProjects.contains(project))
    }
    
    func test_removeProject_whenProjectDoesNotExist_shouldNotChangeProjects() {
        // Given
        sut.addProject("iOS App")
        let initialCount = sut.profile.currentProjects.count
        
        // When
        sut.removeProject("Android App")
        
        // Then
        XCTAssertEqual(sut.profile.currentProjects.count, initialCount)
    }
    
    func test_addCommonTask_whenTaskIsValid_shouldAddTask() {
        // Given
        let task = "Code review"
        
        // When
        sut.addCommonTask(task)
        
        // Then
        XCTAssertTrue(sut.profile.commonTasks.contains(task))
    }
    
    func test_addCommonTask_whenTaskIsEmpty_shouldNotAddTask() {
        // Given
        let emptyTask = ""
        let initialCount = sut.profile.commonTasks.count
        
        // When
        sut.addCommonTask(emptyTask)
        
        // Then
        XCTAssertEqual(sut.profile.commonTasks.count, initialCount)
    }
    
    func test_addCommonTask_whenTaskAlreadyExists_shouldNotAddDuplicate() {
        // Given
        let task = "Code review"
        sut.addCommonTask(task)
        let initialCount = sut.profile.commonTasks.count
        
        // When
        sut.addCommonTask(task)
        
        // Then
        XCTAssertEqual(sut.profile.commonTasks.count, initialCount)
    }
    
    func test_removeCommonTask_whenTaskExists_shoul