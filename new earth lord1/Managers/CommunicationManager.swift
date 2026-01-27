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

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient?

    /// 当前用户 ID
    private var userId: UUID?

    /// 是否已配置
    private var isConfigured: Bool = false

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

    // MARK: - Cleanup

    /// 清除状态（退出登录时调用）
    func clearState() {
        devices = []
        currentDevice = nil
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
