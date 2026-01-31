//
//  ChannelChatView.swift
//  new earth lord1
//
//  频道聊天界面
//  支持消息发送、实时接收、设备模式切换
//

import SwiftUI
import Supabase
import CoreLocation

struct ChannelChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    let channel: CommunicationChannel

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?

    // 当前用户ID
    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    // 当前设备是否可以发送消息
    private var canSend: Bool {
        communicationManager.canSendMessage()
    }

    // 当前设备类型
    private var currentDeviceType: DeviceType {
        communicationManager.getCurrentDeviceType()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 导航栏
            navigationBar

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 消息列表
            messageListView

            // 输入栏或收音机提示
            if canSend {
                inputBar
            } else {
                radioModeHint
            }
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            setupChat()
        }
        .onDisappear {
            cleanupChat()
        }
        .onChange(of: communicationManager.getMessages(for: channel.id).count) { _ in
            scrollToBottom()
        }
    }

    // MARK: - 导航栏

    private var navigationBar: some View {
        HStack(spacing: 12) {
            // 返回按钮
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(channel.channelCode)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("·")
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    HStack(spacing: 2) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(channel.memberCount)")
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 当前设备指示器
            HStack(spacing: 4) {
                Image(systemName: currentDeviceType.iconName)
                    .font(.system(size: 12))
                Text(currentDeviceType.rangeText)
                    .font(.caption2)
            }
            .foregroundColor(ApocalypseTheme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ApocalypseTheme.primary.opacity(0.15))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    let messages = communicationManager.getMessages(for: channel.id)

                    if messages.isEmpty {
                        emptyMessageView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwnMessage: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(16)
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
        }
    }

    // MARK: - 空消息视图

    private var emptyMessageView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 100)

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.3))

            Text("暂无消息".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("发送第一条消息吧".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 12) {
            // 输入框
            TextField("输入消息...".localized, text: $messageText)
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 发送按钮
            Button(action: sendMessage) {
                if communicationManager.isSendingMessage {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 44, height: 44)
                        .background(ApocalypseTheme.textSecondary)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)
                        .clipShape(Circle())
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || communicationManager.isSendingMessage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 收音机模式提示

    private var radioModeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .font(.system(size: 16))

            Text("收音机模式：只能收听，无法发送消息".localized)
                .font(.subheadline)
        }
        .foregroundColor(ApocalypseTheme.warning)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.warning.opacity(0.1))
    }

    // MARK: - Actions

    private func setupChat() {
        // 订阅频道消息的 Realtime
        communicationManager.subscribeToChannelMessages(channelId: channel.id)

        // 加载历史消息
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
        }
    }

    private func cleanupChat() {
        // 取消订阅
        communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        let deviceType = currentDeviceType.rawValue

        // Day 35-B: 从 LocationManager 获取真实 GPS 位置
        let location = LocationManager.shared.userLocation
        let latitude = location?.latitude
        let longitude = location?.longitude

        Task {
            let success = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: content,
                latitude: latitude,
                longitude: longitude,
                deviceType: deviceType
            )

            if success {
                messageText = ""
            }
        }
    }

    private func scrollToBottom() {
        let messages = communicationManager.getMessages(for: channel.id)
        if let lastMessage = messages.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - 消息气泡视图

struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwnMessage: Bool

    var body: some View {
        HStack {
            if isOwnMessage { Spacer() }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                // 发送者信息（仅他人消息显示）
                if !isOwnMessage {
                    HStack(spacing: 4) {
                        Text(message.senderCallsign ?? "匿名用户".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.primary)

                        // 设备图标
                        if let deviceType = message.deviceType {
                            Image(systemName: deviceIconName(for: deviceType))
                                .font(.system(size: 10))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                }

                // 消息内容
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isOwnMessage ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                    .cornerRadius(16)

                // 时间
                Text(message.timeString)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            if !isOwnMessage { Spacer() }
        }
    }

    private func deviceIconName(for deviceType: String) -> String {
        switch deviceType {
        case "radio": return "radio"
        case "walkieTalkie", "walkie_talkie": return "antenna.radiowaves.left.and.right"
        case "campRadio", "camp_radio": return "antenna.radiowaves.left.and.right"
        case "satellite": return "antenna.radiowaves.left.and.right.circle"
        default: return "iphone"
        }
    }
}

#Preview {
    let mockChannel = try! JSONDecoder().decode(
        CommunicationChannel.self,
        from: """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "creator_id": "00000000-0000-0000-0000-000000000002",
            "channel_type": "public",
            "channel_code": "PUB-ABC123",
            "name": "测试频道",
            "description": "测试频道描述",
            "is_active": true,
            "member_count": 42,
            "latitude": null,
            "longitude": null,
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
    )

    return ChannelChatView(channel: mockChannel)
        .environmentObject(AuthManager())
}
