//
//  RootView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的流程
struct RootView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager()

    /// 语言管理器
    @EnvironmentObject private var languageManager: LanguageManager

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页（传入认证管理器以检查会话）
                SplashView(authManager: authManager, isFinished: $splashFinished)
                    .transition(.opacity)
            } else if authManager.isAuthenticated && !authManager.needsPasswordSetup {
                // 已认证且已完成密码设置 -> 显示主界面
                MainTabView()
                    .environmentObject(authManager)
                    .transition(.opacity)
            } else {
                // 未认证或需要设置密码 -> 显示登录/注册页
                AuthView()
                    .environmentObject(authManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.needsPasswordSetup)
        // 🔑 关键修复：当语言改变时，强制重新渲染整个 View 树
        .id(languageManager.currentLanguage)
    }
}

#Preview {
    RootView()
}
