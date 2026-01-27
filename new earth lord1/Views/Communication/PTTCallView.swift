//
//  PTTCallView.swift
//  new earth lord1
//
//  呼叫中心页面（Day 36 实现）
//

import SwiftUI

struct PTTCallView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "phone.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("呼叫中心".localized)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("Day 36 实现".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

#Preview {
    PTTCallView()
}
