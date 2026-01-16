//
//  POIDetailView.swift
//  new earth lord1
//
//  POI详情页面
//  显示POI的详细信息和操作选项
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - Properties

    /// POI数据
    let poi: POI

    /// POI状态（可变，用于更新标记）
    @State private var poiStatus: POIStatus

    // MARK: - Initialization

    init(poi: POI) {
        self.poi = poi
        _poiStatus = State(initialValue: poi.status)
    }

    // MARK: - 假数据

    /// 假距离数据（米）
    private let mockDistance: Double = 350

    /// 假来源
    private let mockSource: POISource = .mapData

    /// POI搜索结果（搜寻POI时使用的临时结果）
    @State private var poiSearchResult: ExplorationResult?

    // MARK: - Computed Properties

    /// 是否可以搜寻（未被搜空）
    private var canExplore: Bool {
        return poiStatus != .looted
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 信息区域
                    infoSection
                        .padding(.horizontal)
                        .padding(.top, 20)

                    // 操作按钮区域
                    actionButtons
                        .padding(.horizontal)
                        .padding(.vertical, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $poiSearchResult) { result in
            ExplorationResultView(result: result)
        }
    }

    // MARK: - 顶部大图区域

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    poiGradientColors.0,
                    poiGradientColors.1
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: UIScreen.main.bounds.height / 3)

            // 大图标
            VStack {
                Spacer()

                Image(systemName: poiIconName)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10)

                Spacer()
            }
            .frame(height: UIScreen.main.bounds.height / 3)

            // 底部遮罩和名称
            VStack(spacing: 8) {
                Text(poi.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.caption)
                    Text(poi.type.rawValue)
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - 信息区域

    private var infoSection: some View {
        VStack(spacing: 16) {
            // 描述
            infoCard(
                icon: "doc.text.fill",
                title: "描述",
                content: poi.description,
                color: ApocalypseTheme.info
            )

            // 距离
            infoCard(
                icon: "location.fill",
                title: "距离",
                content: String(format: "%.0f米", mockDistance),
                color: .blue
            )

            // 物资状态
            infoCard(
                icon: resourceStatusIcon,
                title: "物资状态",
                content: resourceStatusText,
                color: resourceStatusColor
            )

            // 危险等级
            infoCard(
                icon: "exclamationmark.triangle.fill",
                title: "危险等级",
                content: poi.dangerLevel.displayName,
                color: dangerLevelColor
            )

            // 来源
            infoCard(
                icon: "map.fill",
                title: "来源",
                content: mockSource.rawValue,
                color: .gray
            )
        }
    }

    /// 信息卡片
    private func infoCard(icon: String, title: String, content: String, color: Color) -> some View {
        HStack(spacing: 16) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            // 信息内容
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(content)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮区域

    private var actionButtons: some View {
        VStack(spacing: 16) {
            // 主按钮：搜寻此POI
            Button(action: {
                handleExplore()
            }) {
                HStack {
                    Image(systemName: canExplore ? "magnifyingglass.circle.fill" : "lock.fill")
                        .font(.headline)

                    Text(canExplore ? "搜寻此POI" : "已被搜空")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    canExplore
                        ? LinearGradient(
                            gradient: Gradient(colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [Color.gray, Color.gray]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(12)
                .shadow(
                    color: canExplore ? ApocalypseTheme.primary.opacity(0.4) : Color.clear,
                    radius: 10,
                    x: 0,
                    y: 4
                )
            }
            .disabled(!canExplore)

            // 两个小按钮并排
            HStack(spacing: 12) {
                // 标记已发现
                Button(action: {
                    handleMarkDiscovered()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("标记已发现")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(poiStatus == .discovered || poiStatus == .looted ? .white : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        poiStatus == .discovered || poiStatus == .looted
                            ? ApocalypseTheme.success
                            : ApocalypseTheme.cardBackground
                    )
                    .cornerRadius(10)
                }

                // 标记无物资
                Button(action: {
                    handleMarkLooted()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("标记无物资")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(poiStatus == .looted ? .white : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        poiStatus == .looted
                            ? ApocalypseTheme.warning
                            : ApocalypseTheme.cardBackground
                    )
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Computed UI Properties

    /// POI类型对应的渐变颜色
    private var poiGradientColors: (Color, Color) {
        switch poi.type {
        case .hospital:
            return (Color.red.opacity(0.8), Color.red.opacity(0.5))
        case .supermarket:
            return (Color.green.opacity(0.8), Color.green.opacity(0.5))
        case .factory:
            return (Color.gray.opacity(0.8), Color.gray.opacity(0.5))
        case .pharmacy:
            return (Color.purple.opacity(0.8), Color.purple.opacity(0.5))
        case .gasStation:
            return (Color.orange.opacity(0.8), Color.orange.opacity(0.5))
        case .warehouse:
            return (Color.blue.opacity(0.8), Color.blue.opacity(0.5))
        case .school:
            return (Color.yellow.opacity(0.8), Color.yellow.opacity(0.5))
        }
    }

    /// POI类型对应的图标
    private var poiIconName: String {
        switch poi.type {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .factory:
            return "building.2.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .school:
            return "book.fill"
        }
    }

    /// 物资状态图标
    private var resourceStatusIcon: String {
        switch poiStatus {
        case .undiscovered:
            return "questionmark.circle.fill"
        case .discovered:
            return "cube.box.fill"
        case .looted:
            return "tray.fill"
        }
    }

    /// 物资状态文字
    private var resourceStatusText: String {
        switch poiStatus {
        case .undiscovered:
            return "未知"
        case .discovered:
            return "有物资"
        case .looted:
            return "已清空"
        }
    }

    /// 物资状态颜色
    private var resourceStatusColor: Color {
        switch poiStatus {
        case .undiscovered:
            return .gray
        case .discovered:
            return ApocalypseTheme.success
        case .looted:
            return ApocalypseTheme.warning
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case .low:
            return ApocalypseTheme.success
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .extreme:
            return ApocalypseTheme.danger
        }
    }

    // MARK: - Actions

    /// 搜寻POI
    private func handleExplore() {
        print("🔍 [POI详情] 开始搜寻: \(poi.name)")

        // 生成POI搜索结果（模拟）
        // TODO: 后续可以连接真实的POI搜索逻辑
        let mockItems = [
            RewardItem(itemId: "water_bottle", name: "矿泉水", quantity: 2, rarity: "common", icon: "drop.fill", category: "water"),
            RewardItem(itemId: "canned_food", name: "罐头食品", quantity: 1, rarity: "common", icon: "fork.knife", category: "food")
        ]

        poiSearchResult = ExplorationResult(
            distance: mockDistance,
            durationSeconds: 60,
            tier: .bronze,
            items: mockItems,
            hasFailed: false,
            failureReason: nil
        )
    }

    /// 标记已发现
    private func handleMarkDiscovered() {
        withAnimation {
            poiStatus = .discovered
        }
        print("✅ [POI详情] 标记已发现: \(poi.name)")
    }

    /// 标记无物资
    private func handleMarkLooted() {
        withAnimation {
            poiStatus = .looted
        }
        print("❌ [POI详情] 标记无物资: \(poi.name)")
    }
}

// MARK: - Supporting Types

/// POI来源
enum POISource: String {
    case mapData = "地图数据"
    case userAdded = "手动添加"
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIDetailView(poi: MockExplorationData.mockPOIs[0])
    }
}
