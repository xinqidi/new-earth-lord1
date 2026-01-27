//
//  TradeOfferCardView.swift
//  new earth lord1
//
//  交易挂单卡片视图
//  显示交易挂单的摘要信息，点击后显示详情
//

import SwiftUI

struct TradeOfferCardView: View {
    let offer: TradeOffer
    let mode: DisplayMode
    let onTap: () -> Void

    enum DisplayMode {
        case market    // 市场挂单（其他玩家）
        case myOffer   // 我的挂单
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 左侧：用户头像
                userAvatar

                // 中间：挂单信息
                VStack(alignment: .leading, spacing: 6) {
                    // 用户名 + 状态徽章
                    HStack(spacing: 8) {
                        Text(offer.ownerUsername)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        StatusBadgeView(status: offer.status)
                    }

                    // 物品预览
                    itemsSummary

                    // 剩余时间或发布时间
                    timeInfo
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

    // MARK: - 用户头像

    private var userAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: "person.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.blue)
        }
    }

    // MARK: - 物品摘要

    private var itemsSummary: some View {
        HStack(spacing: 8) {
            // 提供的物品数量
            Label("\(offer.offeringItems.count) 件", systemImage: "arrow.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.success)

            Text("↔")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)

            // 需要的物品数量
            Label("\(offer.requestingItems.count) 件", systemImage: "arrow.left")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.warning)
        }
    }

    // MARK: - 时间信息

    private var timeInfo: some View {
        Group {
            if offer.status == .active {
                // 活跃状态：显示剩余时间
                if offer.isExpired {
                    Text("已过期".localized)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.danger)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("剩余 \(offer.formattedRemainingTime)")
                            .font(.caption2)
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)
                }
            } else {
                // 其他状态：显示发布时间
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(offer.formattedCreatedAt)
                        .font(.caption2)
                }
                .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        TradeOfferCardView(
            offer: TradeOffer(
                id: UUID(),
                ownerId: UUID(),
                ownerUsername: "玩家A",
                offeringItems: [
                    TradeItem(itemId: "water", quantity: 5),
                    TradeItem(itemId: "food", quantity: 3)
                ],
                requestingItems: [
                    TradeItem(itemId: "wood", quantity: 10)
                ],
                status: .active,
                message: "急需木材",
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(3600 * 24),
                completedAt: nil,
                completedByUserId: nil,
                completedByUsername: nil
            ),
            mode: .market,
            onTap: { print("Tapped") }
        )

        TradeOfferCardView(
            offer: TradeOffer(
                id: UUID(),
                ownerId: UUID(),
                ownerUsername: "我",
                offeringItems: [
                    TradeItem(itemId: "stone", quantity: 20)
                ],
                requestingItems: [
                    TradeItem(itemId: "iron", quantity: 5)
                ],
                status: .completed,
                message: nil,
                createdAt: Date().addingTimeInterval(-3600 * 48),
                expiresAt: nil,
                completedAt: Date().addingTimeInterval(-3600 * 24),
                completedByUserId: UUID(),
                completedByUsername: "玩家B"
            ),
            mode: .myOffer,
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
