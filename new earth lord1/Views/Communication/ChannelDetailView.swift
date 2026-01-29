//
//  ChannelDetailView.swift
//  new earth lord1
//
//  频道详情页面
//  支持订阅/取消订阅和删除（创建者）
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    let channel: CommunicationChannel

    @State private var showDeleteConfirm = false
    @State private var isProcessing = false
    @State private var showChatView = false

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    private var isCreator: Bool {
        communicationManager.isChannelCreator(channel: channel)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道头部
                    channelHeader

                    // 频道信息卡片
                    channelInfoCard

                    // 操作按钮
                    actionButtons
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .alert("确认删除".localized, isPresented: $showDeleteConfirm) {
                Button("取消".localized, role: .cancel) {}
                Button("删除".localized, role: .destructive) {
                    deleteChannel()
                }
            } message: {
                Text("删除后无法恢复，频道内所有消息也将被删除。确定要删除「\(channel.name)」吗？")
            }
            .fullScreenCover(isPresented: $showChatView) {
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
            }
        }
    }

    // MARK: - 频道头部

    private var channelHeader: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 名称
            Text(channel.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 频道码
            HStack(spacing: 8) {
                Text(channel.channelCode)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 复制按钮
                Button(action: {
                    UIPasteboard.general.string = channel.channelCode
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            // 订阅状态标签
            if isSubscribed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("已订阅".localized)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(16)
            }

            // 描述
            if let description = channel.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - 频道信息卡片

    private var channelInfoCard: some View {
        VStack(spacing: 0) {
            infoRow(icon: "antenna.radiowaves.left.and.right", title: "频道类型".localized, value: channel.channelType.displayName)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            infoRow(icon: "location.circle", title: "覆盖范围".localized, value: channel.channelType.rangeText)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            infoRow(icon: "person.2.fill", title: "成员数量".localized, value: "\(channel.memberCount)")

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            infoRow(icon: "calendar", title: "创建时间".localized, value: formatDate(channel.createdAt))
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(14)
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 进入聊天按钮（已订阅用户显示）
            if isSubscribed {
                Button(action: { showChatView = true }) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("进入聊天".localized)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }

            // 订阅/取消订阅按钮（非创建者显示）
            if !isCreator {
                Button(action: toggleSubscription) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }

                        Image(systemName: isSubscribed ? "bell.slash.fill" : "bell.fill")

                        Text(isSubscribed ? "取消订阅".localized : "订阅频道".localized)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSubscribed ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isProcessing)
            }

            // 删除按钮（仅创建者显示）
            if isCreator {
                Button(action: { showDeleteConfirm = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("删除频道".localized)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.danger)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Text("作为创建者，您可以删除此频道".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private func toggleSubscription() {
        isProcessing = true

        Task {
            if isSubscribed {
                let _ = await communicationManager.unsubscribeFromChannel(channelId: channel.id)
            } else {
                let _ = await communicationManager.subscribeToChannel(channelId: channel.id)
            }
            isProcessing = false
        }
    }

    private func deleteChannel() {
        isProcessing = true

        Task {
            let success = await communicationManager.deleteChannel(channelId: channel.id)
            isProcessing = false

            if success {
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    // 创建一个模拟的频道用于预览
    let mockChannel = try! JSONDecoder().decode(
        CommunicationChannel.self,
        from: """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "creator_id": "00000000-0000-0000-0000-000000000002",
            "channel_type": "public",
            "channel_code": "PUB-ABC123",
            "name": "测试频道",
            "description": "这是一个测试频道的描述",
            "is_active": true,
            "member_count": 42,
            "latitude": null,
            "longitude": null,
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
    )

    return ChannelDetailView(channel: mockChannel)
        .environmentObject(AuthManager())
}
