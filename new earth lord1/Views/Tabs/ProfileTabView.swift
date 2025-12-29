//
//  ProfileTabView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI
import Supabase

/// 个人中心页面
/// 显示用户信息和退出登录功能
struct ProfileTabView: View {
    /// 认证管理器
    @EnvironmentObject private var authManager: AuthManager

    /// 是否显示退出登录确认对话框
    @State private var showingSignOutConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部标题
                Text("幸存者档案")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.top, 15)
                    .padding(.bottom, 8)

                // 用户信息卡片
                VStack(spacing: 8) {
                    // 头像（缩小）
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
                            .frame(width: 80, height: 80)
                            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)

                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 5)

                    // 用户名（优先显示用户名，否则显示邮箱前缀）
                    if let user = authManager.currentUser {
                        Text(user.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 用户邮箱
                        if let email = user.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        // 用户 ID
                        Text("ID: \(user.id.uuidString.prefix(8))...")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .padding(.bottom, 15)

                // 统计信息卡片（缩小）
                HStack(spacing: 0) {
                    // 领地
                    VStack(spacing: 5) {
                        Image(systemName: "flag.fill")
                            .font(.title3)
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("0")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("领地")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)

                    Rectangle()
                        .fill(ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(width: 1, height: 50)

                    // 资源点
                    VStack(spacing: 5) {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("0")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("资源点")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)

                    Rectangle()
                        .fill(ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(width: 1, height: 50)

                    // 探索距离
                    VStack(spacing: 5) {
                        Image(systemName: "figure.walk")
                            .font(.title3)
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("0")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("探索距离")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 15)

                // 设置选项组（缩小间距）
                VStack(spacing: 0) {
                    // 设置
                    Button(action: {
                        // TODO: 跳转到设置页
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.body)
                                .foregroundColor(Color.gray)
                                .frame(width: 24)
                            Text("设置")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(ApocalypseTheme.cardBackground)
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .padding(.leading, 52)

                    // 通知
                    Button(action: {
                        // TODO: 跳转到通知页
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.primary)
                                .frame(width: 24)
                            Text("通知")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(ApocalypseTheme.cardBackground)
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .padding(.leading, 52)

                    // 帮助
                    Button(action: {
                        // TODO: 跳转到帮助页
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.body)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("帮助")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(ApocalypseTheme.cardBackground)
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .padding(.leading, 52)

                    // 关于
                    Button(action: {
                        // TODO: 跳转到关于页
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.body)
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("关于")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(ApocalypseTheme.cardBackground)
                    }
                }
                .cornerRadius(12)
                .padding(.horizontal)

                // 退出登录按钮
                Button(action: {
                    showingSignOutConfirm = true
                }) {
                    HStack(spacing: 10) {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.body)
                        }
                        Text(authManager.isLoading ? "退出中..." : "退出登录")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.danger)
                    .cornerRadius(10)
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 30)  // 按钮本身底部间距
            }
            // VStack 整体底部留白，为 TabBar 预留足够空间
            .padding(.bottom, 120)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .alert("退出登录", isPresented: $showingSignOutConfirm) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("确定要退出登录吗？")
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager())
}
