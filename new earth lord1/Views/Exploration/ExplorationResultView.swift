//
//  ExplorationResultView.swift
//  new earth lord1
//
//  探索结果页面
//  显示探索完成后的统计数据、奖励等级和获得的物品
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss

    // MARK: - Properties

    /// 探索结果
    let result: ExplorationResult

    // MARK: - Animation State

    /// 物品显示状态
    @State private var itemsShown: Set<UUID> = []

    /// 对勾缩放状态
    @State private var checkmarkScales: [UUID: CGFloat] = [:]

    /// 徽章动画状态
    @State private var badgeScale: CGFloat = 0.5
    @State private var badgeOpacity: Double = 0

    /// 动画是否已启动（防止重复触发）
    @State private var animationsStarted: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if result.hasFailed {
                    // 错误状态
                    errorStateView
                } else {
                    // 成功状态
                    ScrollView {
                        VStack(spacing: 24) {
                            // 成就标题
                            achievementHeader
                                .padding(.top, 20)

                            // 等级徽章
                            tierBadge
                                .scaleEffect(badgeScale)
                                .opacity(badgeOpacity)

                            // 统计数据卡片
                            statsCard
                                .padding(.horizontal)

                            // 奖励物品卡片（仅在有物品时显示）
                            if !result.items.isEmpty {
                                rewardsCard
                                    .padding(.horizontal)
                            }

                            // 确认按钮
                            confirmButton
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle(result.hasFailed ? "探索失败".localized : "探索完成".localized)
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
            print("🎁 [探索结果] 页面出现，hasFailed=\(result.hasFailed), items=\(result.items.count)")
            if !result.hasFailed && !animationsStarted {
                animationsStarted = true
                // 延迟一点启动动画，确保视图完全加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startAnimations()
                }
            }
        }
    }

    // MARK: - Animations

    /// 启动所有动画
    private func startAnimations() {
        print("🎁 [探索结果] 启动动画，物品数量: \(result.items.count)")

        // 徽章动画
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            badgeScale = 1.0
            badgeOpacity = 1.0
        }

        // 初始化所有对勾的缩放为0
        for item in result.items {
            checkmarkScales[item.id] = 0
        }

        // 物品依次出现动画（每个间隔0.3秒）
        for (index, item) in result.items.enumerated() {
            let delay = 0.5 + Double(index) * 0.3
            print("🎁 [探索结果] 安排物品[\(index)]动画: \(item.name), 延迟 \(delay)s")

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                print("🎁 [探索结果] 显示物品: \(item.name)")

                // 物品滑入动画
                withAnimation(.easeOut(duration: 0.3)) {
                    self.itemsShown.insert(item.id)
                }

                // 对勾弹跳动画（物品出现后0.15秒）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // 先设置到1.3倍
                    self.checkmarkScales[item.id] = 1.3
                    // 然后弹回1.0
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        self.checkmarkScales[item.id] = 1.0
                    }
                }
            }
        }
    }

    // MARK: - 成就标题

    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标
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
                    .frame(width: 100, height: 100)

                Image(systemName: "figure.walk")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 15, x: 0, y: 8)

            // 标题文字
            Text("探索完成！".localized)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 等级徽章

    private var tierBadge: some View {
        VStack(spacing: 8) {
            // 徽章图标
            ZStack {
                // 背景渐变
                Circle()
                    .fill(tierGradient)
                    .frame(width: 80, height: 80)

                // 图标
                Image(systemName: tierIcon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .shadow(color: tierColor.opacity(0.5), radius: 10, x: 0, y: 5)

            // 等级文字
            Text(result.tier.displayName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(tierColor)
        }
        .padding(.vertical, 8)
    }

    /// 等级对应的颜色
    private var tierColor: Color {
        switch result.tier {
        case .none:
            return .gray
        case .bronze:
            return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver:
            return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold:
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .diamond:
            return Color(red: 0.6, green: 0.4, blue: 0.9)
        }
    }

    /// 等级对应的渐变
    private var tierGradient: LinearGradient {
        switch result.tier {
        case .none:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bronze:
            return LinearGradient(colors: [Color(red: 0.9, green: 0.6, blue: 0.3), Color(red: 0.7, green: 0.4, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .silver:
            return LinearGradient(colors: [Color(red: 0.85, green: 0.85, blue: 0.9), Color(red: 0.6, green: 0.6, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gold:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.9, blue: 0.4), Color(red: 0.9, green: 0.7, blue: 0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .diamond:
            return LinearGradient(colors: [Color(red: 0.7, green: 0.5, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// 等级对应的图标
    private var tierIcon: String {
        switch result.tier {
        case .none:
            return "xmark.circle"
        case .bronze:
            return "medal.fill"
        case .silver:
            return "medal.fill"
        case .gold:
            return "medal.fill"
        case .diamond:
            return "diamond.fill"
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

                Text("探索统计".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            Divider()
                .background(ApocalypseTheme.textMuted)

            // 行走距离
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.info.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "figure.walk")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.info)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("本次行走".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(formatDistance(result.distance))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()
            }

            Divider()
                .background(ApocalypseTheme.textMuted)

            // 探索时长
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("探索时长".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(formatDuration(result.durationSeconds))
                        .font(.title2)
                        .fontWeight(.bold)
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

    // MARK: - 奖励物品卡片

    private var rewardsCard: some View {
        VStack(spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("获得物品".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 物品数量
                Text(String(format: "%d种".localized, result.items.count))
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
                ForEach(result.items) { item in
                    itemRow(item: item)
                        .opacity(itemsShown.contains(item.id) ? 1 : 0)
                        .offset(x: itemsShown.contains(item.id) ? 0 : -20)
                }
            }

            Divider()
                .background(ApocalypseTheme.textMuted)

            // 底部提示
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Text("已添加到背包".localized)
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
    private func itemRow(item: RewardItem) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor(item.category).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor(item.category))
            }

            // 物品名称
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 稀有度标签
                    Text(rarityDisplayName(item.rarity))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rarityColor(item.rarity).opacity(0.2))
                        .foregroundColor(rarityColor(item.rarity))
                        .cornerRadius(4)
                }

                Text(categoryDisplayName(item.category))
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .cornerRadius(10)

            // 对勾（从0开始缩放，随动画显示）
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScales[item.id] ?? 0)
                .opacity(itemsShown.contains(item.id) ? 1 : 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.headline)

                Text("确认".localized)
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
                Text("探索失败".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(result.failureReason ?? "速度过快，探索中断".localized)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // 确认按钮
            Button(action: {
                dismiss()
            }) {
                HStack {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.headline)

                    Text("返回".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(ApocalypseTheme.primary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Helper Methods

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f 公里".localized, meters / 1000)
        } else {
            return String(format: "%.0f 米".localized, meters)
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return String(format: "%d分%d秒".localized, minutes, secs)
        } else {
            return String(format: "%d秒".localized, secs)
        }
    }

    /// 分类对应的颜色
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "water":
            return .blue
        case "food":
            return .orange
        case "medical":
            return .red
        case "material":
            return .brown
        case "tool":
            return .cyan
        default:
            return .gray
        }
    }

    /// 分类显示名称
    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "water": return "水类".localized
        case "food": return "食物".localized
        case "medical": return "医疗".localized
        case "material": return "材料".localized
        case "tool": return "工具".localized
        default: return category
        }
    }

    /// 稀有度对应的颜色
    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "common":
            return .gray
        case "rare":
            return .blue
        case "epic":
            return .purple
        default:
            return .gray
        }
    }

    /// 稀有度显示名称
    private func rarityDisplayName(_ rarity: String) -> String {
        switch rarity {
        case "common": return "普通".localized
        case "rare": return "稀有".localized
        case "epic": return "史诗".localized
        default: return rarity
        }
    }
}

// MARK: - Preview

#Preview {
    ExplorationResultView(result: ExplorationResult(
        distance: 850,
        durationSeconds: 754,
        tier: .silver,
        items: [
            RewardItem(itemId: "water_bottle", name: "矿泉水", quantity: 2, rarity: "common", icon: "drop.fill", category: "water"),
            RewardItem(itemId: "canned_food", name: "罐头食品", quantity: 1, rarity: "common", icon: "fork.knife", category: "food")
        ],
        hasFailed: false,
        failureReason: nil
    ))
}
