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
            // 通过监听 currentLanguage 来确保 body 重新计算
            let _ = languageManager.currentLanguage

            return RootView()
                .environmentObject(languageManager)
                // 🔑 关键：设置环境 locale，让 SwiftUI 使用我们指定的语言
                .environment(\.locale, currentLocale)
                .onOpenURL { url in
                    print("🔗 [App] 收到 URL 回调: \(url)")
                    // 处理 Google Sign In 的 URL 回调
                    GIDSignIn.sharedInstance.handle(url)
                }
                // 强制在语言变化时重新渲染整个 App
                .id(languageManager.currentLanguage)
        }
    }

    /// 根据当前语言设置返回对应的 Locale
    private var currentLocale: Locale {
        if let code = languageManager.currentLanguage.languageCode {
            return Locale(identifier: code)
        } else {
            // 跟随系统
            return Locale.current
        }
    }
}
