//
//  TradeHistoryListView.swift
//  new earth lord1
//
//  交易历史列表视图
//  查看已完成的交易记录
//

import SwiftUI

struct TradeHistoryListView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @EnvironmentObject var authManager: AuthManager

    // MARK: - State Properties

    /// 选中的历史记录（用于评价）
    @State private var selectedHistory: TradeHistory? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            contentView
        }
        .refreshable {
            await tradeManager.fetchTradeHistory()
        }
        .sheet(item: $selectedHistory) { history in
            // 检查是否可以评价
            if canRate(history) {
                RatingView(history: history)
            } else {
                // 显示详情（不可评价）
                historyDetailView(history: history)
            }
        }
    }

    // MARK: - 内容视图

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if tradeManager.tradeHistory.isEmpty {
                    EmptyTradeStateView(
                        icon: "clock.arrow.circlepath",
                        title: "暂无交易历史",
                        description: "完成交易后会显示在这里"
                    )
                } else {
                    ForEach(tradeManager.tradeHistory) { history in
                        TradeHistoryCardView(
                            history: history,
                            currentUserId: authManager.currentUser?.id ?? UUID(),
                            onTap: {
                                selectedHistory = history
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 历史详情视图（只读）

    private func historyDetailView(history: TradeHistory) -> some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 交易信息
                        tradeInfoCard(history: history)

                        // 交换物品
                        exchangeItemsCard(history: history)

                        // 评价信息
                        if history.sellerRating != nil || history.buyerRating != nil {
                            ratingsCard(history: history)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("交易详情".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭".localized) {
                        selectedHistory = nil
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    /// 交易信息卡片
    private func tradeInfoCard(history: TradeHistory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交易信息".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            infoRow(label: "卖家", value: history.sellerUsername)
            infoRow(label: "买家", value: history.buyerUsername)
            infoRow(label: "完成时间", value: history.formattedCompletedAt)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 交换物品卡片
    private func exchangeItemsCard(history: TradeHistory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("交换物品".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 卖家提供
            VStack(alignment: .leading, spacing: 8) {
                Text("卖家提供".localized)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                ForEach(history.itemsExchanged.sellerGave, id: \.itemId) { item in
                    TradeItemRowView(item: item, mode: .display)
                }
            }

            Divider()

            // 买家提供
            VStack(alignment: .leading, spacing: 8) {
                Text("买家提供".localized)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                ForEach(history.itemsExchanged.buyerGave, id: \.itemId) { item in
                    TradeItemRowView(item: item, mode: .display)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 评价卡片
    private func ratingsCard(history: TradeHistory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("评价".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 卖家评价
            if let rating = history.sellerRating {
                ratingRow(
                    role: "卖家评价",
                    rating: rating,
                    comment: history.sellerComment
                )
            }

            if history.sellerRating != nil && history.buyerRating != nil {
                Divider()
            }

            // 买家评价
            if let rating = history.buyerRating {
                ratingRow(
                    role: "买家评价",
                    rating: rating,
                    comment: history.buyerComment
                )
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 评价行
    private func ratingRow(role: String, rating: Int, comment: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(role.localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(star <= rating ? .yellow : ApocalypseTheme.textMuted)
                }
            }

            if let comment = comment, !comment.isEmpty {
                Text(comment)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(8)
            }
        }
    }

    /// 信息行
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label.localized + ":")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - Helper Methods

    /// 检查是否可以评价
    private func canRate(_ history: TradeHistory) -> Bool {
        guard let userId = authManager.currentUser?.id else { return false }

        if history.sellerId == userId {
            return history.sellerRating == nil
        } else if history.buyerId == userId {
            return history.buyerRating == nil
        }

        return false
    }
}

// MARK: - Preview

#Preview {
    TradeHistoryListView()
        .environmentObject(AuthManager())
        .environmentObject(InventoryManager())
}
