import SwiftUI
import CoreLocation
import Supabase

/// 建筑位置选择和建造确认视图
struct BuildingPlacementView: View {
    let template: BuildingTemplate
    let territory: Territory
    let onDismiss: () -> Void
    let onConstructionStarted: (PlayerBuilding) -> Void

    @EnvironmentObject private var buildingManager: BuildingManager

    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showLocationPicker = false
    @State private var isConstructing = false
    @State private var errorMessage: String?
    @State private var territoryManager: TerritoryManager = {
        let supabase = SupabaseClient(
            supabaseURL: URL(string: "https://ipvkhcrgbbcccwiwlofd.supabase.co")!,
            supabaseKey: "sb_publishable_DCfb2P7IEr46I6jX-Wu_3g_Es4DTHEJ"
        )
        return TerritoryManager(supabase: supabase)
    }()

    private var existingBuildings: [PlayerBuilding] {
        return buildingManager.getBuildingsForTerritory(territory.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部：建筑预览卡片
                    buildingPreviewCard

                    // 位置选择区域
                    locationSelectionSection

                    // 资源确认
                    resourceConfirmationSection

                    // 确认建造按钮
                    confirmButton

                    // 错误提示
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                BuildingLocationPickerView(
                    territory: territory,
                    territoryManager: territoryManager,
                    existingBuildings: existingBuildings,
                    onLocationSelected: { coordinate in
                        selectedLocation = coordinate
                        showLocationPicker = false
                    },
                    onCancel: {
                        showLocationPicker = false
                    }
                )
            }
            .disabled(isConstructing)
        }
    }

    // MARK: - Building Preview Card

    private var buildingPreviewCard: some View {
        HStack(spacing: 16) {
            // 图标
            Image(systemName: template.icon)
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                )

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(template.category.displayName, systemImage: template.category.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("Lv.1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Location Selection

    private var locationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造位置")
                .font(.headline)

            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("在地图上选择位置")
                            .font(.body)
                            .foregroundStyle(.primary)

                        if let location = selectedLocation {
                            Text(formatCoordinate(location))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("点击选择建造位置")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if selectedLocation != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }

    // MARK: - Resource Confirmation

    private var resourceConfirmationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("资源消耗")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(template.requiredResources.keys.sorted(), id: \.self) { resourceId in
                    if let required = template.requiredResources[resourceId] {
                        ResourceRow(
                            itemName: resourceId,
                            required: required,
                            owned: 0  // TODO: Get from inventory manager
                        )
                    }
                }
            }
        }
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            confirmConstruction()
        } label: {
            HStack {
                if isConstructing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "hammer.fill")
                    Text("确认建造")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedLocation != nil && !isConstructing ? Color.orange : Color.gray)
            )
        }
        .disabled(selectedLocation == nil || isConstructing)
    }

    // MARK: - Actions

    private func confirmConstruction() {
        guard let location = selectedLocation else { return }

        isConstructing = true
        errorMessage = nil

        Task {
            do {
                try await buildingManager.startConstruction(
                    templateId: template.templateId,
                    territoryId: territory.id,
                    location: location
                )

                // 获取刚建造的建筑
                await MainActor.run {
                    if let newBuilding = buildingManager.playerBuildings.last {
                        onConstructionStarted(newBuilding)
                    }
                }

            } catch {
                await MainActor.run {
                    isConstructing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    BuildingPlacementViewPreview()
}

private struct BuildingPlacementViewPreview: View {
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
                description: "提供温暖和光明",
                icon: "flame.fill",
                requiredResources: ["wood": 10],
                buildTimeSeconds: 30,
                maxPerTerritory: 5,
                maxLevel: 3
            )
        ]

        return BuildingPlacementView(
            template: buildingManager.buildingTemplates[0],
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
            onDismiss: {},
            onConstructionStarted: { _ in }
        )
        .environmentObject(buildingManager)
    }
}
