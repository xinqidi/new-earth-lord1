//
//  CallsignSettingsSheet.swift
//  new earth lord1
//
//  呼号设置弹窗
//  允许用户设置电台身份标识
//

import SwiftUI
import Supabase

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var callsign: String = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    private var isValid: Bool {
        let trimmed = callsign.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.count <= 20
    }

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 说明
                        infoSection

                        // 输入框
                        inputSection

                        // 错误提示
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                        }

                        // 保存按钮
                        saveButton

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("呼号设置".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消".localized) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .onAppear {
            loadCurrentCallsign()
        }
        .alert("保存成功".localized, isPresented: $showingSuccess) {
            Button("确定".localized) {
                dismiss()
            }
        } message: {
            Text("您的呼号已更新为：\(callsign)")
        }
    }

    // MARK: - 说明区

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("什么是呼号？".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text("呼号是您在电波中的身份标识，其他幸存者会通过呼号识别您。就像真实电台中的 \"CQ CQ，这里是 BJ-Alpha-001\"。".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 格式示例
            VStack(alignment: .leading, spacing: 4) {
                Text("推荐格式：".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    ForEach(["BJ-Alpha-001", "SH-Beta-42", "Survivor-X"], id: \.self) { example in
                        Text(example)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 输入区

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("您的呼号".localized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 48)
            } else {
                TextField("输入呼号（3-20字符）".localized, text: $callsign)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(14)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isValid ? ApocalypseTheme.primary : Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }

            Text("仅支持字母、数字和连字符（-）".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 保存按钮

    private var saveButton: some View {
        Button(action: saveCallsign) {
            if isSaving {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("保存呼号".localized)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isValid ? ApocalypseTheme.primary : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(!isValid || isSaving)
    }

    // MARK: - 方法

    private func loadCurrentCallsign() {
        guard let userId = authManager.currentUser?.id else { return }

        isLoading = true

        Task {
            do {
                let response: [ProfileCallsign] = try await authManager.supabase
                    .from("profiles")
                    .select("callsign")
                    .eq("id", value: userId.uuidString)
                    .execute()
                    .value

                await MainActor.run {
                    callsign = response.first?.callsign ?? ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ [呼号] 加载失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func saveCallsign() {
        guard isValid else { return }

        // 验证格式：仅字母、数字、连字符
        let pattern = "^[A-Za-z0-9-]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(callsign.startIndex..., in: callsign)

        if regex?.firstMatch(in: callsign, range: range) == nil {
            errorMessage = "呼号只能包含字母、数字和连字符".localized
            return
        }

        guard let userId = authManager.currentUser?.id else {
            errorMessage = "用户未登录".localized
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                // 先尝试更新现有 profile
                try await authManager.supabase
                    .from("profiles")
                    .update(["callsign": callsign])
                    .eq("id", value: userId.uuidString)
                    .execute()

                // 检查是否更新成功（通过查询确认）
                struct ProfileCheck: Decodable {
                    let id: UUID
                    let callsign: String?
                }

                let profiles: [ProfileCheck] = try await authManager.supabase
                    .from("profiles")
                    .select("id, callsign")
                    .eq("id", value: userId.uuidString)
                    .execute()
                    .value

                if profiles.isEmpty {
                    // Profile 不存在，创建新的
                    print("⚠️ [呼号] Profile 不存在，创建新的...")

                    // 获取用户名（从 email 或默认值）
                    let username = authManager.currentUser?.email?.components(separatedBy: "@").first ?? "user_\(userId.uuidString.prefix(8))"

                    struct NewProfile: Encodable {
                        let id: String
                        let username: String
                        let callsign: String
                    }

                    let newProfile = NewProfile(
                        id: userId.uuidString,
                        username: username,
                        callsign: callsign
                    )

                    try await authManager.supabase
                        .from("profiles")
                        .insert(newProfile)
                        .execute()
                }

                await MainActor.run {
                    isSaving = false
                    showingSuccess = true
                    print("✅ [呼号] 保存成功: \(callsign)")
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "保存失败：\(error.localizedDescription)"
                    print("❌ [呼号] 保存失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// 用于解码呼号的辅助结构
private struct ProfileCallsign: Codable {
    let callsign: String?
}

#Preview {
    CallsignSettingsSheet()
        .environmentObject(AuthManager())
}
