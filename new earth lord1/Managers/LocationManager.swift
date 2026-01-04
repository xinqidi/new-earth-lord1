//
//  LocationManager.swift
//  new earth lord1
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、处理定位错误
//

import Foundation
import CoreLocation
import Combine

/// GPS 定位管理器
/// 使用 CoreLocation 获取用户位置，支持权限管理和错误处理
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（用于圈地判断）
    @Published var isPathClosed: Bool = false

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径更新定时器（每2秒采样一次）
    private var pathUpdateTimer: Timer?

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// 是否被拒绝授权
    var isDenied: Bool {
        return authorizationStatus == .denied
    }

    // MARK: - Initialization

    override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // 最高精度
        locationManager.distanceFilter = 10 // 移动10米才更新位置

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus

        print("🌍 [定位管理] LocationManager 初始化完成")
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        print("🔑 [定位管理] 请求定位权限")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("⚠️ [定位管理] 未授权，无法开始定位")
            locationError = "未获得定位权限"
            return
        }

        print("📍 [定位管理] 开始更新位置")
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        print("🛑 [定位管理] 停止更新位置")
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Path Tracking Methods

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            print("⚠️ [路径追踪] 未授权定位，无法开始追踪")
            return
        }

        print("🚀 [路径追踪] 开始追踪路径")

        isTracking = true
        isPathClosed = false

        // 确保定位已开启
        if locationManager.location == nil {
            startUpdatingLocation()
        }

        // 启动定时器，每2秒采样一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }
    }

    /// 停止路径追踪
    func stopPathTracking() {
        print("⏸️ [路径追踪] 停止追踪路径")

        isTracking = false

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil
    }

    /// 清除路径
    func clearPath() {
        print("🗑️ [路径追踪] 清除路径")

        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        guard let location = currentLocation else {
            print("⚠️ [路径追踪] 当前位置为空，跳过采样")
            return
        }

        let coordinate = location.coordinate

        // 检查是否与上一个点距离足够远（>10米才记录）
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            if distance < 10 {
                print("📏 [路径追踪] 距离上个点仅 \(String(format: "%.1f", distance))米，跳过")
                return
            }
        }

        // 记录新点
        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1

        print("📍 [路径追踪] 记录新点: 纬度 \(coordinate.latitude), 经度 \(coordinate.longitude)，当前共 \(pathCoordinates.count) 个点")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态改变时调用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("🔐 [定位管理] 授权状态改变: \(manager.authorizationStatus.rawValue)")

        // 更新授权状态
        authorizationStatus = manager.authorizationStatus

        // 如果已授权，自动开始定位
        if isAuthorized {
            print("✅ [定位管理] 已授权，开始定位")
            startUpdatingLocation()
        } else if isDenied {
            print("❌ [定位管理] 用户拒绝授权")
            locationError = "定位权限被拒绝，请在设置中开启"
        }
    }

    /// 成功获取位置时调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // 更新当前位置（供 Timer 采点使用）
        currentLocation = location

        // 更新用户位置
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil
        }

        print("📍 [定位管理] 位置更新: 纬度 \(location.coordinate.latitude), 经度 \(location.coordinate.longitude)")
    }

    /// 定位失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [定位管理] 定位失败: \(error.localizedDescription)")

        DispatchQueue.main.async {
            self.locationError = "定位失败: \(error.localizedDescription)"
        }
    }
}
