//
//  TradeHistoryCardView.swift
//  new earth lord1
//
//  交易历史卡片视图
//  显示已完成交易的摘要信息
//

import SwiftUI

struct TradeHistoryCardView: View {
    let history: TradeHistory
    let currentUserId: UUID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 左侧：交易图标
                tradeIcon

                // 中间：交易信息
                VStack(alignment: .leading, spacing: 6) {
                    // 交易对象
                    HStack(spacing: 8) {
                        Text(tradePartnerName)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        roleBadge
                    }

                    // 物品交换摘要
                    exchangeSummary

                    // 完成时间
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        Text(history.formattedCompletedAt)
                            .font(.caption2)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)

                    // 评价状态
                    if canRate {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("可评价".localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(ApocalypseTheme.warning)
                    } else if hasMyRating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("已评价".localized)
                                .font(.caption2)
                        }
                        .foregroundColor(ApocalypseTheme.success)
                    }
                }

                Spacer()

                // 右侧：箭头
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 交易图标

    private var tradeIcon: some View {
        ZStack {
            Circle()
                .fill(ApocalypseTheme.success.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.success)
        }
    }

    // MARK: - 角色徽章

    private var roleBadge: some View {
        Text(isSeller ? "卖家".localized : "买家".localized)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(roleColor.opacity(0.2))
            .foregroundColor(roleColor)
            .cornerRadius(6)
    }

    // MARK: - 物品交换摘要

    private var exchangeSummary: some View {
        HStack(spacing: 8) {
            if isSeller {
                // 我是卖家：我给了 → 我收到
                Label("\(history.itemsExchanged.sellerGave.count) 件", systemImage: "arrow.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)

                Text("↔")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)

                Label("\(history.itemsExchanged.buyerGave.count) 件", systemImage: "arrow.left")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)
            } else {
                // 我是买家：我付了 → 我获得
                Label("\(history.itemsExchanged.buyerGave.count) 件", systemImage: "arrow.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)

                Text("↔")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)

                Label("\(history.itemsExchanged.sellerGave.count) 件", systemImage: "arrow.left")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)
            }
        }
    }

    // MARK: - 计算属性

    /// 是否为卖家
    private var isSeller: Bool {
        history.sellerId == currentUserId
    }

    /// 交易对象名称
    private var tradePartnerName: String {
        isSeller ? history.buyerUsername : history.sellerUsername
    }

    /// 角色颜色
    private var roleColor: Color {
        isSeller ? ApocalypseTheme.info : ApocalypseTheme.primary
    }

    /// 是否可以评价
    private var canRate: Bool {
        if isSeller {
            return history.sellerRating == nil
        } else {
            return history.buyerRating == nil
        }
    }

    /// 是否已评价
    private var hasMyRating: Bool {
        if isSeller {
            return history.sellerRating != nil
        } else {
            return history.buyerRating != nil
        }
    }
}

// MARK: - Preview

#Preview {
    let currentUserId = UUID()
    let otherUserId = UUID()

    return VStack(spacing: 12) {
        // 我是卖家，未评价
        TradeHistoryCardView(
            history: TradeHistory(
                id: UUID(),
                offerId: UUID(),
                sellerId: currentUserId,
                sellerUsername: "我",
                buyerId: otherUserId,
                buyerUsername: "玩家A",
                itemsExchanged: TradeExchangeInfo(
                    sellerGave: [TradeItem(itemId: "water", quantity: 5)],
                    buyerGave: [TradeItem(itemId: "wood", quantity: 10)]
                ),
                completedAt: Date(),
                sellerRating: nil,
                buyerRating: 5,
                sellerComment: nil,
                buyerComment: "很好的卖家"
            ),
            currentUserId: currentUserId,
            onTap: { print("Tapped") }
        )

        // 我是买家，已评价
        TradeHistoryCardView(
            history: TradeHistory(
                id: UUID(),
                offerId: UUID(),
                sellerId: otherUserId,
                sellerUsername: "玩家B",
                buyerId: currentUserId,
                buyerUsername: "我",
                itemsExchanged: TradeExchangeInfo(
                    sellerGave: [TradeItem(itemId: "food", quantity: 20)],
                    buyerGave: [TradeItem(itemId: "iron", quantity: 5)]
                ),
                completedAt: Date().addingTimeInterval(-3600 * 24),
                sellerRating: 4,
                buyerRating: 5,
                sellerComment: "交易愉快",
                buyerComment: "不错"
            ),
            currentUserId: currentUserId,
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
