//
//  MessageBubble.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isSystemMessage {
                // Системное сообщение (суммаризация и т.д.)
                HStack(spacing: 8) {
                    Spacer()
                    Text(message.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    Spacer()
                }
            } else if message.isFromUser {
                Spacer(minLength: 50)

                VStack(alignment: .trailing, spacing: 4) {
                    ScrollView {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .frame(maxHeight: 400)
                    .background(Color.blue)
                    .cornerRadius(18)

                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                            .font(.title3)

                        // Форматированный контент для Claude
                        if let parsed = message.parsedContent {
                            VStack(alignment: .leading, spacing: 12) {
                                // Основной ответ с дополнительной информацией внутри
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(parsed.response)
                                        .textSelection(.enabled)

                                    if let additionalInfo = parsed.additional_info, !additionalInfo.isEmpty {
                                        Divider()
                                            .padding(.vertical, 4)

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "info.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.body)
                                                Text("Дополнительно:")
                                                    .font(.body)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(additionalInfo)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlColor))
                                .clipShape(RoundedRectangle(cornerRadius: 18))

                                // Карточки с дополнительной информацией
                                VStack(alignment: .leading, spacing: 8) {
                                    if let confidence = parsed.confidence {
                                        HStack {
                                            Image(systemName: confidenceIcon(confidence))
                                                .foregroundColor(confidenceColor(confidence))
                                            Text("Уверенность:")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                            Text(confidence)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(confidenceColor(confidence))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(confidenceColor(confidence).opacity(0.1))
                                        .cornerRadius(8)
                                    }

                                    // Метрики
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            if let temperature = message.temperature {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "thermometer.medium")
                                                        .foregroundColor(.purple)
                                                        .font(.caption2)
                                                    Text(String(format: "%.1f", temperature))
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.purple)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.purple.opacity(0.1))
                                                .cornerRadius(6)
                                            }

                                            if let responseTime = message.responseTime {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "clock")
                                                        .foregroundColor(.orange)
                                                        .font(.caption2)
                                                    Text(String(format: "%.2fs", responseTime))
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.orange)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.orange.opacity(0.1))
                                                .cornerRadius(6)
                                            }

                                            if let cost = message.cost, cost > 0 {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "dollarsign.circle")
                                                        .foregroundColor(.green)
                                                        .font(.caption2)
                                                    Text(String(format: "$%.4f", cost))
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.green)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.green.opacity(0.1))
                                                .cornerRadius(6)
                                            }
                                        }

                                        HStack(spacing: 8) {
                                            if let inputTokens = message.inputTokens,
                                               let outputTokens = message.outputTokens {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.left.arrow.right")
                                                        .foregroundColor(.blue)
                                                        .font(.caption2)
                                                    Text("Токены:")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text("\(inputTokens) → \(outputTokens)")
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.blue)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(6)
                                            }

                                            // Скорость генерации токенов
                                            if let outputTokens = message.outputTokens,
                                               let responseTime = message.responseTime,
                                               responseTime > 0 {
                                                let tokensPerSecond = Double(outputTokens) / responseTime
                                                HStack(spacing: 4) {
                                                    Image(systemName: "speedometer")
                                                        .foregroundColor(.cyan)
                                                        .font(.caption2)
                                                    Text("Скорость:")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text(String(format: "%.1f t/s", tokensPerSecond))
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.cyan)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.cyan.opacity(0.1))
                                                .cornerRadius(6)
                                            }
                                        }
                                    }

                                    if let modelName = message.modelName {
                                        HStack {
                                            Image(systemName: "cpu")
                                                .foregroundColor(.gray)
                                            Text("Модель:")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                            Text(modelName)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }

                                    // RAG Sources
                                    if message.usedRAG, let ragSources = message.ragSources, !ragSources.isEmpty {
                                        RAGSourcesView(sources: ragSources, citationCount: message.citationCount ?? 0)
                                    }
                                }
                            }
                        } else {
                            // Fallback для обычного текста (без JSON парсинга)
                            VStack(alignment: .leading, spacing: 12) {
                                Text(message.content)
                                    .textSelection(.enabled)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.controlColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))

                                // Метрики для обычного текста
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        if let temperature = message.temperature {
                                            HStack(spacing: 4) {
                                                Image(systemName: "thermometer.medium")
                                                    .foregroundColor(.purple)
                                                    .font(.caption2)
                                                Text(String(format: "%.1f", temperature))
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.purple)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.purple.opacity(0.1))
                                            .cornerRadius(6)
                                        }

                                        if let responseTime = message.responseTime {
                                            HStack(spacing: 4) {
                                                Image(systemName: "clock")
                                                    .foregroundColor(.orange)
                                                    .font(.caption2)
                                                Text(String(format: "%.2fs", responseTime))
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.orange)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.1))
                                            .cornerRadius(6)
                                        }

                                        if let cost = message.cost, cost > 0 {
                                            HStack(spacing: 4) {
                                                Image(systemName: "dollarsign.circle")
                                                    .foregroundColor(.green)
                                                    .font(.caption2)
                                                Text(String(format: "$%.4f", cost))
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.green)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(6)
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        if let inputTokens = message.inputTokens,
                                           let outputTokens = message.outputTokens {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.left.arrow.right")
                                                    .foregroundColor(.blue)
                                                    .font(.caption2)
                                                Text("Токены:")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text("\(inputTokens) → \(outputTokens)")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.blue)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(6)
                                        }

                                        // Скорость генерации токенов
                                        if let outputTokens = message.outputTokens,
                                           let responseTime = message.responseTime,
                                           responseTime > 0 {
                                            let tokensPerSecond = Double(outputTokens) / responseTime
                                            HStack(spacing: 4) {
                                                Image(systemName: "speedometer")
                                                    .foregroundColor(.cyan)
                                                    .font(.caption2)
                                                Text("Скорость:")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(String(format: "%.1f t/s", tokensPerSecond))
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.cyan)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.cyan.opacity(0.1))
                                            .cornerRadius(6)
                                        }
                                    }
                                }

                                if let modelName = message.modelName {
                                    HStack {
                                        Image(systemName: "cpu")
                                            .foregroundColor(.gray)
                                        Text("Модель:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                        Text(modelName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }

                                // RAG Sources (in fallback section)
                                if message.usedRAG, let ragSources = message.ragSources, !ragSources.isEmpty {
                                    RAGSourcesView(sources: ragSources, citationCount: message.citationCount ?? 0)
                                }
                            }
                        }
                    }

                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                }

                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func confidenceColor(_ confidence: String) -> Color {
        let lower = confidence.lowercased()
        if lower.contains("высок") || lower.contains("high") {
            return .green
        } else if lower.contains("средн") || lower.contains("medium") {
            return .orange
        } else if lower.contains("низк") || lower.contains("low") {
            return .red
        }
        return .gray
    }

    private func confidenceIcon(_ confidence: String) -> String {
        let lower = confidence.lowercased()
        if lower.contains("высок") || lower.contains("high") {
            return "checkmark.circle.fill"
        } else if lower.contains("средн") || lower.contains("medium") {
            return "exclamationmark.circle.fill"
        } else if lower.contains("низк") || lower.contains("low") {
            return "xmark.circle.fill"
        }
        return "circle.fill"
    }
}

// MARK: - RAG Sources View

struct RAGSourcesView: View {
    let sources: [RAGSource]
    let citationCount: Int
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with expand button
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.green)
                    Text("RAG Источники:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 8) {
                        // Citation count badge
                        HStack(spacing: 4) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.caption2)
                            Text("\(citationCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(4)

                        // Sources count badge
                        HStack(spacing: 4) {
                            Image(systemName: "doc.fill")
                                .font(.caption2)
                            Text("\(sources.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(4)

                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expanded sources list
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("[\(index + 1)]")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(4)

                                Text(source.fileName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Spacer()

                                Text("\(String(format: "%.0f%%", source.similarity * 100))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Text(source.chunkContent.prefix(100) + "...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}
