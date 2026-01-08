//
//  LocationFilter.swift
//  new earth lord1
//
//  GPS 位置过滤器（简化版 Kalman 滤波）
//  用于减少 GPS 漂移和提高定位精度
//

import CoreLocation
import Foundation

/// GPS 位置过滤器（基于加权平均的简化 Kalman 滤波）
class LocationFilter {

    // MARK: - Properties

    /// 位置历史缓冲区（最近5个位置）
    private var locationBuffer: [CLLocation] = []

    /// 缓冲区大小
    private let bufferSize: Int = 5

    /// 最小精度阈值（米）- 只接受精度优于此值的位置
    private let minimumAccuracy: Double = 10.0

    /// 过滤后的位置（当前最佳估计）
    private(set) var filteredLocation: CLLocation?

    // MARK: - Public Methods

    /// 添加新的GPS位置并返回过滤后的位置
    /// - Parameter location: 新的GPS位置
    /// - Returns: 过滤后的位置（如果缓冲区不足或精度太差则返回nil）
    func addLocation(_ location: CLLocation) -> CLLocation? {
        // ✅ 步骤1：精度检查（只接受高精度位置）
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= minimumAccuracy else {
            print("⚠️ [位置过滤] GPS精度差 (\(String(format: "%.1f", location.horizontalAccuracy))m)，跳过")
            return filteredLocation // 返回上次过滤结果
        }

        // ✅ 步骤2：添加到缓冲区
        locationBuffer.append(location)

        // 保持缓冲区大小
        if locationBuffer.count > bufferSize {
            locationBuffer.removeFirst()
        }

        // ✅ 步骤3：计算过滤后的位置
        filteredLocation = calculateFilteredLocation()

        if let filtered = filteredLocation {
            print("📍 [位置过滤] 过滤后位置: 纬度 \(filtered.coordinate.latitude), 经度 \(filtered.coordinate.longitude), 精度 \(String(format: "%.1f", filtered.horizontalAccuracy))m")
        }

        return filteredLocation
    }

    /// 重置过滤器（清空缓冲区）
    func reset() {
        locationBuffer.removeAll()
        filteredLocation = nil
        print("🔄 [位置过滤] 过滤器已重置")
    }

    /// 检查缓冲区是否已稳定（至少有3个位置）
    var isStable: Bool {
        return locationBuffer.count >= 3
    }

    // MARK: - Private Methods

    /// 使用加权平均计算过滤后的位置
    /// 权重基于 horizontalAccuracy（精度越高权重越大）
    /// - Returns: 过滤后的位置
    private func calculateFilteredLocation() -> CLLocation? {
        guard !locationBuffer.isEmpty else {
            return nil
        }

        // 如果只有1个位置，直接返回
        if locationBuffer.count == 1 {
            return locationBuffer.first
        }

        // ✅ 计算权重：权重 = 1 / accuracy²（精度越高权重越大）
        var totalWeight: Double = 0
        var weightedLat: Double = 0
        var weightedLon: Double = 0
        var weightedAlt: Double = 0
        var latestTimestamp: Date = locationBuffer.first!.timestamp

        for location in locationBuffer {
            // 权重计算：accuracy 越小，权重越大
            let accuracy = max(location.horizontalAccuracy, 1.0) // 避免除以0
            let weight = 1.0 / (accuracy * accuracy)

            totalWeight += weight
            weightedLat += location.coordinate.latitude * weight
            weightedLon += location.coordinate.longitude * weight
            weightedAlt += location.altitude * weight

            // 使用最新的时间戳
            if location.timestamp > latestTimestamp {
                latestTimestamp = location.timestamp
            }
        }

        // ✅ 计算加权平均
        let filteredLat = weightedLat / totalWeight
        let filteredLon = weightedLon / totalWeight
        let filteredAlt = weightedAlt / totalWeight

        // ✅ 计算过滤后的精度（使用最佳精度作为估计）
        let bestAccuracy = locationBuffer.map { $0.horizontalAccuracy }.min() ?? 10.0

        // 创建过滤后的位置
        let filteredCoordinate = CLLocationCoordinate2D(latitude: filteredLat, longitude: filteredLon)

        let filteredLocation = CLLocation(
            coordinate: filteredCoordinate,
            altitude: filteredAlt,
            horizontalAccuracy: bestAccuracy,
            verticalAccuracy: locationBuffer.last?.verticalAccuracy ?? -1,
            timestamp: latestTimestamp
        )

        return filteredLocation
    }
}
