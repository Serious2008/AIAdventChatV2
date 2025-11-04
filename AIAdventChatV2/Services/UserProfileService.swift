//
//  UserProfileService.swift
//  AIAdventChatV2
//
//  Service for managing user profile and personalization
//

import Foundation
import Combine

// MARK: - User Profile Service

class UserProfileService: ObservableObject {

    // MARK: - Published Properties

    @Published var profile: UserProfile {
        didSet {
            autoSave()
        }
    }

    @Published var isLoaded: Bool = false
    @Published var lastSaved: Date?

    // MARK: - Private Properties

    private let fileURL: URL
    private let autoSaveEnabled: Bool
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(autoSaveEnabled: Bool = true) {
        self.autoSaveEnabled = autoSaveEnabled

        // Setup file path
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("AIAdventChatV2", isDirectory: true)
        self.fileURL = appDir.appendingPathComponent("user_profile.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        // Load existing profile or create new
        if let loadedProfile = Self.load(from: fileURL) {
            self.profile = loadedProfile
            self.isLoaded = true
            print("✅ User profile loaded from: \(fileURL.path)")
            print("   Name: \(loadedProfile.name.isEmpty ? "(empty)" : loadedProfile.name)")
            print("   Skills: \(loadedProfile.skills.count) items")
            print("   Interests: \(loadedProfile.interests.count) items")
        } else {
            self.profile = UserProfile.empty
            self.isLoaded = true
            print("📝 Created new empty user profile")
        }
    }

    // MARK: - Load

    private static func load(from url: URL) -> UserProfile? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            return profile
        } catch {
            print("❌ Failed to load profile: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Save

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(profile)

            // Ensure directory exists
            let directory = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            // Write to file
            try data.write(to: fileURL, options: .atomic)
            lastSaved = Date()

            print("✅ User profile saved to: \(fileURL.path)")
            print("   Size: \(data.count) bytes")
        } catch {
            print("❌ Failed to save profile: \(error.localizedDescription)")
        }
    }

    private func autoSave() {
        guard autoSaveEnabled else { return }

        // Debounce auto-save (wait 1 second after last change)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.save()
        }
    }

    // MARK: - Reset

    func reset() {
        print("🔄 Resetting user profile to empty")
        profile = UserProfile.empty
        save()
    }

    func loadExample() {
        print("📝 Loading example profile")
        profile = UserProfile.example
        save()
    }

    // MARK: - Profile Management

    func updateName(_ name: String) {
        profile.name = name
    }

    func updateRole(_ role: String) {
        profile.role = role
    }

    func addSkill(_ skill: String) {
        guard !skill.isEmpty, !profile.skills.contains(skill) else { return }
        profile.skills.append(skill)
    }

    func removeSkill(_ skill: String) {
        profile.skills.removeAll { $0 == skill }
    }

    func addInterest(_ interest: String) {
        guard !interest.isEmpty, !profile.interests.contains(interest) else { return }
        profile.interests.append(interest)
    }

    func removeInterest(_ interest: String) {
        profile.interests.removeAll { $0 == interest }
    }

    func addGoal(_ goal: String) {
        guard !goal.isEmpty, !profile.goals.contains(goal) else { return }
        profile.goals.append(goal)
    }

    func removeGoal(_ goal: String) {
        profile.goals.removeAll { $0 == goal }
    }

    func addConstraint(_ constraint: String) {
        guard !constraint.isEmpty, !profile.constraints.contains(constraint) else { return }
        profile.constraints.append(constraint)
    }

    func removeConstraint(_ constraint: String) {
        profile.constraints.removeAll { $0 == constraint }
    }

    func addProject(_ project: String) {
        guard !project.isEmpty, !profile.currentProjects.contains(project) else { return }
        profile.currentProjects.append(project)
    }

    func removeProject(_ project: String) {
        profile.currentProjects.removeAll { $0 == project }
    }

    func addCommonTask(_ task: String) {
        guard !task.isEmpty, !profile.commonTasks.contains(task) else { return }
        profile.commonTasks.append(task)
    }

    func removeCommonTask(_ task: String) {
        profile.commonTasks.removeAll { $0 == task }
    }

    // MARK: - Export/Import

    func exportToJSON() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(profile)
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Failed to export profile: \(error.localizedDescription)")
            return nil
        }
    }

    func importFromJSON(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8) else {
            print("❌ Invalid JSON string")
            return false
        }

        do {
            let importedProfile = try JSONDecoder().decode(UserProfile.self, from: data)
            profile = importedProfile
            save()
            print("✅ Profile imported successfully")
            return true
        } catch {
            print("❌ Failed to import profile: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Statistics

    func getStatistics() -> ProfileStatistics {
        ProfileStatistics(
            totalFields: calculateTotalFields(),
            filledFields: calculateFilledFields(),
            completionPercentage: calculateCompletionPercentage(),
            lastModified: lastSaved
        )
    }

    private func calculateTotalFields() -> Int {
        return 12 // name, role, occupation, skills, projects, interests, style, hours, goals, constraints, tasks, language
    }

    private func calculateFilledFields() -> Int {
        var count = 0
        if !profile.name.isEmpty { count += 1 }
        if !profile.role.isEmpty { count += 1 }
        if !profile.occupation.isEmpty { count += 1 }
        if !profile.skills.isEmpty { count += 1 }
        if !profile.currentProjects.isEmpty { count += 1 }
        if !profile.interests.isEmpty { count += 1 }
        count += 1 // style always has default
        if !profile.workingHours.isEmpty { count += 1 }
        if !profile.goals.isEmpty { count += 1 }
        if !profile.constraints.isEmpty { count += 1 }
        if !profile.commonTasks.isEmpty { count += 1 }
        if !profile.preferredLanguage.isEmpty { count += 1 }
        return count
    }

    private func calculateCompletionPercentage() -> Double {
        let total = Double(calculateTotalFields())
        let filled = Double(calculateFilledFields())
        return (filled / total) * 100.0
    }
}

// MARK: - Profile Statistics

struct ProfileStatistics {
    let totalFields: Int
    let filledFields: Int
    let completionPercentage: Double
    let lastModified: Date?

    var completionText: String {
        String(format: "%.0f%%", completionPercentage)
    }

    var isWellConfigured: Bool {
        completionPercentage >= 50.0
    }
}
