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
            } else {
                VStack(alignment: .leading) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.black)
                    
                    if let timestamp = message.timestamp {
                        Text(formatTime(timestamp))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        MessageBubble(message: Message(content: "Привет! Как дела?", isFromUser: true))
        MessageBubble(message: Message(content: "Отлично, спасибо! Чем могу помочь?", isFromUser: false))
    }
    .padding()
}