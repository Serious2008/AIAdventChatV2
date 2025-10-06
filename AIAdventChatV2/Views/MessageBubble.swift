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
            if message.isFromUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
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
                                // Основной ответ
                                Text(parsed.response)
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

                                    if let additionalInfo = parsed.additional_info, !additionalInfo.isEmpty {
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "info.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Дополнительно:")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.secondary)
                                                Text(additionalInfo)
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        } else {
                            // Fallback для обычного текста
                            Text(message.content)
                                .padding(12)
                                .background(Color(NSColor.controlColor))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
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
