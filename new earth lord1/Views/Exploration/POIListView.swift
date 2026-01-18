//
//  POIListView.swift
//  new earth lord1
//
//  POI（兴趣点）列表页面
//  显示附近的兴趣点，支持搜索和筛选
//

import SwiftUI
import CoreLocation

struct POIListView: View {

    // MARK: - Environment Objects

    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var explorationManager: ExplorationManager

    // MARK: - State Properties

    /// 当前选中的分类（nil表示"全部"）
    @State private var selectedCategory: POIType? = nil

    /// 列表加载完成标志
    @State private var listLoaded = false

    /// 显示距离不足提示
    @State private var showDistanceAlert = false

    /// 距离不足的POI
    @State private var tooFarPOI: POI?

    /// 选中的POI（用于导航）
    @State private var selectedPOI: POI?

    /// 显示POI详情
    @State private var showPOIDetail = false

    /// POI搜刮距离阈值（米）
    private let scavengeDistanceThreshold: Double = 50.0

    // MARK: - Computed Properties

    /// 筛选后的POI列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return explorationManager.nearbyPOIs.filter { $0.type == category }
        }
        return explorationManager.nearbyPOIs
    }

    /// 发现的POI数量
    private var discoveredCount: Int {
        return explorationManager.nearbyPOIs.filter { $0.status == .discovered || $0.status == .looted }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                // 筛选工具栏
                filterToolbar
                    .padding(.vertical, 8)

                // POI列表
                poiList
            }
        }
        .navigationTitle("附近探索".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("距离不足".localized, isPresented: $showDistanceAlert) {
            Button("确定".localized, role: .cancel) { }
        } message: {
            if let poi = tooFarPOI {
                Text(String(format: "距%@还差 %lldm".localized, poi.name, Int64(poi.distance - scavengeDistanceThreshold)))
            }
        }
        .background(
            NavigationLink(
                destination: selectedPOI.map { POIDetailView(poi: $0) },
                isActive: $showPOIDetail
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: 8) {
            // GPS坐标
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.info)

                if let location = locationManager.currentFullLocation {
                    Text(String(format: "GPS: %.2f, %.2f".localized, location.coordinate.latitude, location.coordinate.longitude))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Text("GPS: --")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()
            }

            // 发现数量
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Text(String(format: "附近发现 %lld 个地点".localized, explorationManager.nearbyPOIs.count))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部"按钮
                filterButton(title: "全部".localized, icon: "square.grid.2x2.fill", category: nil)

                // 各分类按钮
                filterButton(title: "医院".localized, icon: "cross.case.fill", category: .hospital)
                filterButton(title: "超市".localized, icon: "cart.fill", category: .supermarket)
                filterButton(title: "工厂".localized, icon: "building.2.fill", category: .factory)
                filterButton(title: "药店".localized, icon: "pills.fill", category: .pharmacy)
                filterButton(title: "加油站".localized, icon: "fuelpump.fill", category: .gasStation)
            }
            .padding(.horizontal)
        }
    }

    /// 筛选按钮
    private func filterButton(title: String, icon: String, category: POIType?) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                selectedCategory == category
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.cardBackground
            )
            .foregroundColor(
                selectedCategory == category
                    ? .white
                    : ApocalypseTheme.textSecondary
            )
            .cornerRadius(20)
        }
    }

    // MARK: - POI列表

    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    // 空状态
                    emptyState
                } else {
                    ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                        Button(action: {
                            handlePOITap(poi)
                        }) {
                            POICardView(poi: poi)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(listLoaded ? 1 : 0)
                        .offset(y: listLoaded ? 0 : 20)
                        .animation(
                            .easeOut(duration: 0.4)
                                .delay(Double(index) * 0.1),
                            value: listLoaded
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onAppear {
            if !listLoaded {
                listLoaded = true
            }
        }
    }

    /// 空状态视图
    private var emptyState: some View {
        VStack(spacing: 16) {
            // 图标
            Image(systemName: explorationManager.nearbyPOIs.isEmpty ? "map" : "mappin.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(explorationManager.nearbyPOIs.isEmpty ? "附近暂无兴趣点".localized : "没有找到该类型的地点".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(explorationManager.nearbyPOIs.isEmpty ? "开始探索以发现周围的废墟".localized : "切换其他分类查看".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    /// 处理POI点击
    private func handlePOITap(_ poi: POI) {
        // 检查距离
        if poi.distance <= scavengeDistanceThreshold {
            // 距离足够，可以进入详情页
            selectedPOI = poi
            showPOIDetail = true
            print("✅ [POI] 距离足够(\(String(format: "%.1f", poi.distance))m)，进入详情页: \(poi.name)")
        } else {
            // 距离不足，显示提示
            tooFarPOI = poi
            showDistanceAlert = true
            print("⚠️ [POI] 距离不足(\(String(format: "%.1f", poi.distance))m > \(scavengeDistanceThreshold)m)，无法搜刮: \(poi.name)")
        }
    }
}

// MARK: - POI Card View

/// POI卡片视图
struct POICardView: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：类型图标
            poiIcon

            // 中间：POI信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                    Text(poi.type.rawValue)
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)

                // 距离
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(String(format: "%.0f米", poi.distance))
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 右侧：状态标签
            VStack(spacing: 6) {
                statusBadge
                resourceBadge
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }

    // MARK: - POI图标

    private var poiIcon: some View {
        ZStack {
            Circle()
                .fill(poiColor.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: poiIconName)
                .font(.system(size: 22))
                .foregroundColor(poiColor)
        }
    }

    /// POI类型对应的颜色
    private var poiColor: Color {
        switch poi.type {
        case .hospital:
            return .red
        case .supermarket:
            return .green
        case .factory:
            return .gray
        case .pharmacy:
            return .purple
        case .gasStation:
            return .orange
        case .warehouse:
            return .blue
        case .school:
            return .yellow
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

    // MARK: - 状态标签

    /// 发现状态标签
    private var statusBadge: some View {
        Group {
            switch poi.status {
            case .undiscovered:
                Label("未发现", systemImage: "lock.fill")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.textMuted.opacity(0.2))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .cornerRadius(8)

            case .discovered:
                Label("已发现", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.success.opacity(0.2))
                    .foregroundColor(ApocalypseTheme.success)
                    .cornerRadius(8)

            case .looted:
                Label("已搜刮", systemImage: "xmark.circle.fill")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.warning.opacity(0.2))
                    .foregroundColor(ApocalypseTheme.warning)
                    .cornerRadius(8)
            }
        }
    }

    /// 物资状态标签
    private var resourceBadge: some View {
        Group {
            switch poi.status {
            case .undiscovered:
                EmptyView()

            case .discovered:
                HStack(spacing: 2) {
                    Image(systemName: "cube.box.fill")
                        .font(.caption2)
                    Text("有物资")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.info.opacity(0.2))
                .foregroundColor(ApocalypseTheme.info)
                .cornerRadius(8)

            case .looted:
                HStack(spacing: 2) {
                    Image(systemName: "tray")
                        .font(.caption2)
                    Text("已搜空")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIListView()
    }
}
