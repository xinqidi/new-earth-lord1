//
//  BackpackView.swift
//  new earth lord1
//
//  背包管理页面
//  显示玩家携带的物品，支持搜索、筛选和物品操作
//

import SwiftUI

struct BackpackView: View {

    // MARK: - Environment Objects

    @EnvironmentObject private var authManager: AuthManager

    // MARK: - State Properties

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager()

    /// 搜索文本
    @State private var searchText = ""

    /// 当前选中的分类（nil表示"全部"）
    @State private var selectedCategory: String? = nil

    /// 列表加载完成标志
    @State private var itemsLoaded = false

    // MARK: - Computed Properties

    /// 筛选后的物品列表
    private var filteredItems: [InventoryDisplayItem] {
        return inventoryManager.filter(category: selectedCategory, searchText: searchText)
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        let percentage = inventoryManager.capacityPercentage
        if percentage < 0.7 {
            return ApocalypseTheme.success  // 绿色
        } else if percentage < 0.9 {
            return ApocalypseTheme.warning  // 黄色
        } else {
            return ApocalypseTheme.danger   // 红色
        }
    }

    /// 是否显示容量警告
    private var showCapacityWarning: Bool {
        return inventoryManager.capacityPercentage > 0.9
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
                if inventoryManager.isLoading {
                    loadingView
                } else if let error = inventoryManager.errorMessage {
                    errorView(message: error)
                } else {
                    itemList
                }
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 配置并加载背包
            if let userId = authManager.currentUser?.id {
                inventoryManager.configure(supabase: authManager.supabase, userId: userId)
                Task {
                    await inventoryManager.loadInventory()
                    await MainActor.run {
                        itemsLoaded = true
                    }
                }
            }
        }
        .refreshable {
            await inventoryManager.loadInventory()
        }
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)
            Text("加载背包中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - 错误视图

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.warning)
            Text(message)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                Task {
                    await inventoryManager.loadInventory()
                }
            }) {
                Text("重试")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            Spacer()
        }
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 容量文字
            HStack {
                Image(systemName: "backpack.fill")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量：\(inventoryManager.totalItemCount) / \(inventoryManager.maxCapacity)")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 百分比
                Text(String(format: "%.0f%%", inventoryManager.capacityPercentage * 100))
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
                        .frame(width: geometry.size.width * inventoryManager.capacityPercentage, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: inventoryManager.capacityPercentage)
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
                categoryButton(title: "食物", icon: "fork.knife", category: "food")
                categoryButton(title: "水", icon: "drop.fill", category: "water")
                categoryButton(title: "材料", icon: "hammer.fill", category: "material")
                categoryButton(title: "工具", icon: "wrench.fill", category: "tool")
                categoryButton(title: "医疗", icon: "cross.fill", category: "medical")
            }
            .padding(.horizontal)
        }
    }

    /// 分类按钮
    private func categoryButton(title: String, icon: String, category: String?) -> some View {
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
                        BackpackItemCardView(item: item, inventoryManager: inventoryManager)
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
    }

    /// 空状态视图
    private var emptyState: some View {
        VStack(spacing: 16) {
            // 图标
            Image(systemName: inventoryManager.items.isEmpty ? "backpack" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(inventoryManager.items.isEmpty ? "背包空空如也" : "没有找到相关物品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(inventoryManager.items.isEmpty ? "去探索收集物资吧" : "尝试其他搜索关键词或分类")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Item Card View

/// 背包物品卡片视图
struct BackpackItemCardView: View {
    let item: InventoryDisplayItem
    @ObservedObject var inventoryManager: InventoryManager

    // MARK: - State

    /// 显示使用确认弹窗
    @State private var showUseConfirmation = false

    /// 显示丢弃弹窗
    @State private var showDiscardSheet = false

    /// 丢弃数量
    @State private var discardQuantity = 1

    /// 操作中状态
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：物品图标
            itemIcon

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 物品名称 + 稀有度标签
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    rarityBadge
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
                HStack(spacing: 4) {
                    Image(systemName: "scalemass.fill")
                        .font(.caption2)
                    Text(String(format: "%.1fkg", item.weight * Double(item.quantity)))
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)

                // 品质（如果有）
                if let quality = item.quality {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("品质：\(quality)")
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
                    showUseConfirmation = true
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
                .disabled(isProcessing)

                // 丢弃按钮
                Button(action: {
                    discardQuantity = 1
                    showDiscardSheet = true
                }) {
                    Text("丢弃")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
        .opacity(isProcessing ? 0.6 : 1.0)
        // 使用确认弹窗
        .alert("使用物品", isPresented: $showUseConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认使用") {
                handleUseItem()
            }
        } message: {
            Text("确定要使用 \(item.name) 吗？")
        }
        // 丢弃弹窗（带数量选择）
        .sheet(isPresented: $showDiscardSheet) {
            DiscardItemSheet(
                item: item,
                quantity: $discardQuantity,
                onConfirm: {
                    handleDiscardItem(quantity: discardQuantity)
                },
                onCancel: {
                    showDiscardSheet = false
                }
            )
            .presentationDetents([.height(320)])
        }
    }

    // MARK: - 物品图标

    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: item.icon)
                .font(.system(size: 22))
                .foregroundColor(categoryColor)
        }
    }

    /// 分类对应的颜色
    private var categoryColor: Color {
        switch item.category {
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

    // MARK: - 稀有度标签

    private var rarityBadge: some View {
        Text(item.rarityDisplayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(rarityColor.opacity(0.2))
            .foregroundColor(rarityColor)
            .cornerRadius(6)
    }

    /// 稀有度对应的颜色
    private var rarityColor: Color {
        switch item.rarity {
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

    /// 品质对应的颜色
    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "poor":
            return .red
        case "normal":
            return ApocalypseTheme.textSecondary
        case "good":
            return .green
        case "excellent":
            return .cyan
        default:
            return ApocalypseTheme.textSecondary
        }
    }

    // MARK: - Actions

    /// 使用物品
    private func handleUseItem() {
        print("🎒 [背包] 使用物品: \(item.name)")
        isProcessing = true
        Task {
            await inventoryManager.useItem(itemId: item.itemId)
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    /// 丢弃物品
    private func handleDiscardItem(quantity: Int) {
        print("🎒 [背包] 丢弃物品: \(item.name) x\(quantity)")
        showDiscardSheet = false
        isProcessing = true
        Task {
            do {
                try await inventoryManager.removeItem(itemId: item.itemId, quantity: quantity)
            } catch {
                print("❌ [背包] 丢弃物品失败: \(error.localizedDescription)")
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

// MARK: - Discard Item Sheet

/// 丢弃物品弹窗
struct DiscardItemSheet: View {
    let item: InventoryDisplayItem
    @Binding var quantity: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 物品信息
                HStack(spacing: 16) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: item.icon)
                            .font(.system(size: 28))
                            .foregroundColor(categoryColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("当前持有：\(item.quantity) 个")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                Divider()

                // 数量选择
                VStack(spacing: 12) {
                    Text("选择丢弃数量")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    HStack(spacing: 20) {
                        // 减少按钮
                        Button(action: {
                            if quantity > 1 {
                                quantity -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        }
                        .disabled(quantity <= 1)

                        // 数量显示
                        Text("\(quantity)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .frame(width: 80)

                        // 增加按钮
                        Button(action: {
                            if quantity < item.quantity {
                                quantity += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(quantity < item.quantity ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        }
                        .disabled(quantity >= item.quantity)
                    }

                    // 快捷按钮
                    if item.quantity > 1 {
                        HStack(spacing: 12) {
                            quickSelectButton(amount: 1, label: "1个")
                            if item.quantity >= 5 {
                                quickSelectButton(amount: 5, label: "5个")
                            }
                            if item.quantity >= 10 {
                                quickSelectButton(amount: 10, label: "10个")
                            }
                            quickSelectButton(amount: item.quantity, label: "全部")
                        }
                    }
                }

                Spacer()

                // 确认按钮
                Button(action: onConfirm) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("确认丢弃 \(quantity) 个")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ApocalypseTheme.danger)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
            .background(ApocalypseTheme.background)
            .navigationTitle("丢弃物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    /// 快捷选择按钮
    private func quickSelectButton(amount: Int, label: String) -> some View {
        Button(action: {
            quantity = min(amount, item.quantity)
        }) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(quantity == amount ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(quantity == amount ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                .cornerRadius(8)
        }
    }

    /// 分类对应的颜色
    private var categoryColor: Color {
        switch item.category {
        case "water": return .blue
        case "food": return .orange
        case "medical": return .red
        case "material": return .brown
        case "tool": return .cyan
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        BackpackView()
            .environmentObject(AuthManager())
    }
}
