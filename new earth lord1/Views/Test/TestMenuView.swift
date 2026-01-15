//
//  TestMenuView.swift
//  new earth lord1
//
//  测试模块入口菜单
//  显示所有测试功能的入口，包括 Supabase 测试、圈地测试和探索测试
//

import SwiftUI

struct TestMenuView: View {

    // MARK: - Environment Objects

    /// 语言管理器
    @EnvironmentObject private var languageManager: LanguageManager

    /// 定位管理器
    @EnvironmentObject private var locationManager: LocationManager

    /// 探索管理器
    @EnvironmentObject private var explorationManager: ExplorationManager

    // MARK: - Body

    var body: some View {
        let _ = languageManager.currentLanguage // 触发语言切换

        return List {
            // MARK: - Supabase 连接测试

            NavigationLink(destination: SupabaseTestView()) {
                HStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Supabase 连接测试")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("测试数据库连接状态".localized)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // MARK: - 圈地功能测试

            NavigationLink(destination:
                TerritoryTestView()
                    .environmentObject(locationManager)
            ) {
                HStack(spacing: 16) {
                    Image(systemName: "map.circle")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("圈地功能测试")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("查看圈地过程的调试日志")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // MARK: - 探索功能测试

            NavigationLink(destination:
                ExplorationLogView()
                    .environmentObject(explorationManager)
            ) {
                HStack(spacing: 16) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("探索功能测试")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("查看POI检测和探索日志")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("开发测试")
        .navigationBarTitleDisplayMode(.large)
        .listStyle(InsetGroupedListStyle())
        .id(languageManager.currentLanguage) // 语言切换时重新渲染
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestMenuView()
            .environmentObject(LanguageManager.shared)
            .environmentObject(LocationManager())
            .environmentObject(ExplorationManager())
    }
}
