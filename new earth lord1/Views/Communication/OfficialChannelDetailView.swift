//
//  OfficialChannelDetailView.swift
//  new earth lord1
//
//  官方频道详情页
//  显示分类过滤的官方公告消息
//

import SwiftUI

struct OfficialChannelDetailView: View {
    let channel: CommunicationChannel

    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: MessageCategory?
    @State private var isLoading = true

    private var messages: [ChannelMessage] {
        let allMessages = communicationManager.getMessages(for: channel.id)
        if let category = selectedCategory {
            return allMessages.filter { $0.category == category }
        }
        return allMessages
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 导航栏
                navigationBar

                // 分类过滤器
                categoryFilter

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.3))

                // 消息列表
                messageListView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadMessages()
        }
    }

    // MARK: - 导航栏

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "megaphone.fill")
                        .foregroundColor(.red)
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Text("官方公告 · 全球覆盖".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 分类过滤器

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                CategoryChip(
                    title: "全部".localized,
                    icon: "list.bullet",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各分类
                ForEach(MessageCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.iconName,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollView {
            if isLoading {
                VStack {
                    Spacer().frame(height: 50)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    Spacer()
                }
            } else if messages.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        OfficialMessageBubble(message: message)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(selectedCategory == nil ? "暂无公告".localized : "暂无\(selectedCategory!.displayName)".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()
        }
    }

    private func loadMessages() {
        isLoading = true
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - 分类标签组件

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(16)
        }
    }
}

// MARK: - 官方消息气泡

struct OfficialMessageBubble: View {
    let message: ChannelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 分类标签
            if let category = message.category {
                HStack(spacing: 4) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 12))
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(category.color.opacity(0.15))
                .cornerRadius(8)
            }

            // 消息内容
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 时间
            Text(message.timeAgo)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.category?.color.opacity(0.3) ?? Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    OfficialChannelDetailView(channel: CommunicationChannel.preview)
}

// Preview helper
extension CommunicationChannel {
    static var preview: CommunicationChannel {
        // 创建一个用于预览的官方频道
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "creator_id": "00000000-0000-0000-0000-000000000000",
            "channel_type": "official",
            "channel_code": "OFF-MAIN",
            "name": "官方频道",
            "description": "官方公告",
            "is_active": true,
            "member_count": 0,
            "created_at": "2025-01-01T00:00:00Z",
            "updated_at": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        return try! decoder.decode(CommunicationChannel.self, from: json)
    }
}
