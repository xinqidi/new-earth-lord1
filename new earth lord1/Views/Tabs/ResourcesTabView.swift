//
//  ResourcesTabView.swift
//  new earth lord1
//
//  资源模块主入口页面
//  包含POI、背包、已购、领地、交易等功能入口
//

import SwiftUI

struct ResourcesTabView: View {

    // MARK: - State Properties

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradingEnabled = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 交易开关区域
                    tradingSwitchBar
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                    // 分段选择器
                    segmentedPicker
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源".localized)
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - 交易开关区域

    private var tradingSwitchBar: some View {
        HStack {
            // 左侧图标和文字
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.headline)
                    .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                Text("交易模式".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            // 开关
            Toggle("", isOn: $isTradingEnabled)
                .labelsHidden()
                .tint(ApocalypseTheme.primary)
                .onChange(of: isTradingEnabled) { oldValue, newValue in
                    handleTradingToggle(newValue)
                }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 分段选择器

    private var segmentedPicker: some View {
        Picker("资源分段".localized, selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - 内容区域

    private var contentView: some View {
        Group {
            switch selectedSegment {
            case .poi:
                POIListView()

            case .backpack:
                BackpackView()

            case .purchased:
                placeholderView(
                    icon: "bag.fill",
                    title: "已购物品".localized,
                    description: "功能开发中".localized
                )

            case .territory:
                placeholderView(
                    icon: "map.fill",
                    title: "领地管理".localized,
                    description: "功能开发中".localized
                )

            case .trading:
                TradeMainView()
            }
        }
    }

    /// 占位视图
    private func placeholderView(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 标题
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 描述
            Text(description)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 提示
            Text("敬请期待...".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }

    // MARK: - Actions

    /// 处理交易开关切换
    private func handleTradingToggle(_ isEnabled: Bool) {
        print("🔄 [资源Tab] 交易模式: \(isEnabled ? "开启" : "关闭")")
        // TODO: 实现交易模式切换逻辑
    }
}

// MARK: - Resource Segment

/// 资源分段类型
enum ResourceSegment: Int, CaseIterable, Identifiable {
    case poi = 0
    case backpack = 1
    case purchased = 2
    case territory = 3
    case trading = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .poi:
            return "POI"
        case .backpack:
            return "背包".localized
        case .purchased:
            return "已购".localized
        case .territory:
            return "领地".localized
        case .trading:
            return "交易".localized
        }
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
