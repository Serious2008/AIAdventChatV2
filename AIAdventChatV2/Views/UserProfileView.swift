//
//  UserProfileView.swift
//  AIAdventChatV2
//
//  UI for editing user profile and personalization settings
//

import SwiftUI

// MARK: - User Profile View

struct UserProfileView: View {
    @ObservedObject var service: UserProfileService
    @Environment(\.dismiss) var dismiss

    @State private var showingExportSheet = false
    @State private var exportedJSON = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Мой профиль")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    let stats = service.getStatistics()
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(stats.isWellConfigured ? .green : .orange)
                            Text("Заполнено \(stats.completionText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let lastSaved = service.lastSaved {
                            Divider()
                                .frame(height: 12)
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text("Сохранено \(formatDate(lastSaved))")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Form
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Information
                    GroupBox(label: Label("Базовая информация", systemImage: "person.fill")) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Имя:")
                                    .frame(width: 120, alignment: .trailing)
                                TextField("Например: Сергей", text: $service.profile.name)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Роль:")
                                    .frame(width: 120, alignment: .trailing)
                                TextField("Например: iOS разработчик", text: $service.profile.role)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Профессия:")
                                    .frame(width: 120, alignment: .trailing)
                                TextField("Например: Senior iOS Developer", text: $service.profile.occupation)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Рабочее время:")
                                    .frame(width: 120, alignment: .trailing)
                                TextField("Например: 10:00-19:00 MSK", text: $service.profile.workingHours)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(8)
                    }

                    // Skills
                    GroupBox(label: Label("Навыки и технологии", systemImage: "hammer.fill")) {
                        TagInputView(
                            tags: $service.profile.skills,
                            placeholder: "Добавить навык...",
                            examples: ["Swift", "SwiftUI", "Python", "Machine Learning"]
                        )
                        .padding(8)
                    }

                    // Current Projects
                    GroupBox(label: Label("Текущие проекты", systemImage: "folder.fill")) {
                        TagInputView(
                            tags: $service.profile.currentProjects,
                            placeholder: "Добавить проект...",
                            examples: ["AIAdventChatV2", "PersonalWebsite"]
                        )
                        .padding(8)
                    }

                    // Interests
                    GroupBox(label: Label("Интересы", systemImage: "star.fill")) {
                        TagInputView(
                            tags: $service.profile.interests,
                            placeholder: "Добавить интерес...",
                            examples: ["AI", "Machine Learning", "iOS разработка", "RAG"]
                        )
                        .padding(8)
                    }

                    // Communication Style
                    GroupBox(label: Label("Стиль общения", systemImage: "message.fill")) {
                        VStack(spacing: 12) {
                            Picker("", selection: $service.profile.communicationStyle) {
                                ForEach(UserProfile.CommunicationStyle.allCases, id: \.self) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(service.profile.communicationStyle.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(8)
                    }

                    // Goals
                    GroupBox(label: Label("Текущие цели", systemImage: "target")) {
                        TagInputView(
                            tags: $service.profile.goals,
                            placeholder: "Добавить цель...",
                            examples: ["Изучить RAG", "Создать AI ассистента"]
                        )
                        .padding(8)
                    }

                    // Constraints
                    GroupBox(label: Label("Ограничения", systemImage: "exclamationmark.triangle.fill")) {
                        TagInputView(
                            tags: $service.profile.constraints,
                            placeholder: "Добавить ограничение...",
                            examples: ["Использовать только macOS API", "Минимизировать зависимости"]
                        )
                        .padding(8)
                    }

                    // Common Tasks
                    GroupBox(label: Label("Частые задачи", systemImage: "list.bullet")) {
                        TagInputView(
                            tags: $service.profile.commonTasks,
                            placeholder: "Добавить задачу...",
                            examples: ["Код-ревью", "Debugging", "Архитектура"]
                        )
                        .padding(8)
                    }
                }
                .padding()
            }

            Divider()

            // Footer buttons
            HStack(spacing: 12) {
                Button("Загрузить пример") {
                    service.loadExample()
                }
                .help("Заполнить профиль примером данных")

                Button("Сбросить") {
                    service.reset()
                }
                .foregroundColor(.red)
                .help("Очистить весь профиль")

                Spacer()

                Button("Экспорт") {
                    if let json = service.exportToJSON() {
                        exportedJSON = json
                        showingExportSheet = true
                    }
                }
                .help("Экспортировать профиль в JSON")

                Button("Сохранить и закрыть") {
                    service.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 700, height: 800)
        .sheet(isPresented: $showingExportSheet) {
            ExportProfileView(json: exportedJSON)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Tag Input View

struct TagInputView: View {
    @Binding var tags: [String]
    var placeholder: String
    var examples: [String] = []

    @State private var newTag: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Existing tags
            if !tags.isEmpty {
                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                    HStack {
                        Text(tag)
                            .font(.callout)

                        Button(action: {
                            tags.remove(at: index)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }

            // Input field
            HStack {
                TextField(placeholder, text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTag()
                    }

                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Examples
            if !examples.isEmpty && tags.isEmpty {
                Text("Примеры: " + examples.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }

        tags.append(trimmed)
        newTag = ""
    }
}

// TagChip removed - integrated into TagInputView for simplicity

// MARK: - Export Profile View

struct ExportProfileView: View {
    let json: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Экспорт профиля")
                    .font(.headline)
                Spacer()
                Button("Закрыть") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            TextEditor(text: .constant(json))
                .font(.system(.body, design: .monospaced))
                .padding()

            Divider()

            HStack {
                Button("Скопировать") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(json, forType: .string)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
}
