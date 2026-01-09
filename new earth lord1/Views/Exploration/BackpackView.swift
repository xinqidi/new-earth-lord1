//
//  BackpackView.swift
//  new earth lord1
//
//  背包管理页面
//  显示玩家携带的物品，支持搜索、筛选和物品操作
//

import SwiftUI

struct BackpackView: View {

    // MARK: - State Properties

    /// 搜索文本
    @State private var searchText = ""

    /// 当前选中的分类（nil表示"全部"）
    @State private var selectedCategory: ItemCategory? = nil

    /// 所有背包物品
    @State private var backpackItems: [BackpackItem] = MockExplorationData.mockBackpackItems

    /// 列表加载完成标志
    @State private var itemsLoaded = false

    /// 背包最大容量（个数）
    private let maxCapacity = 100

    // MARK: - Computed Properties

    /// 当前背包物品总数
    private var currentCapacity: Int {
        return backpackItems.reduce(0) { $0 + $1.quantity }
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        return Double(currentCapacity) / Double(maxCapacity)
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage < 0.7 {
            return ApocalypseTheme.success  // 绿色
        } else if capacityPercentage < 0.9 {
            return ApocalypseTheme.warning  // 黄色
        } else {
            return ApocalypseTheme.danger   // 红色
        }
    }

    /// 是否显示容量警告
    private var showCapacityWarning: Bool {
        return capacityPercentage > 0.9
    }

    /// 筛选后的物品列表
    private var filteredItems: [BackpackItem] {
        var items = backpackItems

        // 按分类筛选
        if let category = selectedCategory {
            items = items.filter { item in
                if let definition = MockExplorationData.getItemDefinition(for: item.itemId) {
                    return definition.category == category
                }
                return false
            }
        }

        // 按搜索文本筛选
        if !searchText.isEmpty {
            items = items.filter { item in
                if let definition = MockExplorationData.getItemDefinition(for: item.itemId) {
                    return definition.name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }

        return items
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                // 搜索框
                searchBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // 分类筛选
                categoryFilter
                    .padding(.vertical, 8)

                // 物品列表
                itemList
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 容量文字
            HStack {
                Image(systemName: "backpack.fill")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量：\(currentCapacity) / \(maxCapacity)")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 百分比
                Text(String(format: "%.0f%%", capacityPercentage * 100))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(capacityColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    Rectangle()
                        .fill(ApocalypseTheme.cardBackground)
                        .frame(height: 8)
                        .cornerRadius(4)

                    // 进度
                    Rectangle()
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * capacityPercentage, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: capacityPercentage)
                        .animation(.easeInOut(duration: 0.3), value: capacityColor)
                }
            }
            .frame(height: 8)

            // 警告提示
            if showCapacityWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.danger)

                    Text("背包快满了！")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.danger)

                    Spacer()
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocapitalization(.none)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部"按钮
                categoryButton(title: "全部", icon: "square.grid.2x2.fill", category: nil)

                // 各分类按钮
                categoryButton(title: "食物", icon: "fork.knife", category: .food)
                categoryButton(title: "水", icon: "drop.fill", category: .water)
                categoryButton(title: "材料", icon: "hammer.fill", category: .material)
                categoryButton(title: "工具", icon: "wrench.fill", category: .tool)
                categoryButton(title: "医疗", icon: "cross.fill", category: .medical)
            }
            .padding(.horizontal)
        }
    }

    /// 分类按钮
    private func categoryButton(title: String, icon: String, category: ItemCategory?) -> some View {
        Button(action: {
            // 先隐藏列表，再切换分类，最后重新显示
            itemsLoaded = false
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
            // 延迟后重新加载列表动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                itemsLoaded = true
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                selectedCategory == category
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.cardBackground
            )
            .foregroundColor(
                selectedCategory == category
                    ? .white
                    : ApocalypseTheme.textSecondary
            )
            .cornerRadius(20)
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredItems.isEmpty {
                    // 空状态
                    emptyState
                } else {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        ItemCardView(item: item)
                            .opacity(itemsLoaded ? 1 : 0)
                            .offset(y: itemsLoaded ? 0 : 20)
                            .animation(
                                .easeOut(duration: 0.4)
                                    .delay(Double(index) * 0.08),
                                value: itemsLoaded
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onAppear {
            if !itemsLoaded {
                itemsLoaded = true
            }
        }
    }

    /// 空状态视图
    private var emptyState: some View {
        VStack(spacing: 16) {
            // 图标
            Image(systemName: backpackItems.isEmpty ? "backpack" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(backpackItems.isEmpty ? "背包空空如也" : "没有找到相关物品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(backpackItems.isEmpty ? "去探索收集物资吧" : "尝试其他搜索关键词或分类")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Item Card View

/// 物品卡片视图
struct ItemCardView: View {
    let item: BackpackItem

    /// 物品定义
    private var itemDefinition: ItemDefinition? {
        MockExplorationData.getItemDefinition(for: item.itemId)
    }

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：物品图标
            itemIcon

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 物品名称 + 稀有度标签
                HStack(spacing: 8) {
                    Text(itemDefinition?.name ?? "未知物品")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if let rarity = itemDefinition?.rarity {
                        rarityBadge(rarity)
                    }
                }

                // 数量
                HStack(spacing: 4) {
                    Image(systemName: "cube.box.fill")
                        .font(.caption2)
                    Text("x\(item.quantity)")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)

                // 重量
                if let definition = itemDefinition {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass.fill")
                            .font(.caption2)
                        Text(String(format: "%.1fkg", definition.weight * Double(item.quantity)))
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 品质（如果有）
                if let quality = item.quality {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("品质：\(quality.rawValue)")
                            .font(.caption)
                    }
                    .foregroundColor(qualityColor(quality))
                }
            }

            Spacer()

            // 右侧：操作按钮
            VStack(spacing: 8) {
                // 使用按钮
                Button(action: {
                    handleUseItem()
                }) {
                    Text("使用")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(8)
                }

                // 存储按钮
                Button(action: {
                    handleStoreItem()
                }) {
                    Text("存储")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }

    // MARK: - 物品图标

    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: categoryIconName)
                .font(.system(size: 22))
                .foregroundColor(categoryColor)
        }
    }

    /// 分类对应的颜色
    private var categoryColor: Color {
        guard let definition = itemDefinition else { return .gray }

        switch definition.category {
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
    private var categoryIconName: String {
        guard let definition = itemDefinition else { return "questionmark" }

        switch definition.category {
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

    // MARK: - 稀有度标签

    private func rarityBadge(_ rarity: ItemRarity) -> some View {
        Text(rarity.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(rarityColor(rarity).opacity(0.2))
            .foregroundColor(rarityColor(rarity))
            .cornerRadius(6)
    }

    /// 稀有度对应的颜色
    private func rarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common:
            return .gray        // 普通：灰色
        case .uncommon:
            return .green       // 罕见：绿色
        case .rare:
            return .blue        // 稀有：蓝色
        case .epic:
            return .purple      // 史诗：紫色
        }
    }

    /// 品质对应的颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .poor:
            return .red
        case .normal:
            return ApocalypseTheme.textSecondary
        case .good:
            return .green
        case .excellent:
            return .cyan
        }
    }

    // MARK: - Actions

    /// 使用物品
    private func handleUseItem() {
        print("🎒 [背包] 使用物品: \(itemDefinition?.name ?? "未知")")
        // TODO: 实现使用物品逻辑
    }

    /// 存储物品
    private func handleStoreItem() {
        print("🎒 [背包] 存储物品: \(itemDefinition?.name ?? "未知")")
        // TODO: 实现存储物品逻辑
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        BackpackView()
    }
}
