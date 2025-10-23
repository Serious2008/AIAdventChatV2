//
//  TextPipelineView.swift
//  AIAdventChatV2
//
//  UI for text processing pipeline results
//

import SwiftUI

struct TextPipelineView: View {
    let result: PipelineResult
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStage: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Text Processing Pipeline")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Statistics
            statisticsSection

            Divider()

            // Stage selector
            Picker("Stage", selection: $selectedStage) {
                Text("Original").tag(0)
                Text("Cleaned").tag(1)
                Text("Compressed").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Text display
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if selectedStage == 0 {
                        textCard(
                            title: "Original Text",
                            text: result.originalText,
                            color: .red
                        )
                    } else if selectedStage == 1 {
                        textCard(
                            title: "Cleaned Text",
                            text: result.cleanedText,
                            color: .orange
                        )
                    } else {
                        textCard(
                            title: "Compressed Text",
                            text: result.compressedText,
                            color: .green
                        )
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 800, idealWidth: 900, maxWidth: 1000,
               minHeight: 600, idealHeight: 700, maxHeight: 900)
    }

    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                statCard(
                    title: "Original",
                    value: "\(result.statistics.originalLength)",
                    subtitle: "characters",
                    color: .red
                )

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                statCard(
                    title: "Cleaned",
                    value: "\(result.statistics.cleanedLength)",
                    subtitle: "\(String(format: "%.1f", result.statistics.cleaningReduction))% reduced",
                    color: .orange
                )

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                statCard(
                    title: "Compressed",
                    value: "\(result.statistics.compressedLength)",
                    subtitle: "\(String(format: "%.1f", result.statistics.compressionReduction))% reduced",
                    color: .green
                )
            }

            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("Total Reduction:")
                    .foregroundColor(.secondary)
                Text("\(String(format: "%.1f", result.statistics.totalReduction))%")
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Spacer()

                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Processing Time:")
                    .foregroundColor(.secondary)
                Text("\(String(format: "%.2f", result.totalProcessingTime))s")
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func textCard(title: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)

                Spacer()

                Text("\(text.count) chars")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    TextPipelineView(result: PipelineResult(
        originalText: "This is a <b>test</b> text with HTML tags and lots of extra    spaces\n\n\n\nand multiple newlines.",
        cleanedText: "This is a test text with HTML tags and lots of extra spaces\n\nand multiple newlines.",
        compressedText: "Test text with HTML and formatting.",
        stages: [],
        totalProcessingTime: 1.5
    ))
}
