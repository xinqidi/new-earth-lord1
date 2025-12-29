//
//  AuthManager.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/29.
//

import SwiftUI
import Supabase
import Combine

// MARK: - 用户模型

/// 应用内用户信息模型
struct User: Identifiable {
    let id: UUID
    let email: String?
    let username: String?

    /// 显示名称（优先使用用户名，否则使用邮箱前缀）
    var displayName: String {
        if let username = username, !username.isEmpty {
            return username
        }
        if let email = email {
            return email.components(separatedBy: "@").first ?? "用户"
        }
        return "用户"
    }
}

// MARK: - 认证管理器

/// 《地球新主》游戏认证管理器
///
/// 认证流程说明：
/// - 注册：发验证码 → 验证（此时已登录但没密码）→ 强制设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证（此时已登录）→ 设置新密码 → 完成
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties

    /// 是否已完成认证（已登录且完成所有流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后必须设置密码）
    @Published var needsPasswordSetup: Bool = false

    /// 当前用户信息
    @Published var currentUser: User? = nil

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    /// Supabase 客户端实例（使用全局实例）
    private let supabase: SupabaseClient

    /// 临时存储的用户邮箱（用于完成注册/重置密码流程）
    private var pendingEmail: String?

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        // 初始化 Supabase 客户端
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://ipvkhcrgbbcccwiwlofd.supabase.co")!,
            supabaseKey: "sb_publishable_DCfb2P7IEr46I6jX-Wu_3g_Es4DTHEJ"
        )

        // 开始监听认证状态变化
        startAuthStateListener()
    }

    deinit {
        // 清理监听任务
        authStateTask?.cancel()
    }

    // MARK: - 认证状态监听

    /// 开始监听 Supabase 认证状态变化
    private func startAuthStateListener() {
        authStateTask = Task { @MainActor in
            for await (event, session) in supabase.auth.authStateChanges {
                handleAuthStateChange(event, session: session)
            }
        }
    }

    /// 处理认证状态变化
    /// - Parameters:
    ///   - event: 认证状态事件
    ///   - session: 会话信息（可选）
    private func handleAuthStateChange(_ event: AuthChangeEvent, session: Session?) {
        switch event {
        case .signedIn:
            // 用户登录
            if let session = session {
                updateUserFromSession(session)
            }

        case .signedOut:
            // 用户登出
            isAuthenticated = false
            currentUser = nil
            needsPasswordSetup = false
            errorMessage = nil

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                updateUserFromSession(session)
            }

        case .initialSession:
            // 初始会话（应用启动时）
            if let session = session {
                updateUserFromSession(session)
            }

        case .tokenRefreshed:
            // Token 刷新成功
            if let session = session {
                updateUserFromSession(session)
            }

        default:
            // 处理其他事件（如会话过期、错误等）
            // 会话过期或发生错误时，清除认证状态
            if session == nil && event != .signedOut {
                isAuthenticated = false
                currentUser = nil
                needsPasswordSetup = false
                errorMessage = "会话已过期，请重新登录"
            }
        }
    }

    /// 从会话更新用户信息
    /// - Parameter session: Supabase 会话
    private func updateUserFromSession(_ session: Session) {
        let user = session.user
        // 尝试从 user_metadata 获取用户名
        let username = user.userMetadata["username"]?.value as? String
        currentUser = User(id: user.id, email: user.email, username: username)

        // 如果有会话且不在注册流程中，标记为已认证
        if !needsPasswordSetup {
            isAuthenticated = true
        }
    }

    // MARK: - 注册流程

    /// 步骤1：发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 先检查用户是否已存在（尝试用不创建用户的方式发送OTP）
            // 如果用户已存在，这个调用会成功，说明邮箱已注册
            do {
                try await supabase.auth.signInWithOTP(
                    email: email,
                    shouldCreateUser: false
                )
                // 如果成功了，说明用户已存在
                errorMessage = "该邮箱已注册，请使用登录功能"
                otpSent = false
                isLoading = false
                return
            } catch {
                // 用户不存在，继续注册流程
            }

            // 调用 Supabase 发送 OTP，shouldCreateUser 为 true 表示允许创建新用户
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            // 成功发送
            otpSent = true
            pendingEmail = email
            errorMessage = nil

        } catch {
            // 发送失败
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            otpSent = false
        }

        isLoading = false
    }

    /// 步骤2：验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    ///
    /// ⚠️ 重要：验证成功后用户已登录，但 isAuthenticated 保持 false
    /// 直到完成密码设置才会变为 true
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        // ⚠️ 在调用 Supabase API 之前设置，避免时序问题
        needsPasswordSetup = true

        do {
            // 验证 OTP，type 为 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录但需要设置密码
            otpVerified = true
            pendingEmail = email

            // 设置当前用户信息
            let user = session.user
            let username = user.userMetadata["username"]?.value as? String
            currentUser = User(id: user.id, email: user.email, username: username)

            // ⚠️ 注意：此时 isAuthenticated 保持 false
            // 必须完成密码设置后才能进入主页

        } catch {
            errorMessage = "验证码错误: \(error.localizedDescription)"
            otpVerified = false
            needsPasswordSetup = false  // 验证失败，重置状态
        }

        isLoading = false
    }

    /// 步骤3：完成注册（设置密码）
    /// - Parameter password: 用户密码
    ///
    /// 只有完成此步骤后，用户才能正式进入应用
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let user = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 密码设置成功，完成注册流程
            needsPasswordSetup = false
            isAuthenticated = true

            // 更新用户信息
            let username = user.userMetadata["username"]?.value as? String
            currentUser = User(id: user.id, email: user.email, username: username)

            // 重置临时状态
            otpSent = false
            otpVerified = false
            pendingEmail = nil

        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 登录

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 直接使用邮箱密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功
            isAuthenticated = true
            needsPasswordSetup = false

            // 设置当前用户信息
            let user = session.user
            let username = user.userMetadata["username"]?.value as? String
            currentUser = User(id: user.id, email: user.email, username: username)

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            isAuthenticated = false
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 步骤1：发送重置密码验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件
            try await supabase.auth.resetPasswordForEmail(email)

            // 成功发送
            otpSent = true
            pendingEmail = email
            errorMessage = nil

        } catch {
            errorMessage = "发送重置邮件失败: \(error.localizedDescription)"
            otpSent = false
        }

        isLoading = false
    }

    /// 步骤2：验证重置密码验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    ///
    /// ⚠️ 注意：type 使用 .recovery 而不是 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        // ⚠️ 在调用 Supabase API 之前设置，避免时序问题
        needsPasswordSetup = true

        do {
            // 验证 OTP，type 为 .recovery（密码恢复）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功，用户已登录但需要设置新密码
            otpVerified = true
            pendingEmail = email

            // 设置当前用户信息
            let user = session.user
            let username = user.userMetadata["username"]?.value as? String
            currentUser = User(id: user.id, email: user.email, username: username)

        } catch {
            errorMessage = "验证码错误: \(error.localizedDescription)"
            otpVerified = false
            needsPasswordSetup = false  // 验证失败，重置状态
        }

        isLoading = false
    }

    /// 步骤3：重置密码
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let user = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置成功
            needsPasswordSetup = false
            isAuthenticated = true

            // 更新用户信息
            let username = user.userMetadata["username"]?.value as? String
            currentUser = User(id: user.id, email: user.email, username: username)

            // 重置临时状态
            otpSent = false
            otpVerified = false
            pendingEmail = nil

        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// TODO: 实现 Apple 第三方登录
    func signInWithApple() async {
        // TODO: 实现 Apple Sign In 集成
        // 1. 配置 Apple Developer 账号
        // 2. 在 Supabase Dashboard 配置 Apple Provider
        // 3. 使用 AuthenticationServices 框架
        errorMessage = "Apple 登录功能开发中..."
    }

    /// Google 登录
    /// TODO: 实现 Google 第三方登录
    func signInWithGoogle() async {
        // TODO: 实现 Google Sign In 集成
        // 1. 配置 Google Cloud Console
        // 2. 在 Supabase Dashboard 配置 Google Provider
        // 3. 使用 GoogleSignIn SDK
        errorMessage = "Google 登录功能开发中..."
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true

        do {
            // 调用 Supabase 退出登录
            try await supabase.auth.signOut()

            // 清除所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            pendingEmail = nil
            errorMessage = nil

        } catch {
            errorMessage = "退出登录失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 检查会话状态
    /// 在应用启动时调用，检查用户是否已登录
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            // 会话存在，用户已登录
            let user = session.user
            let username = user.userMetadata["username"]?.value as? String
            currentUser = User(id: user.id, email: user.email, username: username)

            // 检查用户是否已设置密码
            // 注意：Supabase v2.0 中，通过 OTP 登录后用户已经存在
            // 我们假设有密码的用户已完成完整注册流程
            // 这里简化处理：如果有会话就认为已完成认证
            isAuthenticated = true
            needsPasswordSetup = false

        } catch {
            // 会话检查失败或不存在
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }
}
