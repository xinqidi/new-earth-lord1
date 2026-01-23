import SwiftUI

/// 资源行组件 - 显示单个资源的图标、名称和数量
/// 根据库存是否足够显示不同颜色（足够=绿色，不足=红色）
struct ResourceRow: View {
    let itemName: String
    let required: Int
    let owned: Int

    private var isEnough: Bool {
        owned >= required
    }

    private var displayColor: Color {
        isEnough ? .green : .red
    }

    // 资源图标映射
    private var iconName: String {
        switch itemName.lowercased() {
        case "wood", "木材":
            return "tree.fill"
        case "stone", "石头":
            return "square.3.layers.3d"
        case "metal", "金属":
            return "gearshape.2.fill"
        case "food", "食物":
            return "fork.knife"
        case "water", "水":
            return "drop.fill"
        default:
            return "cube.box.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：资源图标
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            // 中间：资源名称
            Text(itemName)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // 右侧：数量显示（拥有/需要）
            HStack(spacing: 4) {
                Text("\(owned)")
                    .fontWeight(.semibold)
                    .foregroundStyle(displayColor)

                Text("/")
                    .foregroundStyle(.secondary)

                Text("\(required)")
                    .foregroundStyle(.secondary)
            }
            .font(.body)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        ResourceRow(itemName: "木材", required: 10, owned: 15)
        ResourceRow(itemName: "石头", required: 5, owned: 3)
        ResourceRow(itemName: "金属", required: 2, owned: 0)
    }
    .padding()
}
