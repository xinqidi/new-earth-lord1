import SwiftUI

/// 领地建筑行组件
/// 显示建筑图标、名称、等级和状态
struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    let onUpgrade: () -> Void
    let onDemolish: () -> Void

    private var iconName: String {
        template?.icon ?? "building.2.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：建筑图标
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(.orange)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                )

            // 中间：建筑信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Lv.\(building.level)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 状态标签
                statusBadge
            }

            Spacer()

            // 右侧：状态显示
            rightSide
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(building.status.color)
                .frame(width: 6, height: 6)

            Text(building.status.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Right Side

    @ViewBuilder
    private var rightSide: some View {
        if building.status == .constructing {
            // 建造中：显示进度环和倒计时
            HStack(spacing: 8) {
                CircularProgressView(progress: building.constructionProgress)

                Text(building.formattedRemainingTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 50, alignment: .trailing)
            }
        } else if building.status == .active {
            // 运行中：显示操作菜单
            Menu {
                Button {
                    onUpgrade()
                } label: {
                    Label("升级", systemImage: "arrow.up.circle")
                }
                .disabled(isMaxLevel)

                Divider()

                Button(role: .destructive) {
                    onDemolish()
                } label: {
                    Label("拆除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isMaxLevel: Bool {
        guard let template = template else { return true }
        return building.level >= template.maxLevel
    }
}

#Preview {
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

    let constructingBuilding = PlayerBuilding(
        id: UUID(),
        userId: UUID(),
        territoryId: "test",
        templateId: "campfire",
        buildingName: "篝火",
        status: .constructing,
        level: 1,
        locationLat: 0,
        locationLon: 0,
        buildStartedAt: Date(),
        buildCompletedAt: Date().addingTimeInterval(60),
        createdAt: Date(),
        updatedAt: Date()
    )

    let activeBuilding = PlayerBuilding(
        id: UUID(),
        userId: UUID(),
        territoryId: "test",
        templateId: "campfire",
        buildingName: "篝火",
        status: .active,
        level: 2,
        locationLat: 0,
        locationLon: 0,
        buildStartedAt: Date(),
        buildCompletedAt: Date(),
        createdAt: Date(),
        updatedAt: Date()
    )

    return VStack(spacing: 12) {
        TerritoryBuildingRow(
            building: constructingBuilding,
            template: buildingManager.buildingTemplates[0],
            onUpgrade: {},
            onDemolish: {}
        )

        TerritoryBuildingRow(
            building: activeBuilding,
            template: buildingManager.buildingTemplates[0],
            onUpgrade: {},
            onDemolish: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
