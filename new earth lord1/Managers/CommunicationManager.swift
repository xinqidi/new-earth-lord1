//
//  CommunicationManager.swift
//  new earth lord1
//
//  通讯管理器
//  负责管理通讯设备的加载、切换和解锁
//

import Foundation
import Combine
import Supabase

@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = CommunicationManager()

    // MARK: - Published Properties

    /// 用户设备列表
    @Published private(set) var devices: [CommunicationDevice] = []

    /// 当前使用的设备
    @Published private(set) var currentDevice: CommunicationDevice?

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 所有公开频道
    @Published private(set) var channels: [CommunicationChannel] = []

    /// 已订阅的频道（包含订阅信息）
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []

    /// 我的订阅列表
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    /// 频道消息（频道ID -> 消息列表）
    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]

    /// 是否正在发送消息
    @Published var isSendingMessage = false

    /// 已订阅消息的频道ID集合
    @Published var messageSubscribedChannelIds: Set<UUID> = []

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient?

    /// 当前用户 ID
    private var userId: UUID?

    /// 是否已配置
    private var isConfigured: Bool = false

    /// Realtime 频道
    private var realtimeChannel: RealtimeChannelV2?

    /// 消息订阅任务
    private var messageSubscriptionTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        print("📻 [通讯] CommunicationManager 初始化完成")
    }

    // MARK: - Configuration

    /// 配置通讯管理器
    func configure(supabase: SupabaseClient, userId: UUID) {
        self.supabase = supabase
        self.userId = userId
        self.isConfigured = true
        print("📻 [通讯] 配置完成，用户ID: \(userId)")
    }

    // MARK: - Public Methods

    /// 加载用户设备
    func loadDevices() async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [通讯] 未配置，无法加载设备")
            errorMessage = "通讯系统未配置"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("📻 [通讯] 开始加载设备...")

            let response: [CommunicationDevice] = try await supabase
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            print("📻 [通讯] ✅ 加载设备成功，共 \(devices.count) 个设备")

            // 如果没有设备，初始化
            if devices.isEmpty {
                print("📻 [通讯] 设备为空，开始初始化...")
                await initializeDevices()
            }
        } catch {
            print("❌ [通讯] 加载设备失败: \(error.localizedDescription)")
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 初始化用户设备
    func initializeDevices() async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [通讯] 未配置，无法初始化设备")
            return
        }

        do {
            print("📻 [通讯] 初始化用户设备...")

            try await supabase.rpc(
                "initialize_user_devices",
                params: ["p_user_id": AnyJSON.string(userId.uuidString)]
            ).execute()

            print("📻 [通讯] ✅ 设备初始化成功")

            // 重新加载设备
            await loadDevices()
        } catch {
            print("❌ [通讯] 初始化设备失败: \(error.localizedDescription)")
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    /// 切换当前设备
    func switchDevice(to deviceType: DeviceType) async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [通讯] 未配置，无法切换设备")
            errorMessage = "通讯系统未配置"
            return
        }

        // 检查设备是否解锁
        guard let device = devices.first(where: { $0.deviceType == deviceType }), device.isUnlocked else {
            print("❌ [通讯] 设备未解锁: \(deviceType.displayName)")
            errorMessage = "设备未解锁"
            return
        }

        // 如果已经是当前设备，无需切换
        if device.isCurrent {
            print("📻 [通讯] \(deviceType.displayName) 已经是当前设备")
            return
        }

        isLoading = true

        do {
            print("📻 [通讯] 切换设备到: \(deviceType.displayName)...")

            try await supabase.rpc(
                "switch_current_device",
                params: [
                    "p_user_id": AnyJSON.string(userId.uuidString),
                    "p_device_type": AnyJSON.string(deviceType.rawValue)
                ]
            ).execute()

            // 更新本地状态
            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })

            print("📻 [通讯] ✅ 切换设备成功")
        } catch {
            print("❌ [通讯] 切换设备失败: \(error.localizedDescription)")
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 解锁设备（由建造系统调用）
    func unlockDevice(deviceType: DeviceType) async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [通讯] 未配置，无法解锁设备")
            errorMessage = "通讯系统未配置"
            return
        }

        do {
            print("📻 [通讯] 解锁设备: \(deviceType.displayName)...")

            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            // 更新本地状态
            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }

            print("📻 [通讯] ✅ 设备解锁成功")
        } catch {
            print("❌ [通讯] 解锁设备失败: \(error.localizedDescription)")
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods

    /// 获取当前设备类型
    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    /// 检查是否可以发送消息
    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    /// 获取当前设备通讯范围（公里）
    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    /// 检查设备是否已解锁
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    /// 获取指定类型的设备
    func getDevice(_ deviceType: DeviceType) -> CommunicationDevice? {
        devices.first(where: { $0.deviceType == deviceType })
    }

    // MARK: - Channel Methods

    /// 加载所有公开频道
    func loadPublicChannels() async {
        guard let supabase = supabase else {
            print("❌ [频道] 未配置，无法加载频道")
            return
        }

        do {
            print("📡 [频道] 加载公开频道...")

            let response: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            channels = response
            print("📡 [频道] ✅ 加载成功，共 \(channels.count) 个频道")
        } catch {
            print("❌ [频道] 加载失败: \(error.localizedDescription)")
            errorMessage = "加载频道失败"
        }
    }

    /// 加载已订阅的频道
    func loadSubscribedChannels() async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [频道] 未配置，无法加载订阅")
            return
        }

        do {
            print("📡 [频道] 加载已订阅频道...")

            // 1. 加载订阅列表
            let subscriptions: [ChannelSubscription] = try await supabase
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions
            print("📡 [频道] 订阅数量: \(subscriptions.count)")

            // 2. 如果没有订阅，清空并返回
            if subscriptions.isEmpty {
                subscribedChannels = []
                return
            }

            // 3. 获取订阅频道的详情
            let channelIds = subscriptions.map { $0.channelId.uuidString }
            let channelList: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .execute()
                .value

            // 4. 组合成 SubscribedChannel
            subscribedChannels = subscriptions.compactMap { sub in
                guard let channel = channelList.first(where: { $0.id == sub.channelId }) else {
                    return nil
                }
                return SubscribedChannel(channel: channel, subscription: sub)
            }

            print("📡 [频道] ✅ 已订阅频道加载成功")
        } catch {
            print("❌ [频道] 加载订阅失败: \(error.localizedDescription)")
            errorMessage = "加载订阅失败"
        }
    }

    /// 创建频道
    func createChannel(type: ChannelType, name: String, description: String?, latitude: Double? = nil, longitude: Double? = nil) async -> Bool {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [频道] 未配置，无法创建频道")
            errorMessage = "通讯系统未配置"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            print("📡 [频道] 创建频道: \(name)...")

            // 处理 channelType，publicChannel 转为 "public"
            let typeString = type == .publicChannel ? "public" : type.rawValue

            let params: [String: AnyJSON] = [
                "p_creator_id": .string(userId.uuidString),
                "p_channel_type": .string(typeString),
                "p_name": .string(name),
                "p_description": description.map { .string($0) } ?? .null,
                "p_latitude": latitude.map { .double($0) } ?? .null,
                "p_longitude": longitude.map { .double($0) } ?? .null
            ]

            let _: UUID = try await supabase
                .rpc("create_channel_with_subscription", params: params)
                .execute()
                .value

            print("📡 [频道] ✅ 频道创建成功")

            // 刷新数据
            await loadPublicChannels()
            await loadSubscribedChannels()

            isLoading = false
            return true
        } catch {
            print("❌ [频道] 创建失败: \(error.localizedDescription)")
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// 订阅频道
    func subscribeToChannel(channelId: UUID) async -> Bool {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [频道] 未配置，无法订阅")
            errorMessage = "通讯系统未配置"
            return false
        }

        isLoading = true

        do {
            print("📡 [频道] 订阅频道...")

            try await supabase.rpc(
                "subscribe_to_channel",
                params: [
                    "p_user_id": AnyJSON.string(userId.uuidString),
                    "p_channel_id": AnyJSON.string(channelId.uuidString)
                ]
            ).execute()

            print("📡 [频道] ✅ 订阅成功")

            // 刷新数据
            await loadPublicChannels()
            await loadSubscribedChannels()

            isLoading = false
            return true
        } catch {
            print("❌ [频道] 订阅失败: \(error.localizedDescription)")
            errorMessage = "订阅失败"
            isLoading = false
            return false
        }
    }

    /// 取消订阅频道
    func unsubscribeFromChannel(channelId: UUID) async -> Bool {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [频道] 未配置，无法取消订阅")
            errorMessage = "通讯系统未配置"
            return false
        }

        isLoading = true

        do {
            print("📡 [频道] 取消订阅...")

            try await supabase.rpc(
                "unsubscribe_from_channel",
                params: [
                    "p_user_id": AnyJSON.string(userId.uuidString),
                    "p_channel_id": AnyJSON.string(channelId.uuidString)
                ]
            ).execute()

            print("📡 [频道] ✅ 取消订阅成功")

            // 刷新数据
            await loadPublicChannels()
            await loadSubscribedChannels()

            isLoading = false
            return true
        } catch {
            print("❌ [频道] 取消订阅失败: \(error.localizedDescription)")
            errorMessage = "取消订阅失败"
            isLoading = false
            return false
        }
    }

    /// 删除频道（仅创建者可用）
    func deleteChannel(channelId: UUID) async -> Bool {
        guard let supabase = supabase else {
            print("❌ [频道] 未配置，无法删除")
            errorMessage = "通讯系统未配置"
            return false
        }

        isLoading = true

        do {
            print("📡 [频道] 删除频道...")

            try await supabase
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()

            print("📡 [频道] ✅ 删除成功")

            // 刷新数据
            await loadPublicChannels()
            await loadSubscribedChannels()

            isLoading = false
            return true
        } catch {
            print("❌ [频道] 删除失败: \(error.localizedDescription)")
            errorMessage = "删除失败"
            isLoading = false
            return false
        }
    }

    /// 检查是否已订阅频道
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    /// 检查是否是频道创建者
    func isChannelCreator(channel: CommunicationChannel) -> Bool {
        channel.creatorId == userId
    }

    // MARK: - Message Methods

    /// 加载频道历史消息
    func loadChannelMessages(channelId: UUID) async {
        guard let supabase = supabase else {
            print("❌ [消息] 未配置，无法加载消息")
            return
        }

        do {
            print("💬 [消息] 加载频道消息: \(channelId)...")

            let messages: [ChannelMessage] = try await supabase
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value

            channelMessages[channelId] = messages
            print("💬 [消息] ✅ 加载成功，共 \(messages.count) 条消息")
        } catch {
            print("❌ [消息] 加载失败: \(error.localizedDescription)")
            errorMessage = "加载消息失败"
        }
    }

    /// 发送频道消息
    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        deviceType: String? = nil
    ) async -> Bool {
        guard let supabase = supabase else {
            print("❌ [消息] 未配置，无法发送消息")
            errorMessage = "通讯系统未配置"
            return false
        }

        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "消息内容不能为空"
            return false
        }

        isSendingMessage = true

        do {
            print("💬 [消息] 发送消息...")

            let params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content),
                "p_latitude": latitude.map { .double($0) } ?? .null,
                "p_longitude": longitude.map { .double($0) } ?? .null,
                "p_device_type": deviceType.map { .string($0) } ?? .null
            ]

            let _: UUID = try await supabase
                .rpc("send_channel_message", params: params)
                .execute()
                .value

            print("💬 [消息] ✅ 发送成功")
            isSendingMessage = false
            return true
        } catch {
            print("❌ [消息] 发送失败: \(error.localizedDescription)")
            errorMessage = "发送失败: \(error.localizedDescription)"
            isSendingMessage = false
            return false
        }
    }

    /// 获取频道消息列表
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    // MARK: - Realtime Subscription

    /// 启动 Realtime 消息订阅
    func startRealtimeSubscription() async {
        guard let supabase = supabase else {
            print("❌ [Realtime] 未配置，无法启动订阅")
            return
        }

        // 如果已经订阅，先停止
        await stopRealtimeSubscription()

        print("📡 [Realtime] 启动消息订阅...")

        // 创建 Realtime 频道
        realtimeChannel = supabase.realtimeV2.channel("channel_messages_realtime")

        guard let channel = realtimeChannel else { return }

        // 订阅 INSERT 事件
        let insertions = channel.postgresChange(
            InsertAction.self,
            table: "channel_messages"
        )

        // 启动监听任务
        messageSubscriptionTask = Task { [weak self] in
            for await insertion in insertions {
                await self?.handleNewMessage(insertion: insertion)
            }
        }

        // 开始订阅
        await channel.subscribe()

        print("📡 [Realtime] ✅ 消息订阅已启动")
    }

    /// 停止 Realtime 订阅
    func stopRealtimeSubscription() async {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }

        print("📡 [Realtime] 消息订阅已停止")
    }

    /// 处理新消息
    private func handleNewMessage(insertion: InsertAction) async {
        do {
            let decoder = JSONDecoder()
            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)

            // 检查是否是已订阅频道的消息
            guard messageSubscribedChannelIds.contains(message.channelId) else {
                print("📡 [Realtime] 忽略未订阅频道的消息: \(message.channelId)")
                return
            }

            // 添加到消息列表
            if channelMessages[message.channelId] != nil {
                channelMessages[message.channelId]?.append(message)
            } else {
                channelMessages[message.channelId] = [message]
            }

            print("📡 [Realtime] ✅ 收到新消息: \(message.content.prefix(20))...")
        } catch {
            print("❌ [Realtime] 解析消息失败: \(error)")
        }
    }

    /// 订阅频道消息（添加到订阅列表）
    func subscribeToChannelMessages(channelId: UUID) {
        messageSubscribedChannelIds.insert(channelId)

        // 如果 Realtime 未启动，启动它
        if realtimeChannel == nil {
            Task {
                await startRealtimeSubscription()
            }
        }

        print("📡 [Realtime] 订阅频道消息: \(channelId)")
    }

    /// 取消订阅频道消息
    func unsubscribeFromChannelMessages(channelId: UUID) {
        messageSubscribedChannelIds.remove(channelId)
        channelMessages.removeValue(forKey: channelId)

        // 如果没有订阅任何频道，停止 Realtime
        if messageSubscribedChannelIds.isEmpty {
            Task {
                await stopRealtimeSubscription()
            }
        }

        print("📡 [Realtime] 取消订阅频道消息: \(channelId)")
    }

    // MARK: - Cleanup

    /// 清除状态（退出登录时调用）
    func clearState() {
        // 停止 Realtime 订阅
        Task {
            await stopRealtimeSubscription()
        }

        devices = []
        currentDevice = nil
        channels = []
        subscribedChannels = []
        mySubscriptions = []
        channelMessages = [:]
        messageSubscribedChannelIds = []
        isSendingMessage = false
        errorMessage = nil
        isConfigured = false
        userId = nil
        supabase = nil
        print("📻 [通讯] 状态已清除")
    }
}

// MARK: - Update Models

/// 设备解锁更新数据
private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}
