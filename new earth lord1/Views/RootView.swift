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

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

    /// 探索管理器
    @StateObject private var explorationManager = ExplorationManager()

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager()

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
                    .environmentObject(locationManager)
                    .environmentObject(explorationManager)
                    .environmentObject(inventoryManager)
                    .transition(.opacity)
                    .onAppear {
                        // 配置并启动玩家位置上报
                        configureAndStartPlayerLocationReporting()
                    }
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

    // MARK: - Private Methods

    /// 配置并启动玩家位置上报
    private func configureAndStartPlayerLocationReporting() {
        guard let userId = authManager.currentUser?.id else {
            print("⚠️ [位置上报] 用户未登录，跳过位置上报配置")
            return
        }

        // 配置 PlayerLocationManager
        PlayerLocationManager.shared.configure(
            supabase: authManager.supabase,
            userId: userId,
            locationManager: locationManager
        )

        // 同时配置 ExplorationManager（确保它也有正确的配置）
        explorationManager.configure(
            supabase: authManager.supabase,
            userId: userId,
            locationManager: locationManager
        )

        // 配置 AIItemGenerator
        AIItemGenerator.shared.configure(supabase: authManager.supabase)

        // 配置 InventoryManager
        inventoryManager.configure(supabase: authManager.supabase, userId: userId)

        // 配置 BuildingManager
        BuildingManager.shared.configure(
            supabase: authManager.supabase,
            userId: userId,
            inventoryManager: inventoryManager
        )

        // 配置 TradeManager
        TradeManager.shared.configure(
            supabase: authManager.supabase,
            userId: userId,
            username: authManager.currentUser?.displayName ?? "未知用户",
            inventoryManager: inventoryManager
        )

        // 配置 CommunicationManager
        CommunicationManager.shared.configure(
            supabase: authManager.supabase,
            userId: userId
        )

        // 加载背包、建筑模板、玩家建筑和通讯设备
        Task {
            // 首先加载背包（建造系统需要检查资源）
            await inventoryManager.loadInventory()

            // 然后加载建筑数据
            BuildingManager.shared.loadTemplates()
            await BuildingManager.shared.fetchPlayerBuildings(territoryId: nil)

            // 加载通讯设备
            await CommunicationManager.shared.loadDevices()
        }

        // 启动位置上报
        PlayerLocationManager.shared.startReporting()

        print("✅ [位置上报] 配置完成并开始上报")
    }
}

#Preview {
    RootView()
}
