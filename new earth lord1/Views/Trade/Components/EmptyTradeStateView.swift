//
//  EmptyTradeStateView.swift
//  new earth lord1
//
//  交易空状态视图
//  可复用的空状态展示组件
//

import SwiftUI

struct EmptyTradeStateView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(title.localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(description.localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        EmptyTradeStateView(
            icon: "cart",
            title: "市场空空如也",
            description: "还没有玩家发布交易挂单"
        )

        EmptyTradeStateView(
            icon: "doc.text",
            title: "还没有挂单",
            description: "点击右下角按钮发布你的第一个挂单"
        )

        EmptyTradeStateView(
            icon: "clock.arrow.circlepath",
            title: "暂无交易历史",
            description: "完成交易后会显示在这里"
        )
    }
    .background(ApocalypseTheme.background)
}
