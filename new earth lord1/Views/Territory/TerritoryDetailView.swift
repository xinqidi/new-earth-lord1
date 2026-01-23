//
//  TerritoryDetailView.swift
//  new earth lord1
//
//  领地详情页面（完全重写）
//  全屏地图布局，显示领地多边形和建筑标注
//

import SwiftUI
import MapKit
import Supabase

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据
    let territory: Territory

    /// 领地管理器
    let territoryManager: TerritoryManager?

    /// 删除回调
    let onDelete: (() -> Void)?

    // MARK: - State Properties

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 选择的模板用于建造
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 是否显示信息面板
    @State private var showInfoPanel = true

    /// 是否显示重命名对话框
    @State private var showRenameDialog = false

    /// 新名称
    @State private var newName = ""

    /// 建筑列表
    @State private var buildings: [PlayerBuilding] = []

    /// 是否显示删除确认
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    // MARK: - Environment

    @EnvironmentObject private var buildingManager: BuildingManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. 底层：全屏地图
            TerritoryMapView(
                territory: territory,
                buildings: buildings,
                onBuildingTap: { building in
                    // 处理建筑点击（未来可以显示建筑详情）
                    print("🏗️ 点击建筑: \(building.buildingName)")
                }
            )
            .ignoresSafeArea()

            // 2. 顶部：悬浮工具栏
            VStack {
                TerritoryToolbarView(
                    territory: territory,
                    onRename: {
                        newName = territory.name ?? ""
                        showRenameDialog = true
                    },
                    onBuild: {
                        showBuildingBrowser = true
                    },
                    onClose: {
                        dismiss()
                    },
                    onAddTestResources: {
                        // 添加测试资源
                        Task {
                            await buildingManager.addTestResources()
                        }
                    }
                )
                .padding()
                Spacer()
            }
            .zIndex(2)

            // 3. 底部：可折叠信息面板
            VStack {
                Spacer()
                if showInfoPanel {
                    TerritoryInfoPanel(
                        territory: territory,
                        buildings: buildings,
                        onToggle: {
                            withAnimation(.spring(response: 0.3)) {
                                showInfoPanel.toggle()
                            }
                        },
                        onUpgrade: { building in
                            Task {
                                do {
                                    try await buildingManager.upgradeBuilding(buildingId: building.id)
                                } catch {
                                    print("❌ [升级] 失败: \(error.localizedDescription)")
                                }
                            }
                        },
                        onDemolish: { building in
                            Task {
                                do {
                                    try await buildingManager.demolishBuilding(buildingId: building.id)
                                } catch {
                                    print("❌ [拆除] 失败: \(error.localizedDescription)")
                                }
                            }
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .zIndex(1)

            // 4. 快速折叠按钮（当面板折叠时显示）
            if !showInfoPanel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showInfoPanel = true
                            }
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                )
                        }
                        .padding()
                    }
                }
                .zIndex(1)
            }
        }
        .onAppear {
            loadBuildings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .buildingUpdated)) { _ in
            loadBuildings()
        }
        .sheet(isPresented: $showBuildingBrowser) {
            if let territoryManager = territoryManager {
                BuildingBrowserView(
                    territory: territory,
                    onDismiss: {
                        showBuildingBrowser = false
                    },
                    onStartConstruction: { template in
                        showBuildingBrowser = false
                        // 延迟0.3秒避免动画冲突
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedTemplateForConstruction = template
                        }
                    }
                )
                .environmentObject(buildingManager)
            }
        }
        .sheet(item: $selectedTemplateForConstruction) { template in
            if let territoryManager = territoryManager {
                BuildingPlacementView(
                    template: template,
                    territory: territory,
                    onDismiss: {
                        selectedTemplateForConstruction = nil
                    },
                    onConstructionStarted: { building in
                        selectedTemplateForConstruction = nil
                        loadBuildings()
                    }
                )
                .environmentObject(buildingManager)
            }
        }
        .alert("重命名领地", isPresented: $showRenameDialog) {
            TextField("领地名称", text: $newName)
            Button("取消", role: .cancel) { }
            Button("确认") {
                Task {
                    await renameTerritory()
                }
            }
        }
    }

    // MARK: - Methods

    /// 加载建筑列表
    private func loadBuildings() {
        Task {
            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
            await MainActor.run {
                buildings = buildingManager.getBuildingsForTerritory(territory.id)
            }
        }
    }

    /// 重命名领地
    private func renameTerritory() async {
        guard let manager = territoryManager else { return }

        do {
            try await manager.updateTerritoryName(territoryId: territory.id, newName: newName)
            // TerritoryManager会发送通知，TerritoryTabView会刷新
        } catch {
            print("❌ [重命名] 失败: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailViewPreview()
}

private struct TerritoryDetailViewPreview: View {
    var body: some View {
        let supabase = SupabaseClient(
            supabaseURL: URL(string: "https://ipvkhcrgbbcccwiwlofd.supabase.co")!,
            supabaseKey: "sb_publishable_DCfb2P7IEr46I6jX-Wu_3g_Es4DTHEJ"
        )
        let buildingManager = BuildingManager.shared
        let territoryManager = TerritoryManager(supabase: supabase)

        buildingManager.buildingTemplates = [
            BuildingTemplate(
                id: UUID(),
                templateId: "campfire",
                name: "篝火",
                category: .survival,
                tier: 1,
                description: "提供温暖",
                icon: "flame.fill",
                requiredResources: ["wood": 10],
                buildTimeSeconds: 30,
                maxPerTerritory: 5,
                maxLevel: 3
            )
        ]

        return TerritoryDetailView(
            territory: Territory(
                id: "test",
                userId: "test-user",
                name: "测试领地",
                path: [
                    ["lat": 39.9, "lon": 116.4],
                    ["lat": 39.91, "lon": 116.4],
                    ["lat": 39.91, "lon": 116.41],
                    ["lat": 39.9, "lon": 116.41]
                ],
                area: 10000,
                pointCount: 4,
                isActive: true,
                completedAt: nil,
                startedAt: nil,
                createdAt: "2025-01-22T12:00:00Z"
            ),
            territoryManager: territoryManager,
            onDelete: nil
        )
        .environmentObject(buildingManager)
    }
}
