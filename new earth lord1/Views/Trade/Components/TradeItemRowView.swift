//
//  TradeItemRowView.swift
//  new earth lord1
//
//  交易物品行视图
//  显示单个交易物品，支持编辑模式（可删除）
//

import SwiftUI

struct TradeItemRowView: View {
    let item: TradeItem
    let mode: DisplayMode
    let onRemove: (() -> Void)?

    @EnvironmentObject var inventoryManager: InventoryManager

    enum DisplayMode {
        case display    // 仅展示
        case editable   // 可编辑（显示删除按钮）
    }

    init(item: TradeItem, mode: DisplayMode = .display, onRemove: (() -> Void)? = nil) {
        self.item = item
        self.mode = mode
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            itemIcon

            // 物品名称和数量
            VStack(alignment: .leading, spacing: 4) {
                Text(itemName)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("x\(item.quantity)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 删除按钮（编辑模式）
            if mode == .editable, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.danger)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - 物品图标

    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 40, height: 40)

            Image(systemName: itemIcon_)
                .font(.system(size: 18))
                .foregroundColor(categoryColor)
        }
    }

    // MARK: - 计算属性

    /// 物品定义
    private var itemDefinition: DBItemDefinition? {
        inventoryManager.itemDefinitions[item.itemId]
    }

    /// 物品名称
    private var itemName: String {
        itemDefinition?.name ?? item.itemId
    }

    /// 物品图标
    private var itemIcon_: String {
        itemDefinition?.icon ?? "questionmark"
    }

    /// 分类对应的颜色
    private var categoryColor: Color {
        guard let category = itemDefinition?.category else { return .gray }

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
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        TradeItemRowView(
            item: TradeItem(itemId: "water", quantity: 5),
            mode: .display
        )

        TradeItemRowView(
            item: TradeItem(itemId: "food", quantity: 10),
            mode: .editable,
            onRemove: { print("Remove") }
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
    .environmentObject(InventoryManager())
}
