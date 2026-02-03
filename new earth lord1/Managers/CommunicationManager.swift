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
import CoreLocation

@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = CommunicationManager()

    // MARK: - 官方频道常量（Day 36）

    /// 官方频道固定 UUID
    static let officialChannelId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

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

    // MARK: - 官方频道相关（Day 36）

    /// 检查是否是官方频道
    func isOfficialChannel(_ channelId: UUID) -> Bool {
        return channelId == CommunicationManager.officialChannelId
    }

    /// 确保用户订阅了官方频道（强制订阅）
    func ensureOfficialChannelSubscribed() async {
        guard let supabase = supabase, let userId = userId else {
            print("⚠️ [官方频道] 未配置，无法检查订阅")
            return
        }

        let officialId = CommunicationManager.officialChannelId

        // 检查是否已订阅
        if subscribedChannels.contains(where: { $0.channel.id == officialId }) {
            print("✅ [官方频道] 已订阅")
            return
        }

        // 强制订阅官方频道
        do {
            print("📡 [官方频道] 正在自动订阅...")

            // 直接插入订阅记录
            struct SubscriptionInsert: Encodable {
                let user_id: String
                let channel_id: String
                let is_muted: Bool
            }

            let subscription = SubscriptionInsert(
                user_id: userId.uuidString,
                channel_id: officialId.uuidString,
                is_muted: false
            )

            try await supabase
                .from("channel_subscriptions")
                .insert(subscription)
                .execute()

            // 刷新订阅列表
            await loadSubscribedChannels()
            print("✅ [官方频道] 已自动订阅")
        } catch {
            print("❌ [官方频道] 订阅失败: \(error.localizedDescription)")
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

            // 1. 先加载消息
            let messages: [ChannelMessage] = try await supabase
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value

            print("💬 [消息] 加载了 \(messages.count) 条消息")

            // 2. 获取所有发送者ID
            let senderIds = Set(messages.compactMap { $0.senderId })
            print("💬 [消息] 发送者ID列表: \(senderIds.map { $0.uuidString })")

            if senderIds.isEmpty {
                await MainActor.run {
                    channelMessages[channelId] = messages
                }
                print("💬 [消息] ✅ 加载成功，共 \(messages.count) 条消息")
                return
            }

            // 3. 批量查询发送者的最新呼号
            struct ProfileCallsign: Decodable {
                let id: UUID
                let callsign: String?
            }

            let profiles: [ProfileCallsign] = try await supabase
                .from("profiles")
                .select("id, callsign")
                .in("id", values: senderIds.map { $0.uuidString })
                .execute()
                .value

            print("💬 [消息] 查询到 \(profiles.count) 个用户资料")

            // 4. 创建ID到呼号的映射
            var callsignMap: [UUID: String] = [:]
            for profile in profiles {
                print("💬 [消息] 用户 \(profile.id) 的呼号: \(profile.callsign ?? "nil")")
                if let callsign = profile.callsign, !callsign.isEmpty {
                    callsignMap[profile.id] = callsign
                }
            }

            print("💬 [消息] 获取到 \(callsignMap.count) 个呼号映射: \(callsignMap)")

            // 5. 更新消息的呼号
            var updatedCount = 0
            let updatedMessages = messages.map { message -> ChannelMessage in
                if let senderId = message.senderId,
                   let callsign = callsignMap[senderId] {
                    updatedCount += 1
                    return message.withUpdatedCallsign(callsign)
                }
                return message
            }
            print("💬 [消息] 更新了 \(updatedCount) 条消息的呼号")

            // 在主线程更新以触发 UI 刷新
            await MainActor.run {
                channelMessages[channelId] = updatedMessages
            }
            print("💬 [消息] ✅ 加载成功，共 \(updatedMessages.count) 条消息")
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
            var message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)

            // ✅ 第一关：检查是否是已订阅频道的消息
            guard messageSubscribedChannelIds.contains(message.channelId) else {
                print("📡 [Realtime] 忽略未订阅频道的消息: \(message.channelId)")
                return
            }

            // ✅ 第二关：距离过滤（Day 35 新增）
            guard shouldReceiveMessage(message) else {
                print("📡 [Realtime] 距离过滤丢弃消息")
                return
            }

            // ✅ 获取发送者最新呼号
            if let senderId = message.senderId, let supabase = supabase {
                do {
                    struct ProfileCallsign: Decodable {
                        let callsign: String?
                    }
                    let profiles: [ProfileCallsign] = try await supabase
                        .from("profiles")
                        .select("callsign")
                        .eq("id", value: senderId.uuidString)
                        .limit(1)
                        .execute()
                        .value

                    if let callsign = profiles.first?.callsign, !callsign.isEmpty {
                        message = message.withUpdatedCallsign(callsign)
                    }
                } catch {
                    print("⚠️ [Realtime] 获取呼号失败: \(error.localizedDescription)")
                }
            }

            // 添加到消息列表（在主线程更新）
            await MainActor.run {
                if channelMessages[message.channelId] != nil {
                    // 检查是否已存在（避免重复）
                    if !channelMessages[message.channelId]!.contains(where: { $0.id == message.id }) {
                        channelMessages[message.channelId]?.append(message)
                        print("📡 [Realtime] ✅ 收到新消息: \(message.content.prefix(20))...")
                    }
                } else {
                    channelMessages[message.channelId] = [message]
                    print("📡 [Realtime] ✅ 收到新消息: \(message.content.prefix(20))...")
                }
            }
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

    // MARK: - 距离过滤逻辑 (Day 35)

    /// 判断是否应该接收该消息（基于设备类型和距离）
    /// - Parameter message: 收到的消息
    /// - Returns: 是否应该显示该消息
    func shouldReceiveMessage(_ message: ChannelMessage) -> Bool {
        // 0. 检查频道类型 - 只对公共频道应用距离过滤
        if let channel = getChannelById(message.channelId) {
            // 官方频道和私有频道不过滤
            if channel.channelType == .official {
                print("📻 [距离过滤] 官方频道，不过滤")
                return true
            }
            // 注意：publicChannel 需要过滤，walkie/camp/satellite 也需要过滤
        }

        // 1. 获取当前用户设备类型
        guard let myDeviceType = currentDevice?.deviceType else {
            print("⚠️ [距离过滤] 无法获取当前设备，保守显示消息")
            return true  // 保守策略：无设备信息时显示
        }

        // 2. 收音机可以接收所有消息（无限距离）
        if myDeviceType == .radio {
            print("📻 [距离过滤] 收音机用户，接收所有消息")
            return true
        }

        // 3. 检查发送者设备类型
        guard let senderDevice = message.senderDeviceType else {
            print("⚠️ [距离过滤] 消息缺少设备类型，保守显示（向后兼容）")
            return true  // 向后兼容：老消息没有设备类型
        }

        // 4. 收音机不能发送消息
        if senderDevice == .radio {
            print("🚫 [距离过滤] 收音机不能发送消息")
            return false
        }

        // 5. 检查发送者位置
        guard let senderLocation = message.senderLocation else {
            print("⚠️ [距离过滤] 消息缺少位置信息，保守显示")
            return true  // 保守策略：无位置信息时显示
        }

        // 6. 获取当前用户位置
        guard let myLocation = getCurrentLocation() else {
            print("⚠️ [距离过滤] 无法获取当前位置，保守显示")
            return true  // 保守策略：无当前位置时显示
        }

        // 7. 计算距离（公里）
        let distance = calculateDistance(
            from: CLLocationCoordinate2D(
                latitude: myLocation.latitude,
                longitude: myLocation.longitude
            ),
            to: CLLocationCoordinate2D(
                latitude: senderLocation.latitude,
                longitude: senderLocation.longitude
            )
        )

        // 8. 根据设备矩阵判断
        let canReceive = canReceiveMessage(
            senderDevice: senderDevice,
            myDevice: myDeviceType,
            distance: distance
        )

        if canReceive {
            print("✅ [距离过滤] 通过: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km")
        } else {
            print("🚫 [距离过滤] 丢弃: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km (超出范围)")
        }

        return canReceive
    }

    /// 根据设备类型矩阵判断是否能接收消息
    private func canReceiveMessage(
        senderDevice: DeviceType,
        myDevice: DeviceType,
        distance: Double
    ) -> Bool {
        // 收音机接收方：无距离限制
        if myDevice == .radio {
            return true
        }

        // 收音机发送方：不能发送
        if senderDevice == .radio {
            return false
        }

        // 设备矩阵
        switch (senderDevice, myDevice) {
        // 对讲机发送（3km覆盖）
        case (.walkieTalkie, .walkieTalkie):
            return distance <= 3.0
        case (.walkieTalkie, .campRadio):
            return distance <= 30.0
        case (.walkieTalkie, .satellite):
            return distance <= 100.0

        // 营地电台发送（30km覆盖）
        case (.campRadio, .walkieTalkie):
            return distance <= 30.0
        case (.campRadio, .campRadio):
            return distance <= 30.0
        case (.campRadio, .satellite):
            return distance <= 100.0

        // 卫星通讯发送（100km覆盖）
        case (.satellite, .walkieTalkie):
            return distance <= 100.0
        case (.satellite, .campRadio):
            return distance <= 100.0
        case (.satellite, .satellite):
            return distance <= 100.0

        default:
            return false
        }
    }

    /// 计算两个坐标之间的距离（公里）
    private func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let fromLocation = CLLocation(
            latitude: from.latitude,
            longitude: from.longitude
        )
        let toLocation = CLLocation(
            latitude: to.latitude,
            longitude: to.longitude
        )
        return fromLocation.distance(from: toLocation) / 1000.0  // 转换为公里
    }

    /// 获取当前用户位置（从 LocationManager 获取真实 GPS）
    private func getCurrentLocation() -> LocationPoint? {
        guard let coordinate = LocationManager.shared.userLocation else {
            print("⚠️ [距离过滤] LocationManager 无位置数据")
            return nil
        }
        return LocationPoint(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    /// 根据频道ID获取频道信息
    private func getChannelById(_ channelId: UUID) -> CommunicationChannel? {
        // 先从已订阅频道中查找
        if let subscribedChannel = subscribedChannels.first(where: { $0.channel.id == channelId }) {
            return subscribedChannel.channel
        }
        // 再从公开频道列表中查找
        return channels.first(where: { $0.id == channelId })
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
