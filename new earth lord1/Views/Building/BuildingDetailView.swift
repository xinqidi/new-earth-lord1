import SwiftUI

/// 建筑详情视图
/// 显示建筑的完整信息、资源需求和建造按钮
struct BuildingDetailView: View {
    let template: BuildingTemplate
    let territory: Territory
    let onDismiss: () -> Void
    let onStartConstruction: (BuildingTemplate) -> Void

    @EnvironmentObject private var buildingManager: BuildingManager
    @EnvironmentObject private var inventoryManager: InventoryManager

    private var canBuild: Bool {
        let result = buildingManager.canBuild(template: template, territoryId: territory.id)
        return result.canBuild
    }

    private var buildError: BuildingError? {
        let result = buildingManager.canBuild(template: template, territoryId: territory.id)
        return result.error
    }

    private var builtCount: Int {
        return buildingManager.getBuildingCount(
            templateId: template.templateId,
            territoryId: territory.id
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 建筑预览卡片
                    buildingPreviewCard

                    // 描述
                    descriptionSection

                    // 基本信息
                    infoSection

                    // 资源需求
                    resourcesSection

                    // 建造按钮
                    buildButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Building Preview Card

    private var buildingPreviewCard: some View {
        VStack(spacing: 16) {
            // 图标
            Image(systemName: template.icon)
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            // 名称和分类
            VStack(spacing: 4) {
                Text(template.name)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 4) {
                    Image(systemName: template.category.icon)
                        .font(.caption)

                    Text(template.category.displayName)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            // 等级信息
            HStack(spacing: 16) {
                infoItem(
                    icon: "star.fill",
                    label: "等级",
                    value: "1 - \(template.maxLevel)"
                )

                Divider()
                    .frame(height: 30)

                infoItem(
                    icon: "building.2.fill",
                    label: "已建/上限",
                    value: "\(builtCount)/\(template.maxPerTerritory)",
                    valueColor: builtCount >= template.maxPerTerritory ? .red : .primary
                )
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }

    private func infoItem(icon: String, label: String, value: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("描述")
                .font(.headline)

            Text(template.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造信息")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                infoRow(label: "建造时间", value: formatBuildTime(template.buildTimeSeconds))
                Divider()
                    .padding(.leading, 16)
                infoRow(label: "分类", value: template.category.displayName)
                Divider()
                    .padding(.leading, 16)
                infoRow(label: "层级", value: "Tier \(template.tier)")
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func formatBuildTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes)分钟"
            } else {
                return "\(minutes)分\(remainingSeconds)秒"
            }
        }
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("资源需求")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                    if let required = template.requiredResources[resourceId] {
                        let owned = inventoryManager.items.first { $0.itemId == resourceId }?.quantity ?? 0
                        ResourceRow(
                            itemName: resourceId,
                            required: required,
                            owned: owned
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Build Button

    private var buildButton: some View {
        VStack(spacing: 12) {
            if let error = buildError {
                Text(error.errorDescription ?? "无法建造")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                onStartConstruction(template)
            } label: {
                HStack {
                    Image(systemName: "hammer.fill")
                    Text("开始建造")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canBuild ? Color.orange : Color.gray)
                )
            }
            .disabled(!canBuild)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    BuildingDetailViewPreview()
}

private struct BuildingDetailViewPreview: View {
    var body: some View {
        let buildingManager = BuildingManager.shared
        let inventoryManager = InventoryManager()

        buildingManager.buildingTemplates = [
            BuildingTemplate(
                id: UUID(),
                templateId: "campfire",
                name: "篝火",
                category: .survival,
                tier: 1,
                description: "提供温暖和光明，是生存的基础设施",
                icon: "flame.fill",
                requiredResources: ["wood": 10, "stone": 5],
                buildTimeSeconds: 30,
                maxPerTerritory: 5,
                maxLevel: 3
            )
        ]

        return BuildingDetailView(
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
            onStartConstruction: { _ in }
        )
        .environmentObject(buildingManager)
        .environmentObject(inventoryManager)
    }
}
