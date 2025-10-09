//
//  AgentResultCard.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 09.10.2025.
//

import SwiftUI

struct AgentResultCard: View {
    let title: String
    let subtitle: String
    let content: String
    let metrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(content)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlColor))
                .cornerRadius(8)

            HStack(spacing: 12) {
                MetricBadge(
                    icon: "clock",
                    value: String(format: "%.2fs", metrics.responseTime),
                    color: .orange
                )

                if let input = metrics.inputTokens, let output = metrics.outputTokens {
                    MetricBadge(
                        icon: "arrow.left.arrow.right",
                        value: "\(input) → \(output)",
                        color: .blue
                    )
                }

                if let cost = metrics.cost {
                    MetricBadge(
                        icon: "dollarsign.circle",
                        value: String(format: "$%.4f", cost),
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
