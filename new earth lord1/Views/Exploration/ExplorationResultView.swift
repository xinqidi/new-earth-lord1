//
//  ExplorationResultView.swift
//  new earth lord1
//
//  探索结果页面
//  显示探索完成后的统计数据和获得的物品
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss

    // MARK: - Properties

    /// 探索统计数据
    let stats: ExplorationStats

    /// 是否探索失败
    let hasFailed: Bool

    /// 错误信息
    let errorMessage: String

    /// 重试回调
    let onRetry: (() -> Void)?

    // MARK: - Animation State

    /// 动画数值
    @State private var animatedDistanceSession: Double = 0
    @State private var animatedDistanceTotal: Double = 0
    @State private var animatedAreaSession: Double = 0
    @State private var animatedAreaTotal: Double = 0
    @State private var animatedDuration: Int = 0

    /// 物品显示状态
    @State private var itemsShown: Set<String> = []

    /// 对勾缩放状态
    @State private var checkmarkScales: [String: CGFloat] = [:]

    // MARK: - Initialization

    init(
        stats: ExplorationStats = MockExplorationData.mockExplorationStats,
        hasFailed: Bool = false,
        errorMessage: String = "探索过程中发生了未知错误",
        onRetry: (() -> Void)? = nil
    ) {
        self.stats = stats
        self.hasFailed = hasFailed
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if hasFailed {
                    // 错误状态
                    errorStateView
                } else {
                    // 成功状态
                    ScrollView {
                        VStack(spacing: 24) {
                            // 成就标题
                            achievementHeader
                                .padding(.top, 20)

                            // 统计数据卡片
                            statsCard
                                .padding(.horizontal)

                            // 奖励物品卡片
                            rewardsCard
                                .padding(.horizontal)

                            // 确认按钮
                            confirmButton
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle(hasFailed ? "探索失败" : "探索完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
        }
        .onAppear {
            if !hasFailed {
                startAnimations()
            }
        }
    }

    // MARK: - Animations

    /// 启动所有动画
    private func startAnimations() {
        // 数字跳动动画（0.8秒内从0跳到目标值）
        withAnimation(.easeOut(duration: 0.8)) {
            animatedDistanceSession = stats.distanceThisSession
            animatedDistanceTotal = stats.totalDistance
            animatedAreaSession = stats.areaThisSession
            animatedAreaTotal = stats.totalArea
            animatedDuration = stats.durationMinutes
        }

        // 物品依次出现动画（每个间隔0.2秒）
        let sortedItemIds = stats.itemsFound.keys.sorted()
        for (index, itemId) in sortedItemIds.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    itemsShown.insert(itemId)
                }

                // 对勾弹跳动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkmarkScales[itemId] = 1.5
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        checkmarkScales[itemId] = 1.0
                    }
                }
            }
        }
    }

    // MARK: - 成就标题

    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标（带动画效果）
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 20, x: 0, y: 10)

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("勇敢的探险者")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 装饰星星
            HStack(spacing: 20) {
                ForEach(0..<3) { _ in
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.warning)
                }
            }
        }
    }

    // MARK: - 统计数据卡片

    private var statsCard: some View {
        VStack(spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("探索统计")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            Divider()
                .background(ApocalypseTheme.textMuted)

            // 行走距离
            statsRow(
                icon: "figure.walk",
                title: "行走距离",
                thisSession: String(format: "%.0f米", animatedDistanceSession),
                total: String(format: "%.1fkm", animatedDistanceTotal / 1000),
                rank: stats.distanceRank
            )

            Divider()
                .background(ApocalypseTheme.textMuted)

            // 探索面积
            statsRow(
                icon: "map",
                title: "探索面积",
                thisSession: String(format: "%.1f万m²", animatedAreaSession / 10000),
                total: String(format: "%.1f万m²", animatedAreaTotal / 10000),
                rank: stats.areaRank
            )

            Divider()
                .background(ApocalypseTheme.textMuted)

            // 探索时长
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                }

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text("探索时长")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("\(animatedDuration)分钟")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }

    /// 统计行视图
    private func statsRow(icon: String, title: String, thisSession: String, total: String, rank: Int) -> some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.info.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.info)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("本次:")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(thisSession)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Text("|")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    HStack(spacing: 4) {
                        Text("累计:")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(total)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }

            Spacer()

            // 排名
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Text("#\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.success)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.success.opacity(0.2))
            .cornerRadius(12)
        }
    }

    // MARK: - 奖励物品卡片

    private var rewardsCard: some View {
        VStack(spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("获得物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 物品数量
                Text("\(stats.itemsFound.count)种")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(8)
            }

            Divider()
                .background(ApocalypseTheme.textMuted)

            // 物品列表
            VStack(spacing: 12) {
                ForEach(Array(stats.itemsFound.keys.sorted()), id: \.self) { itemId in
                    if let quantity = stats.itemsFound[itemId],
                       let definition = MockExplorationData.getItemDefinition(for: itemId) {
                        itemRow(definition: definition, quantity: quantity, itemId: itemId)
                            .opacity(itemsShown.contains(itemId) ? 1 : 0)
                            .offset(x: itemsShown.contains(itemId) ? 0 : -20)
                    }
                }
            }

            Divider()
                .background(ApocalypseTheme.textMuted)

            // 底部提示
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Text("已添加到背包")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }

    /// 物品行视图
    private func itemRow(definition: ItemDefinition, quantity: Int, itemId: String) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor(definition.category).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: categoryIcon(definition.category))
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor(definition.category))
            }

            // 物品名称
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(definition.category.rawValue)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 数量
            Text("x\(quantity)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .cornerRadius(10)

            // 对勾
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScales[itemId] ?? 0.5)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.headline)

                Text("太棒了！")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 10, x: 0, y: 4)
        }
    }

    // MARK: - 错误状态视图

    private var errorStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误信息
            VStack(spacing: 12) {
                Text("探索失败")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // 重试按钮
            if let retry = onRetry {
                Button(action: {
                    retry()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.headline)

                        Text("重试")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - Helper Methods

    /// 分类对应的颜色
    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .water:
            return .blue
        case .food:
            return .orange
        case .medical:
            return .red
        case .material:
            return .brown
        case .tool:
            return .cyan
        }
    }

    /// 分类对应的图标
    private func categoryIcon(_ category: ItemCategory) -> String {
        switch category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.fill"
        case .material:
            return "hammer.fill"
        case .tool:
            return "wrench.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ExplorationResultView()
}
