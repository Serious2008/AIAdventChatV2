//
//  PlanCard.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 09.10.2025.
//

import SwiftUI

struct PlanCard: View {
    let plan: AgentPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📋 Детальный план")
                .font(.headline)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                SectionView(title: "Понимание задачи", content: plan.task_understanding)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Шаги выполнения")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Text(step)
                        }
                    }
                }

                Divider()

                SectionView(title: "Ожидаемый результат", content: plan.expected_output)

                if !plan.considerations.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Важные моменты")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(plan.considerations, id: \.self) { consideration in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.orange)
                                Text(consideration)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}
