//
//  ImplementationCard.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 09.10.2025.
//

import SwiftUI

struct ImplementationCard: View {
    let implementation: AgentImplementation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✅ Реализация")
                .font(.headline)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                SectionView(title: "Решение", content: implementation.solution)

                if let code = implementation.code {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Код")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlColor))
                            .cornerRadius(8)
                    }
                }

                Divider()

                SectionView(title: "Объяснение", content: implementation.explanation)

                if let testCases = implementation.test_cases, !testCases.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Тест-кейсы")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(testCases, id: \.self) { testCase in
                            HStack(alignment: .top, spacing: 8) {
                                Text("✓")
                                    .foregroundColor(.green)
                                Text(testCase)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
}
