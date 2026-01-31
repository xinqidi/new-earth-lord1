//
//  MessageCenterView.swift
//  new earth lord1
//
//  消息中心页面
//  显示已订阅频道的最新消息列表，支持快速进入聊天
//

import SwiftUI

struct MessageCenterView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedChannel: CommunicationChannel?
    @State private var showChatView = false

    var body: some View {
        Group {
            if communicationManager.subscribedChannels.isEmpty {
                emptyStateView
            } else {
                messageListView
            }
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            loadData()
        }
        .fullScreenCover(isPresented: $showChatView) {
            if let channel = selectedChannel {
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
            }
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无消息".localized)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("订阅频道后，消息会显示在这里".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 消息列表视图

    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedChannels, id: \.channel.id) { subscribedChannel in
                    MessageChannelRow(
                        channel: subscribedChannel.channel,
                        latestMessage: getLatestMessage(for: subscribedChannel.channel.id),
                        onTap: {
                            selectedChannel = subscribedChannel.channel
                            showChatView = true
                        }
                    )

                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.2))
                        .padding(.leading, 70)
                }
            }
        }
    }

    // MARK: - 数据处理

    /// 按最新消息时间排序的频道列表
    private var sortedChannels: [SubscribedChannel] {
        communicationManager.subscribedChannels.sorted { a, b in
            let aMessage = getLatestMessage(for: a.channel.id)
            let bMessage = getLatestMessage(for: b.channel.id)

            if let aTime = aMessage?.createdAt, let bTime = bMessage?.createdAt {
                return aTime > bTime
            } else if aMessage != nil {
                return true
            } else if bMessage != nil {
                return false
            }
            return a.channel.name < b.channel.name
        }
    }

    /// 获取频道的最新消息
    private func getLatestMessage(for channelId: UUID) -> ChannelMessage? {
        communicationManager.channelMessages[channelId]?.last
    }

    /// 加载数据
    private func loadData() {
        Task {
            await communicationManager.loadSubscribedChannels()

            // 为每个订阅的频道加载最新消息
            for subscribedChannel in communicationManager.subscribedChannels {
                await communicationManager.loadChannelMessages(channelId: subscribedChannel.channel.id)
            }
        }
    }
}

// MARK: - 消息频道行

struct MessageChannelRow: View {
    let channel: CommunicationChannel
    let latestMessage: ChannelMessage?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 频道图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(channel.name)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if let message = latestMessage {
                            Text(message.timeAgo)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    // 最新消息预览
                    if let message = latestMessage {
                        HStack(spacing: 4) {
                            if let callsign = message.senderCallsign {
                                Text("\(callsign):")
                                    .font(.subheadline)
                                    .foregroundColor(ApocalypseTheme.primary)
                            }
                            Text(message.content)
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("暂无消息".localized)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                            .italic()
                    }
                }

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MessageCenterView()
        .environmentObject(AuthManager())
}
