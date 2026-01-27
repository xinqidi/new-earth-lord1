//
//  MyOffersListView.swift
//  new earth lord1
//
//  我的挂单列表视图
//  查看和管理自己发布的挂单
//

import SwiftUI

struct MyOffersListView: View {
    @StateObject private var tradeManager = TradeManager.shared

    // MARK: - State Properties

    /// 选中的挂单（用于显示详情）
    @State private var selectedOffer: TradeOffer? = nil

    /// 显示创建挂单视图
    @State private var showCreateOffer = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 背景和内容
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                contentView
            }
            .refreshable {
                await tradeManager.fetchMyOffers()
            }
            .sheet(item: $selectedOffer) { offer in
                TradeOfferDetailView(offer: offer, mode: .cancel)
            }
            .sheet(isPresented: $showCreateOffer) {
                CreateOfferView()
            }

            // 浮动按钮（始终显示）
            floatingActionButton
        }
    }

    // MARK: - 内容视图

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if tradeManager.myOffers.isEmpty {
                    EmptyTradeStateView(
                        icon: "doc.text",
                        title: "还没有挂单",
                        description: "点击右下角按钮发布你的第一个挂单"
                    )
                } else {
                    ForEach(tradeManager.myOffers) { offer in
                        TradeOfferCardView(offer: offer, mode: .myOffer) {
                            selectedOffer = offer
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 80) // 为浮动按钮留出空间
        }
    }

    // MARK: - 浮动按钮

    private var floatingActionButton: some View {
        Button(action: {
            showCreateOffer = true
        }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(ApocalypseTheme.primary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(20)
    }
}

// MARK: - Preview

#Preview {
    MyOffersListView()
        .environmentObject(InventoryManager())
}
