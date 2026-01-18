//
//  MoreTabView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var explorationManager: ExplorationManager

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 标题
                    VStack(spacing: 8) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 50))
                            .foregroundColor(ApocalypseTheme.primary)

                        Text("更多".localized)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("功能与设置".localized)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.top, 40)

                    Spacer()

                    // 占位文本
                    VStack(spacing: 16) {
                        Image(systemName: "gearshape.2")
                            .font(.system(size: 60))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text("敬请期待...".localized)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text("更多功能正在开发中".localized)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // 强制在语言变化时重新渲染
            .id(languageManager.currentLanguage)
        }
    }
}

#Preview {
    MoreTabView()
        .environmentObject(LanguageManager.shared)
        .environmentObject(LocationManager())
        .environmentObject(ExplorationManager())
}
