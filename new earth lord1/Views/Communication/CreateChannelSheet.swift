//
//  CreateChannelSheet.swift
//  new earth lord1
//
//  创建频道表单
//  支持类型选择和表单验证
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedType: ChannelType = .publicChannel
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道类型选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("频道类型".localized)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        ForEach(ChannelType.creatableTypes, id: \.self) { type in
                            typeSelectionRow(type)
                        }
                    }

                    // 频道名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("频道名称".localized)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        TextField("输入频道名称".localized, text: $channelName)
                            .padding(12)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 验证提示
                        if !nameValidation.isValid && !channelName.isEmpty {
                            Text(nameValidation.message)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.danger)
                        } else {
                            Text("2-50个字符".localized)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    // 频道描述
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("频道描述".localized)
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("(可选)".localized)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        TextEditor(text: $channelDescription)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                    }

                    // 设备要求提示
                    if let requiredDevice = selectedType.requiredDevice {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(ApocalypseTheme.info)

                            Text("此频道需要\(requiredDevice.displayName)才能使用")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ApocalypseTheme.info.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // 创建按钮
                    Button(action: createChannel) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }

                            Text(isCreating ? "创建中...".localized : "创建频道".localized)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canCreate || isCreating)

                    // 错误提示
                    if let error = communicationManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("创建频道".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消".localized) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 类型选择行

    private func typeSelectionRow(_ type: ChannelType) -> some View {
        Button(action: { selectedType = type }) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(selectedType == type ? ApocalypseTheme.primary.opacity(0.2) : ApocalypseTheme.cardBackground)
                        .frame(width: 44, height: 44)

                    Image(systemName: type.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                }

                // 信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 选中标记
                if selectedType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedType == type ? ApocalypseTheme.primary : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - 验证

    private var nameValidation: (isValid: Bool, message: String) {
        let trimmed = channelName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return (false, "请输入频道名称".localized)
        } else if trimmed.count < 2 {
            return (false, "名称至少2个字符".localized)
        } else if trimmed.count > 50 {
            return (false, "名称最多50个字符".localized)
        }
        return (true, "")
    }

    private var canCreate: Bool {
        nameValidation.isValid
    }

    // MARK: - 创建频道

    private func createChannel() {
        isCreating = true

        let trimmedName = channelName.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = channelDescription.trimmingCharacters(in: .whitespaces)

        Task {
            let success = await communicationManager.createChannel(
                type: selectedType,
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription
            )

            isCreating = false

            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager())
}
