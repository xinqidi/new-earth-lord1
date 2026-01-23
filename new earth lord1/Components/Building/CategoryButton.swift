import SwiftUI

/// 建筑分类按钮组件
/// 显示图标和名称，支持选中/未选中状态
struct CategoryButton: View {
    let category: BuildingCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // 图标
                Image(systemName: category.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)

                // 名称
                Text(category.localizedName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BuildingCategory Extension

extension BuildingCategory {
    var iconName: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .survival:
            return "flame.fill"
        case .storage:
            return "shippingbox.fill"
        case .production:
            return "gearshape.2.fill"
        case .energy:
            return "bolt.fill"
        }
    }

    var localizedName: String {
        switch self {
        case .all:
            return NSLocalizedString("building.category.all", value: "全部", comment: "")
        case .survival:
            return NSLocalizedString("building.category.survival", value: "生存", comment: "")
        case .storage:
            return NSLocalizedString("building.category.storage", value: "储存", comment: "")
        case .production:
            return NSLocalizedString("building.category.production", value: "生产", comment: "")
        case .energy:
            return NSLocalizedString("building.category.energy", value: "能源", comment: "")
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        CategoryButton(category: .all, isSelected: true) {}
        CategoryButton(category: .survival, isSelected: false) {}
        CategoryButton(category: .storage, isSelected: false) {}
    }
    .padding()
}
