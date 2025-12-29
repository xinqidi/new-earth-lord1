//
//  AuthView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/29.
//

import SwiftUI

// MARK: - 认证页面

/// 《地球新主》游戏认证页面
/// 包含登录、注册、找回密码功能
struct AuthView: View {

    // MARK: - State Objects

    /// 认证管理器
    @StateObject private var authManager = AuthManager()

    // MARK: - State Variables

    /// 当前选中的 Tab（true=注册, false=登录）
    @State private var isRegistering = false

    /// 是否显示忘记密码弹窗
    @State private var showingResetPassword = false

    // 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerPasswordConfirm = ""
    @State private var registerStep = 1 // 1=邮箱, 2=验证码, 3=密码

    // 找回密码表单
    @State private var resetEmail = ""
    @State private var resetOTP = ""
    @State private var resetPassword = ""
    @State private var resetPasswordConfirm = ""
    @State private var resetStep = 1 // 1=邮箱, 2=验证码, 3=新密码

    // 验证码倒计时
    @State private var otpCountdown = 0
    @State private var otpTimer: Timer? = nil

    // Toast 提示
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    ApocalypseTheme.background,
                    Color(red: 0.12, green: 0.08, blue: 0.15)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // Logo 和标题
                    logoSection

                    // Tab 切换
                    tabSelector

                    // 登录或注册表单
                    if isRegistering {
                        registerFormSection
                    } else {
                        loginFormSection
                    }

                    // 分隔线
                    dividerSection

                    // 第三方登录
                    thirdPartySection

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 30)
                .padding(.top, 40)
            }

            // 加载指示器
            if authManager.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            }

            // Toast 提示
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: showToast)
            }
        }
        .sheet(isPresented: $showingResetPassword) {
            resetPasswordSheet
        }
        .onChange(of: authManager.otpVerified) { verified in
            // 注册流程：验证码验证成功后进入第三步
            if verified && isRegistering {
                registerStep = 3
            }
        }
        .onChange(of: authManager.errorMessage) { error in
            if let error = error {
                showToastMessage(error)
            }
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 15) {
            // Logo 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primary.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 游戏标题
            Text("地球新主")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("Earth Lord")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button(action: {
                withAnimation {
                    isRegistering = false
                    resetRegisterForm()
                }
            }) {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(isRegistering ? ApocalypseTheme.textSecondary : ApocalypseTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        isRegistering ? Color.clear : ApocalypseTheme.cardBackground
                    )
            }

            // 注册 Tab
            Button(action: {
                withAnimation {
                    isRegistering = true
                    resetLoginForm()
                }
            }) {
                Text("注册")
                    .font(.headline)
                    .foregroundColor(isRegistering ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        isRegistering ? ApocalypseTheme.cardBackground : Color.clear
                    )
            }
        }
        .background(ApocalypseTheme.background)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Login Form

    private var loginFormSection: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            VStack(alignment: .leading, spacing: 8) {
                Text("邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("请输入邮箱", text: $loginEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 密码输入
            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请输入密码", text: $loginPassword)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 忘记密码链接
            HStack {
                Spacer()
                Button(action: {
                    showingResetPassword = true
                    resetResetForm()
                }) {
                    Text("忘记密码？")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            // 登录按钮
            Button(action: handleLogin) {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)
            .opacity(loginEmail.isEmpty || loginPassword.isEmpty ? 0.5 : 1.0)
        }
        .padding(.top, 10)
    }

    // MARK: - Register Form

    private var registerFormSection: some View {
        VStack(spacing: 20) {
            // 步骤指示器
            registerStepIndicator

            // 根据步骤显示不同表单
            if registerStep == 1 {
                registerStep1EmailInput
            } else if registerStep == 2 {
                registerStep2OTPInput
            } else {
                registerStep3PasswordInput
            }
        }
        .padding(.top, 10)
    }

    // 注册步骤指示器
    private var registerStepIndicator: some View {
        HStack(spacing: 10) {
            ForEach(1...3, id: \.self) { step in
                Circle()
                    .fill(step <= registerStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 10, height: 10)
            }
        }
    }

    // 注册步骤1：邮箱输入
    private var registerStep1EmailInput: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("请输入邮箱", text: $registerEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Button(action: handleSendRegisterOTP) {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(registerEmail.isEmpty)
            .opacity(registerEmail.isEmpty ? 0.5 : 1.0)
        }
    }

    // 注册步骤2：验证码输入
    private var registerStep2OTPInput: some View {
        VStack(spacing: 20) {
            Text("验证码已发送至 \(registerEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("验证码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("请输入6位验证码", text: $registerOTP)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 验证按钮
            Button(action: handleVerifyRegisterOTP) {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(registerOTP.count != 6)
            .opacity(registerOTP.count != 6 ? 0.5 : 1.0)

            // 重发倒计时
            if otpCountdown > 0 {
                Text("重新发送（\(otpCountdown)s）")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button(action: handleSendRegisterOTP) {
                    Text("重新发送验证码")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // 注册步骤3：设置密码
    private var registerStep3PasswordInput: some View {
        VStack(spacing: 20) {
            Text("验证成功！请设置密码完成注册")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.success)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请输入密码（至少6位）", text: $registerPassword)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("确认密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请再次输入密码", text: $registerPasswordConfirm)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 密码不匹配提示
            if !registerPasswordConfirm.isEmpty && registerPassword != registerPasswordConfirm {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 完成注册按钮
            Button(action: handleCompleteRegistration) {
                Text("完成注册")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(!isRegisterPasswordValid)
            .opacity(isRegisterPasswordValid ? 1.0 : 0.5)
        }
    }

    // MARK: - Reset Password Sheet

    private var resetPasswordSheet: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // 标题
                HStack {
                    Text("找回密码")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Button(action: {
                        showingResetPassword = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // 步骤指示器
                HStack(spacing: 10) {
                    ForEach(1...3, id: \.self) { step in
                        Circle()
                            .fill(step <= resetStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            .frame(width: 10, height: 10)
                    }
                }

                ScrollView {
                    VStack(spacing: 20) {
                        if resetStep == 1 {
                            resetStep1EmailInput
                        } else if resetStep == 2 {
                            resetStep2OTPInput
                        } else {
                            resetStep3PasswordInput
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
    }

    // 找回密码步骤1：邮箱输入
    private var resetStep1EmailInput: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("请输入注册邮箱", text: $resetEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Button(action: handleSendResetOTP) {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(resetEmail.isEmpty)
            .opacity(resetEmail.isEmpty ? 0.5 : 1.0)
        }
    }

    // 找回密码步骤2：验证码输入
    private var resetStep2OTPInput: some View {
        VStack(spacing: 20) {
            Text("验证码已发送至 \(resetEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("验证码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("请输入6位验证码", text: $resetOTP)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Button(action: handleVerifyResetOTP) {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(resetOTP.count != 6)
            .opacity(resetOTP.count != 6 ? 0.5 : 1.0)

            if otpCountdown > 0 {
                Text("重新发送（\(otpCountdown)s）")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button(action: handleSendResetOTP) {
                    Text("重新发送验证码")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // 找回密码步骤3：设置新密码
    private var resetStep3PasswordInput: some View {
        VStack(spacing: 20) {
            Text("验证成功！请设置新密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.success)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("新密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请输入新密码（至少6位）", text: $resetPassword)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("确认密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请再次输入密码", text: $resetPasswordConfirm)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            if !resetPasswordConfirm.isEmpty && resetPassword != resetPasswordConfirm {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Button(action: handleResetPassword) {
                Text("重置密码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(!isResetPasswordValid)
            .opacity(isResetPasswordValid ? 1.0 : 0.5)
        }
    }

    // MARK: - Divider Section

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Third Party Section

    private var thirdPartySection: some View {
        VStack(spacing: 15) {
            // Apple 登录
            Button(action: handleAppleSignIn) {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("使用 Apple 登录")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(10)
            }

            // Google 登录
            Button(action: handleGoogleSignIn) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("使用 Google 登录")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Action Handlers

    /// 处理登录
    private func handleLogin() {
        Task {
            await authManager.signIn(email: loginEmail, password: loginPassword)
        }
    }

    /// 处理发送注册验证码
    private func handleSendRegisterOTP() {
        Task {
            await authManager.sendRegisterOTP(email: registerEmail)
            if authManager.otpSent {
                registerStep = 2
                startOTPCountdown()
            }
        }
    }

    /// 处理验证注册验证码
    private func handleVerifyRegisterOTP() {
        Task {
            await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
            // 验证成功会自动触发 onChange，进入步骤3
        }
    }

    /// 处理完成注册
    private func handleCompleteRegistration() {
        Task {
            await authManager.completeRegistration(password: registerPassword)
            // 成功后 isAuthenticated = true，自动跳转主页（由 RootView 处理）
        }
    }

    /// 处理发送重置密码验证码
    private func handleSendResetOTP() {
        Task {
            await authManager.sendResetOTP(email: resetEmail)
            if authManager.otpSent {
                resetStep = 2
                startOTPCountdown()
            }
        }
    }

    /// 处理验证重置密码验证码
    private func handleVerifyResetOTP() {
        Task {
            await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)
            if authManager.otpVerified {
                resetStep = 3
            }
        }
    }

    /// 处理重置密码
    private func handleResetPassword() {
        Task {
            await authManager.resetPassword(newPassword: resetPassword)
            if authManager.isAuthenticated {
                showingResetPassword = false
                showToastMessage("密码重置成功！")
            }
        }
    }

    /// 处理 Apple 登录（占位）
    private func handleAppleSignIn() {
        showToastMessage("Apple 登录即将开放")
    }

    /// 处理 Google 登录（占位）
    private func handleGoogleSignIn() {
        showToastMessage("Google 登录即将开放")
    }

    // MARK: - Helper Methods

    /// 开始验证码倒计时（60秒）
    private func startOTPCountdown() {
        otpCountdown = 60
        otpTimer?.invalidate()
        otpTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if otpCountdown > 0 {
                otpCountdown -= 1
            } else {
                otpTimer?.invalidate()
            }
        }
    }

    /// 显示 Toast 提示
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showToast = false
        }
    }

    /// 重置登录表单
    private func resetLoginForm() {
        loginEmail = ""
        loginPassword = ""
    }

    /// 重置注册表单
    private func resetRegisterForm() {
        registerEmail = ""
        registerOTP = ""
        registerPassword = ""
        registerPasswordConfirm = ""
        registerStep = 1
    }

    /// 重置找回密码表单
    private func resetResetForm() {
        resetEmail = ""
        resetOTP = ""
        resetPassword = ""
        resetPasswordConfirm = ""
        resetStep = 1
    }

    /// 验证注册密码是否有效
    private var isRegisterPasswordValid: Bool {
        return registerPassword.count >= 6 &&
               registerPassword == registerPasswordConfirm
    }

    /// 验证重置密码是否有效
    private var isResetPasswordValid: Bool {
        return resetPassword.count >= 6 &&
               resetPassword == resetPasswordConfirm
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}
