//
//  MoreTabView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject private var languageManager: LanguageManager

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

                    // 功能列表
                    VStack(spacing: 16) {
                        // Supabase 测试按钮
                        NavigationLink(destination: SupabaseTestView()) {
                            HStack {
                                Image(systemName: "network")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Supabase 连接测试".localized)
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text("测试数据库连接状态".localized)
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
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
}
