//
//  TokenIndicatorView.swift
//  AIAdventChatV2
//
//  Created by Claude on 10.10.2025.
//

import SwiftUI

struct TokenIndicatorView: View {
    let message: String
    let provider: ModelProvider
    let model: String

    private var estimatedTokens: Int {
        TokenManager.estimateTokens(message)
    }

    private var limit: Int {
        TokenManager.getLimit(for: model, provider: provider)
    }

    private var status: TokenStatus {
        TokenManager.checkStatus(tokens: estimatedTokens, limit: limit)
    }

    private var statusColor: Color {
        let rgb = TokenManager.getColor(for: status)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private var statusIcon: String {
        switch status {
        case .ok:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .exceeded:
            return "xmark.circle.fill"
        }
    }

    private var statusText: String {
        switch status {
        case .ok:
            return "В пределах нормы"
        case .warning:
            return "Близко к лимиту"
        case .exceeded:
            return "Превышен лимит!"
        }
    }

    private var percentage: Double {
        Double(estimatedTokens) / Double(limit)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Иконка статуса
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title3)

            // Информация о токенах
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Токены:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(estimatedTokens) / \(formatNumber(limit))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)

                    Text("(\(String(format: "%.1f%%", percentage * 100)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Статус
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(statusColor)
            }

            Spacer()

            // Прогресс бар
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Фон
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)

                    // Прогресс
                    Rectangle()
                        .fill(statusColor)
                        .frame(width: min(geometry.size.width * CGFloat(percentage), geometry.size.width), height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.3), value: percentage)
                }
            }
            .frame(width: 100, height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.0fk", Double(number) / 1000)
        }
        return "\(number)"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // OK status
        TokenIndicatorView(
            message: "Привет, как дела?",
            provider: .claude,
            model: "claude-3-7-sonnet-20250219"
        )

        // Warning status
        TokenIndicatorView(
            message: String(repeating: "Это длинное сообщение с множеством слов. ", count: 1000),
            provider: .huggingface,
            model: "microsoft/phi-2"
        )

        // Exceeded status
        TokenIndicatorView(
            message: String(repeating: "Очень-очень длинное сообщение. ", count: 500),
            provider: .huggingface,
            model: "microsoft/phi-2"
        )
    }
    .padding()
}
