//
//  PlaceholderView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI

/// 通用占位视图
struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(title.localized)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle.localized)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        // 强制在语言变化时重新渲染
        .id(languageManager.currentLanguage)
    }
}

#Preview {
    PlaceholderView(
        icon: "map.fill",
        title: "地图",
        subtitle: "探索和圈占领地"
    )
}
