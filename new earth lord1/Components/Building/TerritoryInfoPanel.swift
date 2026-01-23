import SwiftUI

/// 领地信息面板
/// 底部可折叠面板，显示领地基本信息和建筑列表
struct TerritoryInfoPanel: View {
    let territory: Territory
    let buildings: [PlayerBuilding]
    let onToggle: () -> Void
    let onUpgrade: (PlayerBuilding) -> Void
    let onDemolish: (PlayerBuilding) -> Void

    @EnvironmentObject private var buildingManager: BuildingManager

    private func template(for building: PlayerBuilding) -> BuildingTemplate? {
        return buildingManager.getTemplate(for: building.templateId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 拖动手柄
            dragHandle

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 领地信息
                    territoryInfoSection

                    Divider()

                    // 建筑列表
                    buildingsSection
                }
                .padding()
            }
            .frame(maxHeight: 400)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
            )
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        Button(action: onToggle) {
            VStack(spacing: 4) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Territory Info Section

    private var territoryInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("领地信息")
                .font(.headline)

            HStack(spacing: 20) {
                infoItem(
                    icon: "map.fill",
                    label: "面积",
                    value: territory.formattedArea
                )

                infoItem(
                    icon: "building.2.fill",
                    label: "建筑数",
                    value: "\(buildings.count)"
                )

                infoItem(
                    icon: "clock.fill",
                    label: "创建时间",
                    value: formatDate(territory.createdAt)
                )
            }
        }
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "未知" }

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "未知" }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM/dd"
        return displayFormatter.string(from: date)
    }

    // MARK: - Buildings Section

    private var buildingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建筑列表")
                .font(.headline)

            if buildings.isEmpty {
                emptyView
            } else {
                buildingsList
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("暂无建筑")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("点击右上角建造按钮开始建设")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var buildingsList: some View {
        VStack(spacing: 8) {
            ForEach(buildings) { building in
                TerritoryBuildingRow(
                    building: building,
                    template: template(for: building),
                    onUpgrade: {
                        onUpgrade(building)
                    },
                    onDemolish: {
                        onDemolish(building)
                    }
                )
            }
        }
    }
}

#Preview {
    TerritoryInfoPanelPreview()
}

private struct TerritoryInfoPanelPreview: View {
    var body: some View {
        let buildingManager = BuildingManager.shared
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

        let building = PlayerBuilding(
            id: UUID(),
            userId: UUID(),
            territoryId: "test",
            templateId: "campfire",
            buildingName: "篝火",
            status: .active,
            level: 1,
            locationLat: 0,
            locationLon: 0,
            buildStartedAt: Date(),
            buildCompletedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        return ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            Spacer()
            TerritoryInfoPanel(
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
                buildings: [building],
                onToggle: {},
                onUpgrade: { _ in },
                onDemolish: { _ in }
            )
        }
    }
    .environmentObject(buildingManager)
    }
}
