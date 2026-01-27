//
//  MarketOffersListView.swift
//  new earth lord1
//
//  市场挂单列表视图
//  浏览其他玩家的活跃挂单
//

import SwiftUI

struct MarketOffersListView: View {
    @StateObject private var tradeManager = TradeManager.shared

    // MARK: - State Properties

    /// 选中的挂单（用于显示详情）
    @State private var selectedOffer: TradeOffer? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if tradeManager.isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .refreshable {
            await tradeManager.fetchMarketOffers()
        }
        .sheet(item: $selectedOffer) { offer in
            TradeOfferDetailView(offer: offer, mode: .accept)
        }
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载市场挂单中...".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 内容视图

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if tradeManager.marketOffers.isEmpty {
                    EmptyTradeStateView(
                        icon: "cart",
                        title: "市场空空如也",
                        description: "还没有玩家发布交易挂单"
                    )
                } else {
                    ForEach(tradeManager.marketOffers) { offer in
                        TradeOfferCardView(offer: offer, mode: .market) {
                            selectedOffer = offer
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    MarketOffersListView()
        .environmentObject(InventoryManager())
}
