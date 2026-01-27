//
//  TradeMainView.swift
//  new earth lord1
//
//  交易系统主视图
//  包含市场、我的挂单、历史三个标签页
//

import SwiftUI

struct TradeMainView: View {
    @StateObject private var tradeManager = TradeManager.shared

    // MARK: - State Properties

    /// 当前选中的标签
    @State private var selectedTab: TradeTab = .market

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 分段控件
            segmentedPicker
                .padding()

            // 内容区域
            contentView
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            // 首次加载所有数据
            Task {
                await tradeManager.refreshAll()
            }
        }
    }

    // MARK: - 分段选择器

    private var segmentedPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(TradeTab.allCases) { tab in
                Text(tab.title)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - 内容视图

    private var contentView: some View {
        Group {
            switch selectedTab {
            case .market:
                MarketOffersListView()

            case .myOffers:
                MyOffersListView()

            case .history:
                TradeHistoryListView()
            }
        }
    }
}

// MARK: - Trade Tab

/// 交易标签页枚举
enum TradeTab: Int, CaseIterable, Identifiable {
    case market = 0
    case myOffers = 1
    case history = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .market:
            return "市场".localized
        case .myOffers:
            return "我的挂单".localized
        case .history:
            return "历史".localized
        }
    }
}

// MARK: - Preview

#Preview {
    TradeMainView()
        .environmentObject(AuthManager())
        .environmentObject(InventoryManager())
}
