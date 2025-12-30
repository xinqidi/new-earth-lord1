# Google Sign In 配置说明

## ✅ 已完成的配置

1. **GoogleSignIn SDK** - 已手动添加
2. **Supabase Google Provider** - 已启用
3. **代码实现** - 已完成
   - App 文件添加 URL 处理
   - AuthManager 实现 Google 登录逻辑
   - AuthView 连接 Google 登录按钮

## ⚠️ 需要手动配置的项

### 在 Xcode 中添加 URL Scheme

1. 在 Xcode 中打开项目
2. 选择项目导航器中的 **new earth lord1** 项目
3. 选择 **TARGETS** → **new earth lord1**
4. 选择 **Info** 标签页
5. 展开 **URL Types** 部分（如果没有，点击 + 号添加）
6. 点击 + 号添加新的 URL Type
7. 在 **URL Schemes** 中添加：
   ```
   711485749722-71b8aajrgv0fj0l44vevpvd4ds1ah71a.apps.googleusercontent.com
   ```
8. **Identifier** 可以填写：`com.googleusercontent.apps.711485749722-71b8aajrgv0fj0l44vevpvd4ds1ah71a`

### 配置截图参考

```
URL Types
├── URL Schemes
│   └── 711485749722-71b8aajrgv0fj0l44vevpvd4ds1ah71a.apps.googleusercontent.com
└── Identifier (optional)
    └── com.googleusercontent.apps.711485749722-71b8aajrgv0fj0l44vevpvd4ds1ah71a
```

## 📋 验证配置

配置完成后，您可以：

1. 运行应用
2. 在登录页面点击 "使用 Google 登录"
3. 查看控制台日志，应该能看到以 🔵 [Google登录] 开头的日志
4. 完成 Google 登录流程

## 🐛 调试日志说明

所有 Google 登录相关的日志都以表情符号开头，便于识别：

- 🔵 - 流程开始
- 📱 - 获取视图控制器
- 🔧 - 配置 Google Sign In
- 🚀 - 启动登录界面
- ✅ - 操作成功
- 🔑 - Token 获取
- 🔐 - Supabase 登录
- 👤 - 用户信息
- ❌ - 错误信息
- ℹ️ - 提示信息
- 🏁 - 流程结束
- 🔗 - URL 回调

## ⚙️ 配置信息

- **Client ID**: `711485749722-71b8aajrgv0fj0l44vevpvd4ds1ah71a.apps.googleusercontent.com`
- **Supabase 设置**: Skip nonce check 已开启

## 常见问题

### Q: 点击 Google 登录后没有反应？
A: 检查控制台日志，查看是否有错误信息。确保 URL Scheme 已正确配置。

### Q: 提示 "无法初始化 Google 登录"？
A: 这可能是因为无法获取根视图控制器。确保应用已完全启动。

### Q: Google 登录成功但返回应用时出错？
A: 检查 URL Scheme 是否正确配置，确保与 Client ID 一致。

### Q: Supabase 登录失败？
A: 确认 Supabase Dashboard 中 Google Provider 已启用，并且 Client ID 已正确配置。
