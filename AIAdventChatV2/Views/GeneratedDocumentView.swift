//
//  GeneratedDocumentView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 05.10.2025.
//

import SwiftUI

// MARK: - Generated Document View
struct GeneratedDocumentView: View {
    let document: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text("Сгенерированное ТЗ")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button("Закрыть") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Содержимое документа
            ScrollView {
                Text(document)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // Кнопки действий
            HStack {
                Button(action: {
                    copyToClipboard(document)
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Копировать")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    saveToFile(document)
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Сохранить в файл")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func saveToFile(_ text: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "Техническое_задание.md"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
