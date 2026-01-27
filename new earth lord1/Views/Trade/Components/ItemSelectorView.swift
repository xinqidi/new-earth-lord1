//
//  ItemSelectorView.swift
//  new earth lord1
//
//  物品选择器视图
//  支持两种模式：从背包选择（数量受限）或从所有物品选择（无限制）
//

import SwiftUI

struct ItemSelectorView: View {
    let mode: SelectionMode
    let onSelect: (String, Int) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State Properties

    /// 搜索文本
    @State private var searchText = ""

    /// 当前选中的分类（nil表示"全部"）
    @State private var selectedCategory: String? = nil

    /// 显示数量选择器
    @State private var showQuantityPicker = false

    /// 选中的物品ID
    @State private var selectedItemId: String? = nil

    /// 选择的数量
    @State private var selectedQuantity = 1

    /// 最大可选数量
    @State private var maxQuantity = 1

    // MARK: - Selection Mode

    enum SelectionMode {
        case fromInventory  // 从背包选择（数量受限）
        case allItems       // 从所有物品选择（无限制）
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
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
            .navigationTitle(mode == .fromInventory ? "从背包选择".localized : "选择物品".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消".localized) {
                        onCancel()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showQuantityPicker) {
                quantityPickerSheet
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...".localized, text: $searchText)
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
                categoryButton(title: "全部".localized, icon: "square.grid.2x2.fill", category: nil)

                // 各分类按钮
                categoryButton(title: "食物".localized, icon: "fork.knife", category: "food")
                categoryButton(title: "水".localized, icon: "drop.fill", category: "water")
                categoryButton(title: "材料".localized, icon: "hammer.fill", category: "material")
                categoryButton(title: "工具".localized, icon: "wrench.fill", category: "tool")
                categoryButton(title: "医疗".localized, icon: "cross.fill", category: "medical")
            }
            .padding(.horizontal)
        }
    }

    /// 分类按钮
    private func categoryButton(title: String, icon: String, category: String?) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
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
                    EmptyTradeStateView(
                        icon: "magnifyingglass",
                        title: "没有找到物品",
                        description: "尝试其他搜索关键词或分类"
                    )
                } else {
                    ForEach(filteredItems, id: \.itemId) { item in
                        itemRow(item: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    /// 物品行
    private func itemRow(item: ItemDisplayInfo) -> some View {
        Button(action: {
            handleItemSelection(item)
        }) {
            HStack(spacing: 12) {
                // 物品图标
                ZStack {
                    Circle()
                        .fill(item.categoryColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundColor(item.categoryColor)
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if mode == .fromInventory {
                        Text("当前持有：\(item.availableQuantity) 个".localized)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 数量选择器 Sheet

    private var quantityPickerSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 物品信息
                    if let itemId = selectedItemId,
                       let item = filteredItems.first(where: { $0.itemId == itemId }) {

                        // 物品卡片
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(item.categoryColor.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: item.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(item.categoryColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                if mode == .fromInventory {
                                    Text("当前持有：\(item.availableQuantity) 个".localized)
                                        .font(.subheadline)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                            }

                            Spacer()
                        }
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Divider()

                    // 数量选择
                    VStack(spacing: 12) {
                        Text("选择数量".localized)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        HStack(spacing: 20) {
                            // 减少按钮
                            Button(action: {
                                if selectedQuantity > 1 {
                                    selectedQuantity -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(selectedQuantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            }
                            .disabled(selectedQuantity <= 1)

                            // 数量显示
                            Text("\(selectedQuantity)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .frame(width: 80)

                            // 增加按钮
                            Button(action: {
                                if selectedQuantity < maxQuantity {
                                    selectedQuantity += 1
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(selectedQuantity < maxQuantity ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            }
                            .disabled(selectedQuantity >= maxQuantity)
                        }

                        // 快捷按钮
                        if maxQuantity > 1 {
                            HStack(spacing: 12) {
                                quantityQuickButton(amount: 1, label: "1个")
                                if maxQuantity >= 5 {
                                    quantityQuickButton(amount: 5, label: "5个")
                                }
                                if maxQuantity >= 10 {
                                    quantityQuickButton(amount: 10, label: "10个")
                                }
                                if mode == .fromInventory {
                                    quantityQuickButton(amount: maxQuantity, label: "全部")
                                }
                            }
                        }
                    }

                    Spacer()

                    // 确认按钮
                    Button(action: confirmSelection) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("确认添加".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
            }
            .navigationTitle("选择数量".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消".localized) {
                        showQuantityPicker = false
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.height(450)])
    }

    /// 快捷数量按钮
    private func quantityQuickButton(amount: Int, label: String) -> some View {
        Button(action: {
            selectedQuantity = min(amount, maxQuantity)
        }) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(selectedQuantity == amount ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedQuantity == amount ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                .cornerRadius(8)
        }
    }

    // MARK: - 筛选后的物品列表

    private var filteredItems: [ItemDisplayInfo] {
        var items: [ItemDisplayInfo] = []

        switch mode {
        case .fromInventory:
            // 从背包物品构建
            items = inventoryManager.items.compactMap { inventoryItem in
                guard let definition = inventoryManager.itemDefinitions[inventoryItem.itemId] else {
                    return nil
                }
                return ItemDisplayInfo(
                    itemId: inventoryItem.itemId,
                    name: definition.name,
                    icon: definition.icon ?? "questionmark",
                    category: definition.category,
                    availableQuantity: inventoryItem.quantity
                )
            }

        case .allItems:
            // 从所有物品定义构建
            items = inventoryManager.itemDefinitions.values.map { definition in
                ItemDisplayInfo(
                    itemId: definition.id,
                    name: definition.name,
                    icon: definition.icon ?? "questionmark",
                    category: definition.category,
                    availableQuantity: 999 // 无限制
                )
            }
        }

        // 分类筛选
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.itemId.localizedCaseInsensitiveContains(searchText) }
        }

        return items.sorted { $0.name < $1.name }
    }

    // MARK: - Actions

    /// 处理物品选择
    private func handleItemSelection(_ item: ItemDisplayInfo) {
        selectedItemId = item.itemId
        selectedQuantity = 1
        maxQuantity = item.availableQuantity
        showQuantityPicker = true
    }

    /// 确认选择
    private func confirmSelection() {
        guard let itemId = selectedItemId else { return }
        showQuantityPicker = false

        // 延迟关闭主 Sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSelect(itemId, selectedQuantity)
        }
    }
}

// MARK: - Item Display Info

/// 物品显示信息
struct ItemDisplayInfo {
    let itemId: String
    let name: String
    let icon: String
    let category: String
    let availableQuantity: Int

    /// 分类对应的颜色
    var categoryColor: Color {
        switch category {
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
    ItemSelectorView(
        mode: .fromInventory,
        onSelect: { itemId, quantity in
            print("Selected: \(itemId) x\(quantity)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .environmentObject(InventoryManager())
}
