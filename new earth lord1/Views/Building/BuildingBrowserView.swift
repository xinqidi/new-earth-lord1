import SwiftUI

/// 建筑浏览器视图
/// 显示可建造的建筑列表，支持分类筛选
struct BuildingBrowserView: View {
    let territory: Territory
    let onDismiss: () -> Void
    let onStartConstruction: (BuildingTemplate) -> Void

    @EnvironmentObject private var buildingManager: BuildingManager

    @State private var selectedCategory: BuildingCategory = .all
    @State private var selectedTemplate: BuildingTemplate?

    private var filteredTemplates: [BuildingTemplate] {
        if selectedCategory == .all {
            return buildingManager.buildingTemplates
        }
        return buildingManager.buildingTemplates.filter { $0.category == selectedCategory }
    }

    private func builtCount(for template: BuildingTemplate) -> Int {
        return buildingManager.getBuildingCount(
            templateId: template.templateId,
            territoryId: territory.id
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部：分类筛选
                categoryBar

                Divider()

                // 建筑列表
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(filteredTemplates) { template in
                            BuildingCard(
                                template: template,
                                builtCount: builtCount(for: template)
                            ) {
                                selectedTemplate = template
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("建筑列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                BuildingDetailView(
                    template: template,
                    territory: territory,
                    onDismiss: {
                        selectedTemplate = nil
                    },
                    onStartConstruction: { template in
                        selectedTemplate = nil
                        // 延迟0.3秒避免Sheet动画冲突
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onStartConstruction(template)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                    .frame(width: 70)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    BuildingBrowserViewPreview()
}

private struct BuildingBrowserViewPreview: View {
    var body: some View {
        let buildingManager = BuildingManager.shared
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

        return BuildingBrowserView(
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
    }
}
