//
//  ResultView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 09.10.2025.
//

import SwiftUI

struct ResultView: View {
    let result: MultiAgentResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Общая информация
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Задача выполнена!")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(String(format: "%.2fs", result.totalTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            // Агент 1: Планировщик
            AgentResultCard(
                title: "🤖 Агент-Планировщик",
                subtitle: "Анализ и планирование",
                content: result.plannerResponse,
                metrics: result.plannerMetrics,
                color: .blue
            )

            // План (если распарсен)
            if let plan = result.plannerPlan {
                PlanCard(plan: plan)
            }

            // Агент 2: Реализатор
            AgentResultCard(
                title: "🛠️ Агент-Реализатор",
                subtitle: "Реализация решения",
                content: result.implementerResponse,
                metrics: result.implementerMetrics,
                color: .purple
            )

            // Реализация (если распарсена)
            if let implementation = result.implementation {
                ImplementationCard(implementation: implementation)
            }
        }
    }
}
