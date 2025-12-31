# 语言切换功能使用说明

## ✅ 已实现的功能

### 1. 语言管理器 (LanguageManager)
- **位置**: `Managers/LanguageManager.swift`
- **功能**:
  - 管理App内语言切换
  - 持久化存储用户选择
  - 动态更新本地化Bundle
  - 无需重启App即可生效

### 2. 支持的语言选项
- **跟随系统**: 自动使用系统语言设置
- **简体中文**: 强制使用简体中文
- **English**: 强制使用英文

### 3. UI 界面
- **位置**: 个人中心 → 设置区域 → 语言
- **显示**: 当前选择的语言名称
- **操作**: 点击弹出语言选择器

## 📝 在代码中使用本地化字符串

### 方法 1：使用 .localized 扩展（推荐）

```swift
// 简单文本
Text("登录".localized)

// 带参数的文本
Text("验证码已发送至 %@".localized(email))

// 按钮标题
Button("发送验证码".localized) {
    // ...
}
```

### 方法 2：使用 NSLocalizedString

```swift
Text(NSLocalizedString("登录", comment: ""))
```

### 方法 3：使用 LanguageManager（不推荐，仅特殊情况）

```swift
Text(LanguageManager.shared.localizedString("登录"))
```

## 🔄 语言切换流程

1. 用户进入个人中心页面
2. 点击"语言"选项
3. 从列表中选择目标语言：
   - 跟随系统
   - 简体中文
   - English
4. 选择后自动关闭弹窗
5. 界面立即更新为选择的语言
6. 设置自动保存到 UserDefaults

## 🗂️ 文件结构

```
new earth lord1/
├── Managers/
│   └── LanguageManager.swift          # 语言管理器
├── Views/
│   └── Tabs/
│       └── ProfileTabView.swift       # 个人中心（含语言选择器）
├── Localizable.xcstrings              # 多语言翻译文件
└── new_earth_lord1App.swift           # App入口（注入LanguageManager）
```

## 🎯 关键代码说明

### LanguageManager 初始化

```swift
@main
struct new_earth_lord1App: App {
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(languageManager)  // ✅ 注入到环境
        }
    }
}
```

### 在 View 中使用

```swift
struct SomeView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        VStack {
            Text("地球新主".localized)
            Text(languageManager.currentLanguage.displayName)
        }
    }
}
```

### 持久化存储

语言选择自动保存到 `UserDefaults`，Key 为 `app_language`：
- `"system"` - 跟随系统
- `"zh-Hans"` - 简体中文
- `"en"` - English

## 📋 添加新翻译

在 `Localizable.xcstrings` 中添加新的翻译字符串：

```json
{
  "新功能标题" : {
    "localizations" : {
      "en" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "New Feature Title"
        }
      }
    }
  }
}
```

然后在代码中使用：

```swift
Text("新功能标题".localized)
```

## 🐛 调试日志

语言管理器会输出详细的调试日志：

```
🌍 [语言管理] 初始化语言管理器
✅ [语言管理] 读取已保存的语言设置: 简体中文
📦 [语言管理] 更新本地化Bundle
🌐 [语言管理] 使用指定语言: zh-Hans
✅ [语言管理] Bundle更新成功: zh-Hans
```

切换语言时：

```
🔄 [语言管理] 切换语言: 简体中文 → English
🌍 [语言管理] 语言切换为: English
💾 [语言管理] 语言设置已保存: en
📦 [语言管理] 更新本地化Bundle
🌐 [语言管理] 使用指定语言: en
✅ [语言管理] Bundle更新成功: en
```

## ⚠️ 注意事项

1. **所有可见文本都需要本地化**
   - 不要硬编码中文或英文文本
   - 使用 `.localized` 扩展

2. **占位符格式保持一致**
   ```swift
   // ✅ 正确
   "验证码已发送至 %@".localized(email)

   // ❌ 错误
   "验证码已发送至 " + email  // 无法翻译
   ```

3. **新增页面记得注入 LanguageManager**
   ```swift
   .environmentObject(languageManager)
   ```

4. **切换后立即生效**
   - 不需要重启App
   - 所有使用 `.localized` 的文本会自动更新

## 🎨 UI 样式

语言选择器使用了：
- NavigationView 结构
- List 展示语言选项
- Checkmark 显示当前选中项
- ApocalypseTheme 主题配色

## 📱 用户体验

- ✅ 切换无延迟
- ✅ 选择持久化
- ✅ 界面立即更新
- ✅ 三种语言选项
- ✅ 支持跟随系统

## 🔮 未来扩展

添加新语言时：

1. 在 `AppLanguage` 枚举中添加新 case
2. 在 Xcode 项目设置中添加对应的 Localization
3. 在 `Localizable.xcstrings` 中补充翻译
4. 更新 `displayName` 和 `languageCode`

例如添加繁体中文：

```swift
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case chinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"  // ✅ 新增
    case english = "en"

    var displayName: String {
        switch self {
        case .traditionalChinese:
            return "繁體中文"
        // ...
        }
    }
}
```
