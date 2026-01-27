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

    /// 语言管理器
    @EnvironmentObject private var languageManager: LanguageManager

    /// 是否显示退出登录确认对话框
    @State private var showingSignOutConfirm = false

    /// 是否显示删除账户确认对话框
    @State private var showingDeleteAccountConfirm = false

    /// 是否显示语言选择器
    @State private var showingLanguagePicker = false

    /// 用户输入的确认文本
    @State private var deleteConfirmText = ""

    /// 删除账户错误信息
    @State private var deleteAccountError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 0) {
                // 顶部标题
                Text("幸存者档案".localized)
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
                        Text("\(authManager.territoryCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("领地".localized)
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
                        Text("\(authManager.resourcePointCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("资源点".localized)
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
                        Text(formattedDistance)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("探索距离".localized)
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
                .onAppear {
                    // 加载用户统计数据
                    Task {
                        await authManager.loadUserStats()
                    }
                }

                // 设置选项组（缩小间距）
                VStack(spacing: 0) {
                    // 设置
                    NavigationLink(destination: SettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.body)
                                .foregroundColor(Color.gray)
                                .frame(width: 24)
                            Text("设置".localized)
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
                            Text("通知".localized)
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

                    // 语言
                    Button(action: {
                        showingLanguagePicker = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.body)
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("语言".localized)
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            Text(languageManager.currentLanguage.displayName(languageManager: languageManager))
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
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
                            Text("帮助".localized)
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
                            Text("关于".localized)
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

                // 删除账户按钮
                Button(action: {
                    showingDeleteAccountConfirm = true
                    deleteConfirmText = ""
                    deleteAccountError = nil
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "trash.fill")
                            .font(.body)
                        Text("删除账户".localized)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal)
                .padding(.top, 20)

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
                        Text(authManager.isLoading ? "退出中...".localized : "退出登录".localized)
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
                .padding(.top, 12)
                .padding(.bottom, 30)  // 按钮本身底部间距
            }
            // VStack 整体底部留白，为 TabBar 预留足够空间
            .padding(.bottom, 120)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
        }
        .alert("退出登录".localized, isPresented: $showingSignOutConfirm) {
            Button("取消".localized, role: .cancel) {}
            Button("退出".localized, role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("确定要退出登录吗？".localized)
        }
        .sheet(isPresented: $showingDeleteAccountConfirm) {
            deleteAccountConfirmSheet
        }
        .sheet(isPresented: $showingLanguagePicker) {
            languagePickerSheet
        }
        // 🔑 强制在语言变化时重新渲染
        .id(languageManager.currentLanguage)
    }

    // MARK: - 语言选择器

    private var languagePickerSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                List {
                    ForEach(AppLanguage.allCases) { language in
                        Button(action: {
                            languageManager.setLanguage(language)
                            showingLanguagePicker = false
                        }) {
                            HStack {
                                Text(language.displayName(languageManager: languageManager))
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                Spacer()
                                if languageManager.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(ApocalypseTheme.primary)
                                }
                            }
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("选择语言".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成".localized) {
                        showingLanguagePicker = false
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 删除账户确认对话框

    private var deleteAccountConfirmSheet: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 25) {
                // 标题
                HStack {
                    Text("删除账户".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.danger)

                    Spacer()

                    Button(action: {
                        showingDeleteAccountConfirm = false
                        deleteConfirmText = ""
                        deleteAccountError = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
                    .padding(.top, 10)

                // 警告信息
                VStack(spacing: 15) {
                    Text("此操作无法撤销！".localized)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.danger)

                    Text("删除账户将永久删除您的所有数据，包括：".localized)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("个人资料和账户信息".localized, systemImage: "person.fill")
                        Label("游戏进度和成就".localized, systemImage: "gamecontroller.fill")
                        Label("所有领地和资源".localized, systemImage: "flag.fill")
                    }
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.horizontal)

                // 确认输入
                VStack(spacing: 12) {
                    Text("请输入 \"删除\" 以确认操作".localized)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField("输入：删除".localized, text: $deleteConfirmText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(10)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(deleteConfirmText == "删除" ? ApocalypseTheme.danger : Color.clear, lineWidth: 2)
                        )
                }
                .padding(.horizontal)

                // 错误提示
                if let error = deleteAccountError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // 按钮组
                VStack(spacing: 12) {
                    // 确认删除按钮
                    Button(action: {
                        Task {
                            await handleDeleteAccount()
                        }
                    }) {
                        HStack(spacing: 10) {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash.fill")
                                    .font(.body)
                            }
                            Text(authManager.isLoading ? "删除中...".localized : "确认删除".localized)
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(deleteConfirmText == "删除" ? ApocalypseTheme.danger : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(deleteConfirmText != "删除" || authManager.isLoading)

                    // 取消按钮
                    Button(action: {
                        showingDeleteAccountConfirm = false
                        deleteConfirmText = ""
                        deleteAccountError = nil
                    }) {
                        Text("取消".localized)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(10)
                    }
                    .disabled(authManager.isLoading)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Computed Properties

    /// 格式化的探索距离
    private var formattedDistance: String {
        let distance = authManager.totalExplorationDistance
        if distance >= 1000 {
            return String(format: "%.1fkm", distance / 1000)
        } else {
            return "\(Int(distance))m"
        }
    }

    // MARK: - Helper Methods

    /// 处理删除账户
    private func handleDeleteAccount() async {
        print("🗑️ [UI] 用户点击确认删除按钮")

        do {
            try await authManager.deleteAccount()
            print("✅ [UI] 账户删除成功，关闭对话框")

            // 删除成功，关闭对话框
            showingDeleteAccountConfirm = false
            deleteConfirmText = ""
            deleteAccountError = nil

        } catch {
            print("❌ [UI] 账户删除失败: \(error.localizedDescription)")

            // 显示错误信息
            deleteAccountError = error.localizedDescription
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager())
}
