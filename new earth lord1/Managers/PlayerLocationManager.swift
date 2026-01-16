//
//  PlayerLocationManager.swift
//  new earth lord1
//
//  玩家位置管理器
//  负责位置上报和附近玩家密度查询
//

import Foundation
import CoreLocation
import Combine
import Supabase
import UIKit

/// 玩家密度等级
enum PlayerDensityLevel: String, CaseIterable {
    case alone   // 0人
    case low     // 1-5人
    case medium  // 6-20人
    case high    // 20人以上

    /// 密度等级对应的最大POI数量
    var maxPOICount: Int {
        switch self {
        case .alone: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return 15
        }
    }

    /// 密度等级显示名称
    var displayName: String {
        switch self {
        case .alone: return "独行者"
        case .low: return "低密度"
        case .medium: return "中密度"
        case .high: return "高密度"
        }
    }

    /// 根据附近玩家数量判断密度等级
    static func fromPlayerCount(_ count: Int) -> PlayerDensityLevel {
        switch count {
        case 0:
            return .alone
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }
}

/// 玩家位置管理器
/// 负责位置上报到服务器，以及查询附近玩家数量
class PlayerLocationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PlayerLocationManager()

    // MARK: - Published Properties

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var currentDensityLevel: PlayerDensityLevel = .alone

    /// 最后一次位置上报时间
    @Published var lastReportTime: Date?

    /// 是否正在上报
    @Published var isReporting: Bool = false

    // MARK: - Private Properties

    /// Supabase客户端
    private var supabase: SupabaseClient?

    /// 当前用户ID
    private var userId: UUID?

    /// 位置管理器引用
    private weak var locationManager: LocationManager?

    /// 上次上报的位置（用于判断是否移动超过50米）
    private var lastReportedLocation: CLLocation?

    /// 位置更新订阅
    private var locationCancellable: AnyCancellable?

    /// 定时上报Timer
    private var reportTimer: Timer?

    /// App状态订阅
    private var appStateCancellable: AnyCancellable?

    // MARK: - Constants

    /// 定时上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 触发立即上报的移动距离阈值（米）
    private let movementThreshold: CLLocationDistance = 50.0

    /// 附近玩家查询半径（米）
    private let queryRadius: Int = 1000

    // MARK: - Initialization

    private init() {
        print("📍 [位置上报] PlayerLocationManager 初始化")
    }

    // MARK: - Configuration

    /// 配置管理器
    func configure(supabase: SupabaseClient, userId: UUID, locationManager: LocationManager) {
        self.supabase = supabase
        self.userId = userId
        self.locationManager = locationManager
        print("📍 [位置上报] 配置完成，用户ID: \(userId)")
    }

    // MARK: - Reporting Control

    /// 开始位置上报
    func startReporting() {
        guard supabase != nil, userId != nil else {
            print("❌ [位置上报] 未配置，无法开始上报")
            return
        }

        guard !isReporting else {
            print("⚠️ [位置上报] 已在上报中")
            return
        }

        isReporting = true
        print("🚀 [位置上报] 开始位置上报")

        // 立即上报一次当前位置
        Task {
            await reportCurrentLocation(isOnline: true)
        }

        // 启动定时上报（每30秒）
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.reportCurrentLocation(isOnline: true)
            }
        }

        // 订阅位置更新，检测是否移动超过50米
        locationCancellable = locationManager?.$currentFullLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.checkMovementAndReport(location: location)
            }

        // 监听App进入后台
        appStateCancellable = NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                print("📍 [位置上报] App进入后台，标记为离线")
                Task {
                    await self?.reportCurrentLocation(isOnline: false)
                }
            }
    }

    /// 停止位置上报
    func stopReporting() {
        isReporting = false

        // 停止定时器
        reportTimer?.invalidate()
        reportTimer = nil

        // 取消订阅
        locationCancellable?.cancel()
        locationCancellable = nil
        appStateCancellable?.cancel()
        appStateCancellable = nil

        // 上报离线状态
        Task {
            await reportCurrentLocation(isOnline: false)
        }

        print("🛑 [位置上报] 停止位置上报")
    }

    // MARK: - Location Reporting

    /// 上报当前位置
    func reportCurrentLocation(isOnline: Bool = true) async {
        guard let supabase = supabase else {
            print("❌ [位置上报] Supabase未配置")
            return
        }

        guard let location = locationManager?.currentFullLocation else {
            print("⚠️ [位置上报] 当前位置为空")
            return
        }

        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        do {
            // 调用RPC函数上报位置
            try await supabase.rpc(
                "report_player_location",
                params: [
                    "p_latitude": AnyJSON(latitude),
                    "p_longitude": AnyJSON(longitude),
                    "p_is_online": AnyJSON(isOnline)
                ]
            ).execute()

            lastReportTime = Date()
            lastReportedLocation = location

            print("✅ [位置上报] 上报成功: (\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude))), 在线: \(isOnline)")

        } catch {
            print("❌ [位置上报] 上报失败: \(error.localizedDescription)")
        }
    }

    /// 检查是否移动超过阈值并上报
    private func checkMovementAndReport(location: CLLocation) {
        guard let lastLocation = lastReportedLocation else {
            // 首次位置更新
            return
        }

        let distance = location.distance(from: lastLocation)

        if distance >= movementThreshold {
            print("📍 [位置上报] 移动超过\(movementThreshold)米，立即上报")
            Task {
                await reportCurrentLocation(isOnline: true)
            }
        }
    }

    // MARK: - Nearby Player Query

    /// 查询附近玩家数量
    /// - Returns: 附近在线玩家数量
    func queryNearbyPlayerCount() async -> Int {
        guard let supabase = supabase else {
            print("❌ [位置上报] Supabase未配置")
            return 0
        }

        guard let location = locationManager?.currentFullLocation else {
            print("⚠️ [位置上报] 当前位置为空")
            return 0
        }

        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        do {
            // 调用RPC函数查询附近玩家
            let response: Int = try await supabase.rpc(
                "get_nearby_player_count",
                params: [
                    "p_latitude": AnyJSON(latitude),
                    "p_longitude": AnyJSON(longitude),
                    "p_radius_meters": AnyJSON(queryRadius)
                ]
            ).execute().value

            await MainActor.run {
                self.nearbyPlayerCount = response
                self.currentDensityLevel = PlayerDensityLevel.fromPlayerCount(response)
            }

            print("✅ [位置上报] 附近玩家: \(response)人，密度等级: \(currentDensityLevel.displayName)")
            return response

        } catch {
            print("❌ [位置上报] 查询附近玩家失败: \(error.localizedDescription)")
            return 0
        }
    }

    /// 获取当前密度等级对应的最大POI数量
    func getMaxPOICount() -> Int {
        return currentDensityLevel.maxPOICount
    }
}
