//
//  ProfileTabView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI

struct ProfileTabView: View {
    /// 认证管理器
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // 用户信息卡片
                VStack(spacing: 15) {
                    // 头像
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ApocalypseTheme.primary,
                                        ApocalypseTheme.primary.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }

                    // 用户邮箱
                    if let email = authManager.currentUser?.email {
                        Text(email)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    // 用户 ID
                    if let userId = authManager.currentUser?.id {
                        Text("ID: \(userId.uuidString.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(15)
                .padding(.horizontal)
                .padding(.top, 40)

                Spacer()

                // 退出登录按钮
                Button(action: {
                    Task {
                        await authManager.signOut()
                    }
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                        Text("退出登录")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.danger)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager())
}
