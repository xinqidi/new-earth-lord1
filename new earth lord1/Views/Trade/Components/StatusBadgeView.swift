//
//  StatusBadgeView.swift
//  new earth lord1
//
//  交易状态徽章
//  显示交易挂单的状态（活跃/已完成/已取消/已过期）
//

import SwiftUI

struct StatusBadgeView: View {
    let status: TradeOfferStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }

    /// 状态对应的颜色
    private var statusColor: Color {
        switch status {
        case .active:
            return ApocalypseTheme.success       // 绿色
        case .completed:
            return ApocalypseTheme.info          // 蓝色
        case .cancelled:
            return ApocalypseTheme.textMuted     // 灰色
        case .expired:
            return ApocalypseTheme.warning       // 黄色
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        StatusBadgeView(status: .active)
        StatusBadgeView(status: .completed)
        StatusBadgeView(status: .cancelled)
        StatusBadgeView(status: .expired)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
