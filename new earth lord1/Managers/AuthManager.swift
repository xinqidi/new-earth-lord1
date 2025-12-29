//
//  AuthManager.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/29.
//

import SwiftUI
import Supabase

// MARK: - 用户模型

/// 应用内用户信息模型
struct User: Identifiable {
    let id: UUID
    let email: String?
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

    // MARK: - Initialization

    init(supabaseClient: SupabaseClient = supabase) {
        self.supabase = supabaseClient
    }

    // MARK: - 注册流程

    /// 步骤1：发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
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

        do {
            // 验证 OTP，type 为 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录但需要设置密码
            otpVerified = true
            needsPasswordSetup = true
            pendingEmail = email

            // 设置当前用户信息
            if let user = session.user {
                currentUser = User(id: user.id, email: user.email)
            }

            // ⚠️ 注意：此时 isAuthenticated 保持 false
            // 必须完成密码设置后才能进入主页

        } catch {
            errorMessage = "验证码错误: \(error.localizedDescription)"
            otpVerified = false
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
            currentUser = User(id: user.id, email: user.email)

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
            if let user = session.user {
                currentUser = User(id: user.id, email: user.email)
            }

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

        do {
            // 验证 OTP，type 为 .recovery（密码恢复）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功，用户已登录但需要设置新密码
            otpVerified = true
            needsPasswordSetup = true
            pendingEmail = email

            // 设置当前用户信息
            if let user = session.user {
                currentUser = User(id: user.id, email: user.email)
            }

        } catch {
            errorMessage = "验证码错误: \(error.localizedDescription)"
            otpVerified = false
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
            currentUser = User(id: user.id, email: user.email)

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
            if let user = session.user {
                currentUser = User(id: user.id, email: user.email)

                // 检查用户是否已设置密码
                // 注意：Supabase v2.0 中，通过 OTP 登录后用户已经存在
                // 我们假设有密码的用户已完成完整注册流程
                // 这里简化处理：如果有会话就认为已完成认证
                isAuthenticated = true
                needsPasswordSetup = false
            } else {
                // 无会话，用户未登录
                isAuthenticated = false
                currentUser = nil
            }

        } catch {
            // 会话检查失败或不存在
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }
}
