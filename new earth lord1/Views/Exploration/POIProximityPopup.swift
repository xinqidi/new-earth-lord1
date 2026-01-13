//
//  POIProximityPopup.swift
//  new earth lord1
//
//  接近POI时的搜刮提示弹窗
//

import SwiftUI
import CoreLocation

/// POI接近弹窗
/// 当玩家进入POI 50米范围时显示
struct POIProximityPopup: View {

    /// 当前POI
    let poi: POI

    /// 搜刮回调
    let onScavenge: () -> Void

    /// 取消回调
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                // POI类型图标
                Image(systemName: poiIconName)
                    .font(.system(size: 28))
                    .foregroundColor(poiColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("发现废墟")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(poi.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                // 距离显示
                VStack(alignment: .trailing, spacing: 2) {
                    Text("距离")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("\(Int(poi.distance))m")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 描述
            Text(poi.description)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 按钮区域
            HStack(spacing: 12) {
                // 稍后再说
                Button(action: onDismiss) {
                    Text("稍后再说")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.background)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                }

                // 立即搜刮
                Button(action: onScavenge) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                        Text("立即搜刮")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .padding(.horizontal, 24)
    }

    // MARK: - POI图标和颜色（复用POIDetailView的逻辑）

    private var poiIconName: String {
        switch poi.type {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .factory:
            return "gearshape.2.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .school:
            return "book.fill"
        }
    }

    private var poiColor: Color {
        switch poi.type {
        case .hospital:
            return .red
        case .supermarket:
            return .green
        case .pharmacy:
            return .blue
        case .gasStation:
            return .orange
        case .factory:
            return .gray
        case .warehouse:
            return .brown
        case .school:
            return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.edgesIgnoringSafeArea(.all)

        POIProximityPopup(
            poi: POI(
                name: "废弃的华联超市",
                type: .supermarket,
                coordinate: .init(latitude: 39.9, longitude: 116.4),
                status: .undiscovered,
                distance: 32,
                description: "一座废弃的大型超市，货架倒塌，但仍可能残留罐头食品和瓶装水。"
            ),
            onScavenge: {},
            onDismiss: {}
        )
    }
}
