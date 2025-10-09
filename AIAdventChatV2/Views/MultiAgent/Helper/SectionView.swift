//
//  SectionView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 09.10.2025.
//

import SwiftUI

struct SectionView: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(content)
        }
    }
}
