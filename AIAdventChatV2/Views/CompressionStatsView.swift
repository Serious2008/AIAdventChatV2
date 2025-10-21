//
//  CompressionStatsView.swift
//  AIAdventChatV2
//
//  View for displaying compression statistics
//

import SwiftUI

struct CompressionStatsView: View {
    let stats: CompressionStats
    let compressedHistory: CompressedConversationHistory
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.purple)

                    Text("Статистика сжатия истории")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    if stats.totalCompressions > 0 {
                        Text("\(stats.totalTokensSaved) токенов сэкономлено")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Divider()

                // Statistics Grid
                if stats.totalCompressions > 0 {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        // Total Compressions
                        StatCard(
                            icon: "arrow.down.circle.fill",
                            title: "Сжатий",
                            value: "\(stats.totalCompressions)",
                            color: .blue
                        )

                        // Tokens Saved
                        StatCard(
                            icon: "arrow.down.circle.fill",
                            title: "Сэкономлено",
                            value: "\(stats.totalTokensSaved)",
                            subtitle: "токенов",
                            color: .green
                        )

                        // Compression Ratio
                        StatCard(
                            icon: "percent",
                            title: "Эффективность",
                            value: String(format: "%.1f%%", stats.compressionEfficiency),
                            color: .purple
                        )

                        // Average Saved
                        StatCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "В среднем",
                            value: String(format: "%.0f", stats.averageTokensSavedPerCompression),
                            subtitle: "токенов",
                            color: .orange
                        )
                    }

                    // Current State
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Текущее состояние")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("\(compressedHistory.summaries.count) summary")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "message")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("\(compressedHistory.recentMessages.count) недавних")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                                Text(String(format: "%.1f%%", (1.0 - compressedHistory.compressionRatio) * 100))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Token Usage Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)

                                // Filled portion
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.green, Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geometry.size.width * CGFloat(compressedHistory.compressionRatio),
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("Использовано: \(compressedHistory.totalTokensEstimate) токенов")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("Было: \(compressedHistory.originalTokensEstimate)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)

                    // Last Compression Date
                    if let lastDate = stats.lastCompressionDate {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Последнее сжатие: \(formatDate(lastDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // No compressions yet
                    VStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text("Сжатия еще не производились")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Статистика появится после первого автоматического сжатия истории")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        // With stats
        CompressionStatsView(
            stats: {
                var stats = CompressionStats()
                stats.totalCompressions = 3
                stats.totalTokensSaved = 4500
                stats.totalOriginalTokens = 10000
                stats.totalCompressedTokens = 5500
                stats.averageCompressionRatio = 0.55
                stats.lastCompressionDate = Date()
                return stats
            }(),
            compressedHistory: {
                var history = CompressedConversationHistory()
                history.summaries = [
                    ConversationSummary(
                        summary: "Test summary",
                        originalMessagesCount: 10,
                        originalTokensEstimate: 2000,
                        summaryTokensEstimate: 500,
                        startDate: Date().addingTimeInterval(-3600),
                        endDate: Date()
                    )
                ]
                return history
            }()
        )

        // Without stats
        CompressionStatsView(
            stats: CompressionStats(),
            compressedHistory: CompressedConversationHistory()
        )
    }
    .padding()
    .frame(width: 500)
}
