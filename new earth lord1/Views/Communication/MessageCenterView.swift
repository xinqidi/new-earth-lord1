//
//  MessageCenterView.swift
//  new earth lord1
//
//  消息中心页面
//  显示已订阅频道的最新消息列表，官方频道置顶
//

import SwiftUI

struct MessageCenterView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    // 普通频道导航（用于 ChannelChatView）
    @State private var selectedChannel: CommunicationChannel?

    // 官方频道导航（用于 OfficialChannelDetailView）
    @State private var selectedOfficialChannel: CommunicationChannel?

    // 刷新状态
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // 内容区
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
        // 普通频道 -> 聊天页面
        .fullScreenCover(item: $selectedChannel) { channel in
            ChannelChatView(channel: channel)
                .environmentObject(authManager)
        }
        // 官方频道 -> 公告页面
        .fullScreenCover(item: $selectedOfficialChannel) { channel in
            OfficialChannelDetailView(channel: channel)
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            Text("消息中心".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 刷新按钮
            Button(action: {
                refreshData()
            }) {
                if isRefreshing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .disabled(isRefreshing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
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
                        isOfficial: subscribedChannel.channel.channelType == .official,
                        onTap: {
                            handleChannelTap(subscribedChannel.channel)
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

    /// 按官方频道优先，然后按最新消息时间排序
    private var sortedChannels: [SubscribedChannel] {
        communicationManager.subscribedChannels.sorted { a, b in
            // Day 36: 官方频道置顶
            if a.channel.channelType == .official && b.channel.channelType != .official {
                return true
            }
            if a.channel.channelType != .official && b.channel.channelType == .official {
                return false
            }

            // 其他按最新消息时间排序
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

    /// 处理频道点击
    private func handleChannelTap(_ channel: CommunicationChannel) {
        if channel.channelType == .official {
            selectedOfficialChannel = channel
        } else {
            selectedChannel = channel
        }
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

    /// 刷新数据（带动画）
    private func refreshData() {
        isRefreshing = true

        Task {
            await communicationManager.loadSubscribedChannels()

            // 为每个订阅的频道加载最新消息
            for subscribedChannel in communicationManager.subscribedChannels {
                await communicationManager.loadChannelMessages(channelId: subscribedChannel.channel.id)
            }

            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

// MARK: - 消息频道行

struct MessageChannelRow: View {
    let channel: CommunicationChannel
    let latestMessage: ChannelMessage?
    let isOfficial: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 频道图标
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 50, height: 50)

                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(iconColor)
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(channel.name)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)

                        // Day 36: 官方标签
                        if isOfficial {
                            Text("官方".localized)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }

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
                            // 官方频道显示分类，普通频道显示呼号
                            if isOfficial, let category = message.category {
                                Text("[\(category.displayName)]")
                                    .font(.subheadline)
                                    .foregroundColor(category.color)
                            } else if let callsign = message.senderCallsign {
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
            .background(isOfficial ? ApocalypseTheme.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconBackgroundColor: Color {
        isOfficial ? Color.red.opacity(0.2) : ApocalypseTheme.primary.opacity(0.2)
    }

    private var iconColor: Color {
        isOfficial ? .red : ApocalypseTheme.primary
    }
}

#Preview {
    MessageCenterView()
        .environmentObject(AuthManager())
}
