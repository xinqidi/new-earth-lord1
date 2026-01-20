//
//  SettingsView.swift
//  new earth lord1
//
//  设置页面
//  包含技术支持、隐私政策、版本信息等
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 帮助与支持分组
                    VStack(spacing: 0) {
                        sectionHeader(title: "帮助与支持".localized)

                        VStack(spacing: 0) {
                            // 技术支持
                            SettingRow(
                                icon: "questionmark.circle",
                                title: "技术支持".localized,
                                subtitle: "获取帮助和常见问题解答".localized,
                                iconColor: ApocalypseTheme.info
                            ) {
                                openURL("https://xinqidi.github.io/earthlord-support/support.html")
                            }

                            Divider()
                                .background(ApocalypseTheme.textMuted.opacity(0.3))
                                .padding(.leading, 60)

                            // 隐私政策
                            SettingRow(
                                icon: "lock.shield",
                                title: "隐私政策".localized,
                                subtitle: "了解我们如何保护您的隐私".localized,
                                iconColor: ApocalypseTheme.success
                            ) {
                                openURL("https://xinqidi.github.io/earthlord-support/privacy.html")
                            }
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)

                    // 关于应用分组
                    VStack(spacing: 0) {
                        sectionHeader(title: "关于应用".localized)

                        VStack(spacing: 0) {
                            // 应用版本
                            HStack {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(ApocalypseTheme.primary.opacity(0.2))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "info.circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(ApocalypseTheme.primary)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("版本".localized)
                                            .font(.headline)
                                            .foregroundColor(ApocalypseTheme.textPrimary)

                                        Text("当前版本信息".localized)
                                            .font(.caption)
                                            .foregroundColor(ApocalypseTheme.textSecondary)
                                    }
                                }

                                Spacer()

                                Text("1.0.0")
                                    .font(.subheadline)
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider()
                                .background(ApocalypseTheme.textMuted.opacity(0.3))
                                .padding(.leading, 60)

                            // 版权信息
                            HStack {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.purple.opacity(0.2))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "c.circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(.purple)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("版权".localized)
                                            .font(.headline)
                                            .foregroundColor(ApocalypseTheme.textPrimary)

                                        Text("© 2026 Xiong Haibo")
                                            .font(.caption)
                                            .foregroundColor(ApocalypseTheme.textSecondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)

                    // App名称
                    VStack(spacing: 8) {
                        Text("Earth Lord · 地球新主".localized)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("设置".localized)
        .navigationBarTitleDisplayMode(.inline)
        .id(languageManager.currentLanguage)
    }

    /// 分组标题
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// 打开URL
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ [设置] 无效的URL: \(urlString)")
            return
        }

        print("🌐 [设置] 打开链接: \(urlString)")
        UIApplication.shared.open(url)
    }
}

// MARK: - Setting Row

/// 设置行组件
struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }

                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(LanguageManager.shared)
    }
}
