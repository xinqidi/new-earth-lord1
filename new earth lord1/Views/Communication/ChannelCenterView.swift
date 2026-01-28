//
//  ChannelCenterView.swift
//  new earth lord1
//
//  频道中心页面
//  包含"我的频道"和"发现频道"两个Tab
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
                Text("频道中心".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Button(action: { showCreateSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("创建".localized)
                    }
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.primary.opacity(0.15))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Tab 切换栏
            HStack(spacing: 0) {
                tabButton(title: "我的频道".localized, index: 0)
                tabButton(title: "发现频道".localized, index: 1)
            }
            .padding(.horizontal, 16)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))
                .padding(.top, 8)

            // 搜索栏（仅发现页面显示）
            if selectedTab == 1 {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField("搜索频道".localized, text: $searchText)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // 内容区域
            if communicationManager.isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                Spacer()
            } else {
                if selectedTab == 0 {
                    myChannelsView
                } else {
                    discoverChannelsView
                }
            }
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            Task {
                await communicationManager.loadSubscribedChannels()
                await communicationManager.loadPublicChannels()
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
        }
    }

    // MARK: - Tab 按钮

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 我的频道

    private var myChannelsView: some View {
        Group {
            if communicationManager.subscribedChannels.isEmpty {
                emptyStateView(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "还没有订阅的频道".localized,
                    subtitle: "去发现频道订阅感兴趣的内容".localized
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(communicationManager.subscribedChannels) { subscribedChannel in
                            ChannelRowView(
                                channel: subscribedChannel.channel,
                                isSubscribed: true
                            )
                            .onTapGesture {
                                selectedChannel = subscribedChannel.channel
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - 发现频道

    private var discoverChannelsView: some View {
        Group {
            let filteredChannels = searchText.isEmpty
                ? communicationManager.channels
                : communicationManager.channels.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.channelCode.localizedCaseInsensitiveContains(searchText)
                }

            if filteredChannels.isEmpty {
                emptyStateView(
                    icon: "magnifyingglass",
                    title: searchText.isEmpty ? "暂无公开频道".localized : "未找到匹配频道".localized,
                    subtitle: searchText.isEmpty ? "创建第一个频道吧".localized : "尝试其他关键词".localized
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredChannels) { channel in
                            ChannelRowView(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            )
                            .onTapGesture {
                                selectedChannel = channel
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - 空状态视图

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 频道行视图

struct ChannelRowView: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if isSubscribed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 8) {
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

            // 频道类型标签
            Text(channel.channelType.displayName)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.primary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager())
}
