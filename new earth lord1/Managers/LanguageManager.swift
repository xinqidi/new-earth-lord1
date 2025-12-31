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

    /// 显示名称（本地化 Key）
    /// 返回需要本地化的 key，由调用者负责本地化
    /// 这样可以避免在初始化时产生循环依赖
    var displayNameKey: String {
        switch self {
        case .system:
            return "跟随系统"
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 显示名称（已本地化）
    /// 使用 LanguageManager 的翻译
    func displayName(languageManager: LanguageManager) -> String {
        switch self {
        case .system:
            // "跟随系统"需要本地化
            return languageManager.localizedString("跟随系统")
        case .chinese:
            // 语言名称固定显示为原生文字，方便用户识别
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
            print("🌍 [语言管理] 语言切换为: \(currentLanguage.displayNameKey)")
            saveLanguage()
            updateBundle()
        }
    }

    /// 本地化Bundle
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
            print("✅ [语言管理] 读取已保存的语言设置: \(language.displayNameKey)")
            self.currentLanguage = language
        } else {
            print("ℹ️ [语言管理] 未找到保存的语言设置，使用系统默认")
            self.currentLanguage = .system
        }

        // 设置本地化 Bundle
        updateBundle()
    }

    // MARK: - Public Methods

    /// 切换语言
    /// - Parameter language: 目标语言
    func setLanguage(_ language: AppLanguage) {
        print("🔄 [语言管理] 切换语言: \(currentLanguage.displayNameKey) → \(language.displayNameKey)")
        currentLanguage = language
    }

    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 本地化Key
    ///   - comment: 注释
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, comment: String = "") -> String {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    // MARK: - Private Methods

    /// 保存语言设置到UserDefaults
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("💾 [语言管理] 语言设置已保存: \(currentLanguage.rawValue)")
    }

    /// 更新本地化 Bundle
    private func updateBundle() {
        print("📚 [语言管理] 更新本地化 Bundle")

        // 获取目标语言代码
        guard let languageCode = currentLanguage.languageCode else {
            // 跟随系统语言
            self.bundle = Bundle.main
            print("🌐 [语言管理] 使用系统语言")
            return
        }

        print("🌐 [语言管理] 目标语言: \(languageCode)")

        // 查找对应语言的 .lproj 文件夹路径
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            self.bundle = langBundle
            print("✅ [语言管理] 成功加载语言包: \(languageCode).lproj")
        } else {
            // 如果找不到对应的语言包，回退到主 Bundle
            self.bundle = Bundle.main
            print("⚠️ [语言管理] 未找到 \(languageCode).lproj，使用默认 Bundle")
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
