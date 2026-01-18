//
//  ScavengeResultView.swift
//  new earth lord1
//
//  搜刮结果展示页面
//

import SwiftUI
import CoreLocation

/// 搜刮结果
struct ScavengeResult: Identifiable {
    let id = UUID()
    let poi: POI
    let items: [RewardItem]
}

/// 搜刮结果视图
struct ScavengeResultView: View {

    /// 搜刮结果
    let result: ScavengeResult

    /// 确认回调
    let onConfirm: () -> Void

    /// 是否显示动画
    @State private var showItems = false

    /// 展开的物品ID（显示故事）
    @State private var expandedItemIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            VStack(spacing: 12) {
                // 成功图标
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)

                Text("搜刮成功！".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // POI名称和危险等级
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.subheadline)
                        Text(result.poi.name)
                            .font(.subheadline)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)

                    // 危险等级标签
                    Text(result.poi.dangerLevel.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(dangerLevelColor(result.poi.dangerLevel))
                        .cornerRadius(4)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 获得物品区域
            VStack(alignment: .leading, spacing: 12) {
                Text("获得物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if result.items.isEmpty {
                    // 没有找到物品
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.gray)
                        Text("这里已经被搜刮过了，没有找到任何物品")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(8)
                } else {
                    // 物品列表（可展开显示故事）
                    ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            // 物品主行
                            HStack {
                                // 物品图标
                                Image(systemName: item.icon)
                                    .font(.title3)
                                    .foregroundColor(rarityColor(item.rarity))
                                    .frame(width: 36, height: 36)
                                    .background(rarityColor(item.rarity).opacity(0.15))
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text(rarityDisplayName(item.rarity))
                                        .font(.caption)
                                        .foregroundColor(rarityColor(item.rarity))
                                }

                                Spacer()

                                // 数量
                                Text("x\(item.quantity)")
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                // 展开指示器（如果有故事）
                                if item.story != nil {
                                    Image(systemName: expandedItemIds.contains(item.id) ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if item.story != nil {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedItemIds.contains(item.id) {
                                            expandedItemIds.remove(item.id)
                                        } else {
                                            expandedItemIds.insert(item.id)
                                        }
                                    }
                                }
                            }

                            // 物品故事（展开显示）
                            if let story = item.story, expandedItemIds.contains(item.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Divider()
                                        .background(ApocalypseTheme.textSecondary.opacity(0.2))
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "book.fill")
                                            .font(.caption)
                                            .foregroundColor(ApocalypseTheme.textSecondary)
                                        Text(story)
                                            .font(.caption)
                                            .foregroundColor(ApocalypseTheme.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 12)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(ApocalypseTheme.background)
                        .cornerRadius(8)
                        .opacity(showItems ? 1 : 0)
                        .offset(y: showItems ? 0 : 20)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                                .delay(Double(index) * 0.1),
                            value: showItems
                        )
                    }
                }
            }
            .padding()

            Spacer()

            // 确认按钮
            Button(action: onConfirm) {
                Text("确认")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .padding()
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .padding(.horizontal, 24)
        .padding(.vertical, 50)
        .onAppear {
            // 延迟显示动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showItems = true
            }
        }
    }

    // MARK: - Helper Methods

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common":
            return .gray
        case "uncommon":
            return .green
        case "rare":
            return .blue
        case "epic":
            return .purple
        case "legendary":
            return .orange
        default:
            return .gray
        }
    }

    private func rarityDisplayName(_ rarity: String) -> String {
        switch rarity.lowercased() {
        case "common":
            return "稀有度.普通".localized
        case "uncommon":
            return "稀有度.优秀".localized
        case "rare":
            return "稀有度.稀有".localized
        case "epic":
            return "稀有度.史诗".localized
        case "legendary":
            return "稀有度.传奇".localized
        default:
            return rarity
        }
    }

    private func dangerLevelColor(_ level: DangerLevel) -> Color {
        switch level {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .extreme:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)

        ScavengeResultView(
            result: ScavengeResult(
                poi: POI(
                    name: "废弃的华联超市",
                    type: .supermarket,
                    coordinate: .init(latitude: 39.9, longitude: 116.4),
                    status: .looted,
                    distance: 32,
                    description: "一座废弃的超市"
                ),
                items: [
                    RewardItem(itemId: "water_bottle", name: "矿泉水", quantity: 2, rarity: "common", icon: "drop.fill", category: "water"),
                    RewardItem(itemId: "canned_food", name: "罐头食品", quantity: 1, rarity: "common", icon: "fork.knife", category: "food"),
                    RewardItem(itemId: "medicine", name: "药品", quantity: 1, rarity: "rare", icon: "pills.fill", category: "medical")
                ]
            ),
            onConfirm: {}
        )
    }
}
