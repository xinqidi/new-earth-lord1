//
//  POIListView.swift
//  new earth lord1
//
//  POI（兴趣点）列表页面
//  显示附近的兴趣点，支持搜索和筛选
//

import SwiftUI

struct POIListView: View {

    // MARK: - State Properties

    /// 是否正在搜索
    @State private var isSearching = false

    /// 当前选中的分类（nil表示"全部"）
    @State private var selectedCategory: POIType? = nil

    /// 所有POI数据
    @State private var allPOIs: [POI] = MockExplorationData.mockPOIs

    /// 搜索按钮缩放
    @State private var searchButtonScale: CGFloat = 1.0

    /// 列表加载完成标志
    @State private var listLoaded = false

    /// 假GPS坐标
    private let mockGPSCoordinate = "22.54, 114.06"

    // MARK: - Computed Properties

    /// 筛选后的POI列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return allPOIs.filter { $0.type == category }
        }
        return allPOIs
    }

    /// 发现的POI数量
    private var discoveredCount: Int {
        return allPOIs.filter { $0.status == .discovered || $0.status == .looted }.count
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

                // 搜索按钮
                searchButton
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // 筛选工具栏
                filterToolbar
                    .padding(.vertical, 8)

                // POI列表
                poiList
            }
        }
        .navigationTitle("附近探索")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: 8) {
            // GPS坐标
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.info)

                Text("GPS: \(mockGPSCoordinate)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }

            // 发现数量
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 搜索按钮

    private var searchButton: some View {
        Button(action: {
            // 按钮点击缩放动画
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                searchButtonScale = 0.95
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    searchButtonScale = 1.0
                }
            }
            performSearch()
        }) {
            HStack {
                if isSearching {
                    // 加载动画
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Text("搜索中...")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(searchButtonScale)
        .disabled(isSearching)
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部"按钮
                filterButton(title: "全部", icon: "square.grid.2x2.fill", category: nil)

                // 各分类按钮
                filterButton(title: "医院", icon: "cross.case.fill", category: .hospital)
                filterButton(title: "超市", icon: "cart.fill", category: .supermarket)
                filterButton(title: "工厂", icon: "building.2.fill", category: .factory)
                filterButton(title: "药店", icon: "pills.fill", category: .pharmacy)
                filterButton(title: "加油站", icon: "fuelpump.fill", category: .gasStation)
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
                        NavigationLink(destination: POIDetailView(poi: poi)) {
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
            Image(systemName: allPOIs.isEmpty ? "map" : "mappin.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(allPOIs.isEmpty ? "附近暂无兴趣点" : "没有找到该类型的地点")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(allPOIs.isEmpty ? "点击搜索按钮发现周围的废墟" : "尝试搜索或切换其他分类")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    /// 执行搜索
    private func performSearch() {
        isSearching = true

        // 模拟网络请求（1.5秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            print("🔍 [POI搜索] 搜索完成")
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
