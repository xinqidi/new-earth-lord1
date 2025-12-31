//
//  LanguageManager.swift
//  new earth lord1
//
//  语言管理器
//  支持App内语言切换，无需依赖系统设置
//

import SwiftUI
import Combine

/// 语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case chinese = "zh-Hans"    // 简体中文
    case english = "en"         // English

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return NSLocalizedString("跟随系统", bundle: Bundle.main, comment: "")
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 语言代码（用于Bundle）
    var languageCode: String? {
        switch self {
        case .system:
            return nil  // 使用系统语言
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

/// 语言管理器
/// 管理App内的语言切换和本地化
@MainActor
class LanguageManager: ObservableObject {

    // MARK: - Published Properties

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            print("🌍 [语言管理] 语言切换为: \(currentLanguage.displayName)")
            saveLanguage()
            updateBundle()
            // 通知UI更新
            objectWillChange.send()
        }
    }

    /// 本地化Bundle（用于获取翻译）
    @Published var bundle: Bundle = Bundle.main

    // MARK: - Private Properties

    /// UserDefaults存储Key
    private let languageKey = "app_language"

    // MARK: - Singleton

    /// 单例实例
    static let shared = LanguageManager()

    // MARK: - Initialization

    private init() {
        print("🌍 [语言管理] 初始化语言管理器")

        // 从UserDefaults读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            print("✅ [语言管理] 读取已保存的语言设置: \(language.displayName)")
            self.currentLanguage = language
        } else {
            print("ℹ️ [语言管理] 未找到保存的语言设置，使用系统默认")
            self.currentLanguage = .system
        }

        // 初始化Bundle
        updateBundle()
    }

    // MARK: - Public Methods

    /// 切换语言
    /// - Parameter language: 目标语言
    func setLanguage(_ language: AppLanguage) {
        print("🔄 [语言管理] 切换语言: \(currentLanguage.displayName) → \(language.displayName)")
        currentLanguage = language
    }

    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 本地化Key
    ///   - comment: 注释
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, comment: String = "") -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    // MARK: - Private Methods

    /// 保存语言设置到UserDefaults
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("💾 [语言管理] 语言设置已保存: \(currentLanguage.rawValue)")
    }

    /// 更新本地化Bundle
    private func updateBundle() {
        print("📦 [语言管理] 更新本地化Bundle")

        // 获取语言代码
        let languageCode: String

        if let code = currentLanguage.languageCode {
            // 使用指定语言
            languageCode = code
            print("🌐 [语言管理] 使用指定语言: \(languageCode)")
        } else {
            // 跟随系统语言
            languageCode = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
            print("🌐 [语言管理] 跟随系统语言: \(languageCode)")
        }

        // 查找对应的Bundle
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            self.bundle = langBundle
            print("✅ [语言管理] Bundle更新成功: \(languageCode)")
        } else {
            // 如果找不到，回退到英文
            if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let langBundle = Bundle(path: path) {
                self.bundle = langBundle
                print("⚠️ [语言管理] 未找到 \(languageCode) Bundle，回退到英文")
            } else {
                // 如果英文也找不到，使用主Bundle
                self.bundle = Bundle.main
                print("⚠️ [语言管理] 未找到语言包，使用主Bundle")
            }
        }
    }
}

// MARK: - String Extension

/// String扩展，提供便捷的本地化方法
extension String {
    /// 获取本地化字符串
    var localized: String {
        return LanguageManager.shared.localizedString(self)
    }

    /// 获取本地化字符串（带参数）
    func localized(_ arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - View Extension

/// View扩展，监听语言变化
extension View {
    /// 监听语言变化并更新View
    func languageUpdate() -> some View {
        self.environmentObject(LanguageManager.shared)
    }
}
