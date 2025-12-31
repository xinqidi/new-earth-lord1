//
//  new_earth_lord1App.swift
//  new earth lord1
//
//  Created by 新起点 on 2025/12/23.
//

import SwiftUI
import GoogleSignIn

@main
struct new_earth_lord1App: App {
    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(languageManager)
                .onOpenURL { url in
                    print("🔗 [App] 收到 URL 回调: \(url)")
                    // 处理 Google Sign In 的 URL 回调
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
