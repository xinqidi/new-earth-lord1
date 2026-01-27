//
//  AuthManager.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/29.
//

import SwiftUI
import Supabase
import Combine
import GoogleSignIn
import AuthenticationServices

// MARK: - 辅助类型

/// 用于解码任意 JSON 值的类型
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        default:
            break
        }
    }
}

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

/// 《行走的领主》游戏认证管理器
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

    // MARK: - User Statistics

    /// 用户领地数量
    @Published var territoryCount: Int = 0

    /// 用户资源点数量
    @Published var resourcePointCount: Int = 0

    /// 累计探索距离（米）
    @Published var totalExplorationDistance: Double = 0

    // MARK: - Internal Properties

    /// Supabase 客户端实例（使用全局实例）
    let supabase: SupabaseClient

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
                errorMessage = "会话已过期，请重新登录".localized
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
                errorMessage = "该邮箱已注册，请使用登录功能".localized
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

    // MARK: - 第三方登录

    /// Apple 登录
    /// 使用 AuthenticationServices 框架与 Supabase 集成
    func signInWithApple() async {
        print("🍎 [Apple登录] 开始 Apple 登录流程")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 执行 Apple 登录获取凭证
            print("🚀 [Apple登录] 启动 Apple 登录界面...")
            let coordinator = SignInWithAppleCoordinator()
            let appleResult = try await coordinator.signIn()
            print("✅ [Apple登录] Apple 登录成功，获取到 ID Token")

            // 2. 使用 Supabase 登录
            print("🔐 [Apple登录] 使用 Apple 凭证登录 Supabase...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: appleResult.idToken,
                    nonce: nil
                )
            )
            print("✅ [Apple登录] Supabase 登录成功")

            // 3. 如果 Apple 提供了用户全名，保存到 user_metadata
            // Apple 只在用户首次授权时提供全名
            if let fullName = appleResult.fullName, !fullName.isEmpty {
                print("👤 [Apple登录] 检测到用户全名: \(fullName)，保存到 metadata")
                do {
                    _ = try await supabase.auth.update(
                        user: UserAttributes(data: ["full_name": .string(fullName)])
                    )
                    print("✅ [Apple登录] 用户全名已保存")
                } catch {
                    print("⚠️ [Apple登录] 保存用户全名失败: \(error.localizedDescription)")
                }
            }

            // 4. 更新用户状态
            let user = session.user
            let username = user.userMetadata["username"]?.value as? String
            let savedFullName = user.userMetadata["full_name"]?.value as? String

            print("👤 [Apple登录] 用户信息:")
            print("   - ID: \(user.id)")
            print("   - Email: \(user.email ?? "无")")
            print("   - Username: \(username ?? "无")")
            print("   - Full Name: \(savedFullName ?? "无")")

            currentUser = User(
                id: user.id,
                email: user.email,
                username: username ?? savedFullName ?? appleResult.fullName
            )

            // 5. 设置认证状态
            isAuthenticated = true
            needsPasswordSetup = false
            print("✅ [Apple登录] 用户状态已更新，登录完成")

        } catch let error as SignInWithAppleError {
            print("❌ [Apple登录] Apple Sign In 错误: \(error)")

            switch error {
            case .cancelled:
                print("ℹ️ [Apple登录] 用户取消了登录")
                errorMessage = nil
            case .failed(let message):
                errorMessage = "Apple 登录失败: \(message)"
            case .invalidCredential:
                errorMessage = "Apple 登录失败：凭证无效".localized
            case .noIdToken:
                errorMessage = "Apple 登录失败：无法获取身份令牌".localized
            }
        } catch {
            print("❌ [Apple登录] 发生异常: \(error.localizedDescription)")
            errorMessage = "Apple 登录失败: \(error.localizedDescription)"
        }

        isLoading = false
        print("🏁 [Apple登录] Apple 登录流程结束")
    }

    /// Google 登录
    /// 使用 Google Sign In SDK 和 Supabase 集成
    func signInWithGoogle() async {
        print("🔵 [Google登录] 开始 Google 登录流程")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取根视图控制器
            print("📱 [Google登录] 获取根视图控制器...")
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ [Google登录] 无法获取根视图控制器")
                errorMessage = "无法初始化 Google 登录".localized
                isLoading = false
                return
            }
            print("✅ [Google登录] 根视图控制器获取成功")

            // 2. 配置 Google Sign In
            let clientID = "711485749722-71b8aajrgv0fj0l44vevpvd4ds1ah71a.apps.googleusercontent.com"
            print("🔧 [Google登录] 配置 Google Sign In，Client ID: \(clientID)")
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            // 3. 执行 Google 登录
            print("🚀 [Google登录] 启动 Google 登录界面...")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            print("✅ [Google登录] Google 登录成功")

            // 4. 获取 ID Token
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ [Google登录] 无法获取 ID Token")
                errorMessage = "Google 登录失败：无法获取身份令牌".localized
                isLoading = false
                return
            }
            print("🔑 [Google登录] ID Token 获取成功: \(idToken.prefix(20))...")

            // 5. 获取 Access Token
            let accessToken = result.user.accessToken.tokenString
            print("🔑 [Google登录] Access Token 获取成功: \(accessToken.prefix(20))...")

            // 6. 使用 Supabase 登录
            print("🔐 [Google登录] 使用 Google 凭证登录 Supabase...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken,
                    nonce: nil
                )
            )
            print("✅ [Google登录] Supabase 登录成功")

            // 7. 更新用户状态
            let user = session.user
            let username = user.userMetadata["username"]?.value as? String
            let fullName = user.userMetadata["full_name"]?.value as? String

            print("👤 [Google登录] 用户信息:")
            print("   - ID: \(user.id)")
            print("   - Email: \(user.email ?? "无")")
            print("   - Username: \(username ?? "无")")
            print("   - Full Name: \(fullName ?? "无")")

            currentUser = User(
                id: user.id,
                email: user.email,
                username: username ?? fullName
            )

            // 8. 设置认证状态
            isAuthenticated = true
            needsPasswordSetup = false
            print("✅ [Google登录] 用户状态已更新，登录完成")

        } catch let error as GIDSignInError {
            print("❌ [Google登录] Google Sign In 错误: \(error.localizedDescription)")

            // 处理用户取消登录的情况
            if error.code == .canceled {
                print("ℹ️ [Google登录] 用户取消了登录")
                errorMessage = nil  // 用户取消不显示错误
            } else {
                errorMessage = "Google 登录失败: \(error.localizedDescription)"
            }
        } catch {
            print("❌ [Google登录] 发生异常: \(error.localizedDescription)")
            errorMessage = "Google 登录失败: \(error.localizedDescription)"
        }

        isLoading = false
        print("🏁 [Google登录] Google 登录流程结束")
    }

    // MARK: - 用户统计

    /// 加载用户统计数据（领地数量、资源点数量、探索距离）
    func loadUserStats() async {
        guard let userId = currentUser?.id else {
            print("⚠️ [统计] 用户未登录，跳过统计加载")
            return
        }

        print("📊 [统计] 开始加载用户统计数据...")

        // 并行加载所有统计数据
        async let territoriesTask = loadTerritoryCount(userId: userId)
        async let explorationTask = loadExplorationStats(userId: userId)

        let (territories, exploration) = await (territoriesTask, explorationTask)

        await MainActor.run {
            self.territoryCount = territories
            self.totalExplorationDistance = exploration
            // 资源点暂时设为0，后续可以添加
            self.resourcePointCount = 0
        }

        print("📊 [统计] 加载完成 - 领地: \(territories), 探索距离: \(Int(exploration))m")
    }

    /// 加载领地数量
    private func loadTerritoryCount(userId: UUID) async -> Int {
        do {
            struct CountResult: Decodable {
                let count: Int
            }

            let response: [CountResult] = try await supabase
                .from("territories")
                .select("count", head: false, count: .exact)
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            // 使用 count 查询返回的结果
            return response.first?.count ?? 0
        } catch {
            print("❌ [统计] 加载领地数量失败: \(error.localizedDescription)")

            // 备用方案：直接查询并计数
            do {
                struct Territory: Decodable {
                    let id: UUID
                }

                let territories: [Territory] = try await supabase
                    .from("territories")
                    .select("id")
                    .eq("user_id", value: userId.uuidString)
                    .eq("is_active", value: true)
                    .execute()
                    .value

                return territories.count
            } catch {
                print("❌ [统计] 备用领地查询也失败: \(error.localizedDescription)")
                return 0
            }
        }
    }

    /// 加载探索统计数据（累计距离）
    private func loadExplorationStats(userId: UUID) async -> Double {
        do {
            struct ExplorationRecord: Decodable {
                let distance: Double?
            }

            let records: [ExplorationRecord] = try await supabase
                .from("exploration_records")
                .select("distance")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            // 计算总距离
            let total = records.compactMap { $0.distance }.reduce(0, +)
            return total
        } catch {
            print("❌ [统计] 加载探索距离失败: \(error.localizedDescription)")
            return 0
        }
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

            // 清除统计数据
            territoryCount = 0
            resourcePointCount = 0
            totalExplorationDistance = 0

        } catch {
            errorMessage = "退出登录失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 删除账户
    /// 调用边缘函数永久删除用户账户
    func deleteAccount() async throws {
        print("🗑️ [删除账户] 开始删除账户流程")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前会话
            print("🔑 [删除账户] 获取当前用户会话...")
            guard let session = try? await supabase.auth.session else {
                print("❌ [删除账户] 未找到有效会话")
                throw NSError(
                    domain: "DeleteAccount",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "未登录，无法删除账户"]
                )
            }
            print("✅ [删除账户] 会话获取成功，用户ID: \(session.user.id)")

            // 2. 构建请求
            let functionURL = "https://ipvkhcrgbbcccwiwlofd.supabase.co/functions/v1/delete-account"
            print("🌐 [删除账户] 调用边缘函数: \(functionURL)")

            guard let url = URL(string: functionURL) else {
                print("❌ [删除账户] URL 构建失败")
                throw NSError(
                    domain: "DeleteAccount",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "内部错误：无效的 URL"]
                )
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            print("📤 [删除账户] 请求已构建，携带 JWT token")

            // 3. 发送请求
            print("⏳ [删除账户] 发送删除请求...")
            let (data, response) = try await URLSession.shared.data(for: request)

            // 4. 处理响应
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [删除账户] 无效的响应类型")
                throw NSError(
                    domain: "DeleteAccount",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "服务器响应异常"]
                )
            }

            print("📥 [删除账户] 收到响应，状态码: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 200 {
                // 成功删除
                print("✅ [删除账户] 账户删除成功")

                // 解析响应（可选）
                if let json = try? JSONDecoder().decode([String: AnyCodable].self, from: data) {
                    print("📋 [删除账户] 响应数据: \(json)")
                }

                // 5. 清除 Supabase 本地会话缓存
                print("🗑️ [删除账户] 清除 Supabase 本地会话缓存...")
                do {
                    try await supabase.auth.signOut()
                    print("✅ [删除账户] Supabase 会话缓存已清除")
                } catch {
                    print("⚠️ [删除账户] 清除会话缓存时出错: \(error.localizedDescription)")
                    // 即使清除缓存失败，也继续清除本地状态
                }

                // 6. 清除应用内本地状态
                print("🧹 [删除账户] 清除应用内用户状态")
                isAuthenticated = false
                needsPasswordSetup = false
                currentUser = nil
                otpSent = false
                otpVerified = false
                pendingEmail = nil
                errorMessage = nil

            } else {
                // 删除失败
                print("❌ [删除账户] 删除失败，状态码: \(httpResponse.statusCode)")

                // 尝试解析错误信息
                if let errorJson = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMsg = errorJson["error"] {
                    print("📋 [删除账户] 错误信息: \(errorMsg)")
                    throw NSError(
                        domain: "DeleteAccount",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: errorMsg]
                    )
                } else {
                    print("📋 [删除账户] 未知错误")
                    throw NSError(
                        domain: "DeleteAccount",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "删除账户失败（状态码: \(httpResponse.statusCode)）"]
                    )
                }
            }

        } catch {
            print("❌ [删除账户] 发生异常: \(error.localizedDescription)")
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            isLoading = false
            throw error
        }

        isLoading = false
        print("🏁 [删除账户] 删除账户流程结束")
    }

    /// 检查会话状态
    /// 在应用启动时调用，检查用户是否已登录
    func checkSession() async {
        print("🔍 [会话检查] 开始检查用户会话状态")
        isLoading = true

        do {
            // 获取当前会话
            print("📱 [会话检查] 尝试从本地获取会话...")
            let session = try await supabase.auth.session

            // 会话存在，验证用户信息
            let user = session.user
            print("✅ [会话检查] 找到本地会话")
            print("👤 [会话检查] 用户ID: \(user.id)")
            print("📧 [会话检查] 用户邮箱: \(user.email ?? "无")")

            // 提取用户名
            let username = user.userMetadata["username"]?.value as? String
            let fullName = user.userMetadata["full_name"]?.value as? String

            currentUser = User(
                id: user.id,
                email: user.email,
                username: username ?? fullName
            )

            // 检查用户是否已设置密码
            // 注意：Supabase v2.0 中，通过 OTP 登录后用户已经存在
            // 我们假设有密码的用户已完成完整注册流程
            // 这里简化处理：如果有会话就认为已完成认证
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ [会话检查] 用户会话有效，自动登录成功")

        } catch {
            // 会话检查失败或不存在
            print("ℹ️ [会话检查] 未找到有效会话或会话已过期")
            print("📋 [会话检查] 错误详情: \(error.localizedDescription)")

            isAuthenticated = false
            currentUser = nil

            print("🔓 [会话检查] 用户未登录，显示登录页面")
        }

        isLoading = false
        print("🏁 [会话检查] 会话检查完成")
    }
}

// MARK: - Sign in with Apple 辅助类型

/// Apple 登录结果
struct AppleSignInResult {
    let idToken: String
    let fullName: String?
    let email: String?
}

/// Sign in with Apple 错误类型
enum SignInWithAppleError: Error {
    case cancelled
    case failed(String)
    case invalidCredential
    case noIdToken
}

/// Sign in with Apple 协调器
class SignInWithAppleCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    @MainActor
    func signIn() async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: SignInWithAppleError.invalidCredential)
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            continuation?.resume(throwing: SignInWithAppleError.noIdToken)
            return
        }

        var fullName: String? = nil
        if let nameComponents = appleIDCredential.fullName {
            let formatter = PersonNameComponentsFormatter()
            formatter.style = .default
            let formattedName = formatter.string(from: nameComponents)
            if !formattedName.isEmpty {
                fullName = formattedName
            }
        }

        let result = AppleSignInResult(
            idToken: idToken,
            fullName: fullName,
            email: appleIDCredential.email
        )
        continuation?.resume(returning: result)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                continuation?.resume(throwing: SignInWithAppleError.cancelled)
            default:
                continuation?.resume(throwing: SignInWithAppleError.failed(authError.localizedDescription))
            }
        } else {
            continuation?.resume(throwing: SignInWithAppleError.failed(error.localizedDescription))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
