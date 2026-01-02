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

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

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
