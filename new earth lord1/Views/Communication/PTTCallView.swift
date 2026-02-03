//
//  PTTCallView.swift
//  new earth lord1
//
//  PTT呼叫页面
//  支持长按发送、频道切换、震动反馈
//

import SwiftUI
import CoreLocation

struct PTTCallView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedChannelId: UUID?
    @State private var messageContent: String = ""
    @State private var isPressingPTT: Bool = false
    @State private var showingSuccess: Bool = false
    @FocusState private var isTextEditorFocused: Bool

    private var subscribedChannels: [SubscribedChannel] {
        communicationManager.subscribedChannels.filter {
            // 排除官方频道（官方频道只能接收）
            !communicationManager.isOfficialChannel($0.channel.id)
        }
    }

    private var selectedChannel: CommunicationChannel? {
        subscribedChannels.first { $0.channel.id == selectedChannelId }?.channel
    }

    private var canSend: Bool {
        communicationManager.canSendMessage() &&
        selectedChannel != nil &&
        !messageContent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 标题
                headerView

                // 当前频率卡片
                if let channel = selectedChannel {
                    frequencyCard(channel: channel)
                } else {
                    noChannelCard
                }

                // 频道切换标签栏
                if !subscribedChannels.isEmpty {
                    channelTabBar
                }

                Spacer()

                // 消息输入区
                messageInputArea

                // PTT 按钮
                pttButton

                Spacer()

                // 提示文字
                Text("长按按钮发送呼叫，松开结束".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            if selectedChannelId == nil {
                selectedChannelId = subscribedChannels.first?.channel.id
            }
        }
        .onTapGesture {
            // 点击空白区域关闭键盘
            isTextEditorFocused = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成".localized) {
                    isTextEditorFocused = false
                }
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .overlay(successToast)
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            Text("PTT 呼叫".localized)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 当前设备
            if let device = communicationManager.currentDevice {
                HStack(spacing: 4) {
                    Image(systemName: device.deviceType.iconName)
                    Text(device.deviceType.rangeText)
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.primary.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 频率卡片

    private func frequencyCard(channel: CommunicationChannel) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24))
                    .foregroundColor(ApocalypseTheme.primary)

                Spacer()

                // 范围指示
                if let device = communicationManager.currentDevice {
                    HStack(spacing: 4) {
                        Text(device.deviceType.rangeText)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Text(channel.channelCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(channel.name)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - 无频道提示

    private var noChannelCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无可用频道".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("请先订阅一个非官方频道".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - 频道切换标签栏

    private var channelTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subscribedChannels, id: \.channel.id) { subscribedChannel in
                    let channel = subscribedChannel.channel
                    let isSelected = channel.id == selectedChannelId

                    Button(action: {
                        selectedChannelId = channel.id
                    }) {
                        VStack(spacing: 2) {
                            Text(channel.channelCode)
                                .font(.caption)
                                .fontWeight(.medium)

                            Text(channel.name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(isSelected ? .white : ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - 消息输入区

    private var messageInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("呼叫内容".localized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $messageContent)
                    .frame(height: 80)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .tint(ApocalypseTheme.primary)
                    .focused($isTextEditorFocused)

                if messageContent.isEmpty {
                    Text("输入您的呼叫内容，然后按住PTT按钮发送".localized)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - PTT 按钮

    private var pttButton: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: isPressingPTT ? "waveform" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)

                Text(isPressingPTT ? "发送中...".localized : "按住发送".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(width: 120, height: 120)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isPressingPTT
                                ? [Color.red, Color.red.opacity(0.7)]
                                : (canSend
                                    ? [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)]
                                    : [Color.gray, Color.gray.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: isPressingPTT ? Color.red.opacity(0.5) : (canSend ? ApocalypseTheme.primary.opacity(0.5) : Color.clear), radius: 10)
            .scaleEffect(isPressingPTT ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressingPTT)
        }
        .disabled(!canSend && !isPressingPTT)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard canSend, !isPressingPTT else { return }
                    isPressingPTT = true
                    triggerHapticFeedback(.medium)
                }
                .onEnded { _ in
                    guard isPressingPTT else { return }
                    isPressingPTT = false
                    sendPTTMessage()
                }
        )
    }

    // MARK: - 成功提示

    private var successToast: some View {
        Group {
            if showingSuccess {
                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("消息已发送".localized)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(20)
                    .shadow(radius: 10)

                    Spacer().frame(height: 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - 方法

    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }

    private func sendPTTMessage() {
        guard let channelId = selectedChannelId,
              !messageContent.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let content = messageContent

        // 获取当前位置
        let location = LocationManager.shared.userLocation

        Task {
            let success = await communicationManager.sendChannelMessage(
                channelId: channelId,
                content: content,
                latitude: location?.latitude,
                longitude: location?.longitude
            )

            if success {
                await MainActor.run {
                    messageContent = ""
                    showingSuccess = true

                    // 成功震动
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)

                    // 隐藏成功提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingSuccess = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PTTCallView()
        .environmentObject(AuthManager())
}
