import SwiftUI

/// 领地工具栏视图
/// 悬浮在地图上方，包含关闭、重命名和建造按钮
struct TerritoryToolbarView: View {
    let territory: Territory
    let onRename: () -> Void
    let onBuild: () -> Void
    let onClose: () -> Void
    let onAddTestResources: (() -> Void)?  // 可选的测试资源按钮

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                    )
            }

            // 中间：领地名称 + 齿轮按钮
            HStack(spacing: 8) {
                Text(territory.name ?? "未命名领地")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Button(action: onRename) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
            )

            Spacer()

            // 测试资源按钮（可选，仅用于开发）
            if let onAddTestResources = onAddTestResources {
                Button(action: onAddTestResources) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.green)
                        )
                }
            }

            // 右侧：建造按钮
            Button(action: onBuild) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14))
                    Text("建造")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.orange)
                )
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
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
                onRename: {},
                onBuild: {},
                onClose: {},
                onAddTestResources: {}
            )
            .padding()

            Spacer()
        }
    }
}
