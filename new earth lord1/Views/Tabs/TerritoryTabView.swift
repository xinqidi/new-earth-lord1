//
//  TerritoryTabView.swift
//  new earth lord1
//
//  领地管理页面
//  显示我的领地列表、统计信息，支持查看详情和删除
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - Environment Objects

    /// 认证管理器
    @EnvironmentObject private var authManager: AuthManager

    /// 语言管理器
    @EnvironmentObject private var languageManager: LanguageManager

    // MARK: - State Properties

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading = false

    /// 选中的领地（用于详情页）
    @State private var selectedTerritory: Territory?

    /// 领地管理器
    @State private var territoryManager: TerritoryManager?

    // MARK: - Computed Properties

    /// 总面积
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Body

    var body: some View {
        let _ = languageManager.currentLanguage // 触发语言切换

        return NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading {
                    // 加载中
                    ProgressView("加载中...".localized)
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    ScrollView {
                        VStack(spacing: 20) {
                            // 统计信息头部
                            statisticsHeaderView

                            // 领地卡片列表
                            ForEach(myTerritories) { territory in
                                TerritoryCardView(territory: territory)
                                    .onTapGesture {
                                        selectedTerritory = territory
                                    }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadMyTerritories()
                    }
                }
            }
            .navigationTitle("我的领地".localized)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if territoryManager == nil {
                    territoryManager = TerritoryManager(supabase: authManager.supabase)
                }
                Task {
                    await loadMyTerritories()
                }
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    territoryManager: territoryManager,
                    onDelete: {
                        selectedTerritory = nil
                        Task {
                            await loadMyTerritories()
                        }
                    }
                )
            }
        }
        .id(languageManager.currentLanguage) // 语言切换时重新渲染
    }

    // MARK: - Subviews

    /// 统计信息头部
    private var statisticsHeaderView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // 领地数量
                StatisticItemView(
                    icon: "flag.fill",
                    value: "\(myTerritories.count)",
                    label: "领地数量".localized,
                    color: .green
                )

                Divider()
                    .frame(height: 40)

                // 总面积
                StatisticItemView(
                    icon: "map.fill",
                    value: formattedTotalArea,
                    label: "总面积".localized,
                    color: .blue
                )
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("还没有领地".localized)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图圈占你的第一块领地吧！".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Methods

    /// 加载我的领地
    private func loadMyTerritories() async {
        guard let userId = authManager.currentUser?.id else {
            print("⚠️ [领地页] 用户未登录")
            return
        }

        guard let manager = territoryManager else {
            print("⚠️ [领地页] TerritoryManager 未初始化")
            return
        }

        isLoading = true

        do {
            myTerritories = try await manager.loadMyTerritories(userId: userId)
            print("✅ [领地页] 加载了 \(myTerritories.count) 个领地")
        } catch {
            print("❌ [领地页] 加载领地失败: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - Statistic Item View

/// 统计项视图
struct StatisticItemView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Territory Card View

/// 领地卡片视图
struct TerritoryCardView: View {
    let territory: Territory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 领地名称
                Text(territory.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 面积
                Text(territory.formattedArea)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 详细信息
            HStack(spacing: 16) {
                // 点数
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                    Text(String(format: "%lld 个点".localized, territory.pointCount ?? 0))
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)

                // 创建时间
                if let createdAt = territory.createdAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formatDate(createdAt))
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 箭头提示
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }

    /// 格式化日期
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
        .environmentObject(AuthManager())
        .environmentObject(LanguageManager.shared)
}
