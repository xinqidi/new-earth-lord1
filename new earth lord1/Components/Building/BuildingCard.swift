import SwiftUI

/// 建筑卡片组件
/// 显示建筑图标、名称、等级范围和已建数量
struct BuildingCard: View {
    let template: BuildingTemplate
    let builtCount: Int
    let action: () -> Void

    private var isMaxedOut: Bool {
        builtCount >= template.maxPerTerritory
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // 顶部：建筑图标
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                        .frame(width: 40, height: 40)

                    Spacer()

                    // 右上角：数量标签
                    Text("\(builtCount)/\(template.maxPerTerritory)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(isMaxedOut ? .red : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray5))
                        )
                }

                // 中间：建筑名称
                Text(template.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // 底部：等级范围
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)

                    Text("Lv.1 - \(template.maxLevel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // 分类标签
                    Text(template.category.localizedName)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(categoryColor)
                        )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isMaxedOut ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isMaxedOut)
        .opacity(isMaxedOut ? 0.5 : 1.0)
    }

    private var categoryColor: Color {
        switch template.category {
        case .survival:
            return .orange
        case .storage:
            return .blue
        case .production:
            return .green
        case .energy:
            return .yellow
        case .all:
            return .gray
        }
    }
}

#Preview {
    let template = BuildingTemplate(
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

    VStack(spacing: 12) {
        BuildingCard(template: template, builtCount: 2) {}
        BuildingCard(template: template, builtCount: 5) {}
    }
    .padding()
}
