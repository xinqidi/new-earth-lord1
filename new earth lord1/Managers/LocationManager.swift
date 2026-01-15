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

    /// 完整的位置信息（包含精度、速度等）- 用于探索功能
    @Published var currentFullLocation: CLLocation?

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

    /// 上次闭环检测时的点数（用于检测点数变化）
    private var lastClosureCheckPointCount: Int = 0

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速（>30 km/h）
    @Published var isOverSpeed: Bool = false

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    /// 开始追踪的时间
    @Published var trackingStartTime: Date?

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 位置过滤器（Kalman 简化版）
    private let locationFilter = LocationFilter()

    /// 上一个记录点的时间戳（用于速度计算）
    private var lastRecordedTimestamp: Date?

    /// 路径更新定时器（每2秒采样一次）
    private var pathUpdateTimer: Timer?

    /// 上次速度警告的时间戳
    private var lastSpeedWarningTime: Date?

    /// 速度警告清除定时器
    private var speedWarningTimer: Timer?

    // MARK: - Constants

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    /// 速度警告阈值（km/h）
    private let speedWarningThreshold: Double = 15.0

    /// 速度停止阈值（km/h）
    private let speedStopThreshold: Double = 30.0

    /// 速度警告冷却时间（秒）- 防止频繁弹出警告
    private let speedWarningCooldown: TimeInterval = 5.0

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
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // 导航级精度（使用传感器融合）
        locationManager.distanceFilter = kCLDistanceFilterNone // 接收所有位置更新（由我们的过滤器处理）

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus

        print("🌍 [定位管理] LocationManager 初始化完成")
    }

    // MARK: - Public Methods

    /// 请求定位权限（首先请求"使用时"权限）
    func requestPermission() {
        print("🔑 [定位管理] 请求定位权限")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 请求"始终"位置权限（用于地理围栏功能）
    /// 注意：必须先获得"使用时"权限后才能请求"始终"权限
    func requestAlwaysPermission() {
        print("🔑 [定位管理] 请求始终位置权限（用于地理围栏）")
        locationManager.requestAlwaysAuthorization()
    }

    /// 是否已有"始终"位置权限
    var hasAlwaysPermission: Bool {
        return authorizationStatus == .authorizedAlways
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

    // MARK: - Geofence Monitoring

    /// 开始监控地理围栏
    func startMonitoringGeofence(_ region: CLCircularRegion) {
        locationManager.startMonitoring(for: region)
        print("📍 [围栏] 开始监控围栏: \(region.identifier)")
    }

    /// 停止监控地理围栏
    func stopMonitoringGeofence(_ region: CLCircularRegion) {
        locationManager.stopMonitoring(for: region)
        print("🛑 [围栏] 停止监控围栏: \(region.identifier)")
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
        trackingStartTime = Date()

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        lastClosureCheckPointCount = 0

        // 重置位置过滤器
        locationFilter.reset()
        lastRecordedTimestamp = nil

        // 记录日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 确保定位已开启
        if locationManager.location == nil {
            startUpdatingLocation()
        }

        // 启动定时器，每2秒采样一次记录点
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }
    }

    /// 停止路径追踪
    func stopPathTracking() {
        print("⏸️ [路径追踪] 停止追踪路径")

        isTracking = false

        // 记录日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 清除速度警告
        speedWarning = nil
        isOverSpeed = false
        lastSpeedWarningTime = nil
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil

        // ⚠️ 重置所有状态（防止重复上传）
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        trackingStartTime = nil
        lastClosureCheckPointCount = 0
    }

    /// 清除路径
    func clearPath() {
        print("🗑️ [路径追踪] 清除路径")

        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastSpeedWarningTime = nil
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        lastClosureCheckPointCount = 0
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else {
            return 0
        }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 使用鞋带公式计算多边形面积（投影到平面坐标系）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        // ✅ 检查点数
        guard pathCoordinates.count >= 3 else {
            TerritoryLogger.shared.log("  面积计算: 点数不足 (\(pathCoordinates.count)个点)", type: .warning)
            return 0
        }

        // 使用质心作为参考点（更精确）
        let centerLat = pathCoordinates.map { $0.latitude }.reduce(0, +) / Double(pathCoordinates.count)
        let centerLon = pathCoordinates.map { $0.longitude }.reduce(0, +) / Double(pathCoordinates.count)

        // 将经纬度坐标转换为以米为单位的平面坐标 (x, y)
        var points: [(x: Double, y: Double)] = []

        for coord in pathCoordinates {
            // 使用更精确的Haversine投影
            let x = haversineDistance(
                lat1: centerLat, lon1: centerLon,
                lat2: centerLat, lon2: coord.longitude
            ) * (coord.longitude > centerLon ? 1.0 : -1.0)

            let y = haversineDistance(
                lat1: centerLat, lon1: centerLon,
                lat2: coord.latitude, lon2: centerLon
            ) * (coord.latitude > centerLat ? 1.0 : -1.0)

            points.append((x: x, y: y))
        }

        // 使用鞋带公式计算多边形面积
        var area: Double = 0
        let n = points.count

        for i in 0..<n {
            let j = (i + 1) % n  // 下一个点（循环）
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }

        // ✅ 取绝对值并除以 2
        area = abs(area / 2.0)

        TerritoryLogger.shared.log("  面积计算详情: \(pathCoordinates.count)个点 → \(String(format: "%.2f", area))m²", type: .info)

        return area
    }

    /// 使用 Haversine 公式计算两点间的精确距离
    /// - Parameters:
    ///   - lat1: 起点纬度
    ///   - lon1: 起点经度
    ///   - lat2: 终点纬度
    ///   - lon2: 终点经度
    /// - Returns: 距离（米）
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius: Double = 6371000  // 地球半径（米）

        // 转换为弧度
        let lat1Rad = lat1 * .pi / 180
        let lon1Rad = lon1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let lon2Rad = lon2 * .pi / 180

        // 计算差值
        let dLat = lat2Rad - lat1Rad
        let dLon = lon2Rad - lon1Rad

        // Haversine 公式
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        let distance = earthRadius * c

        return distance
    }

    // MARK: - 自相交检测

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: 是否相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断 C 是否在 AB 的逆时针方向
        /// - Parameters:
        ///   - A: 点 A
        ///   - B: 点 B
        ///   - C: 点 C
        /// - Returns: 叉积 > 0 则为 true（逆时针）
        func ccw(A: CLLocationCoordinate2D, B: CLLocationCoordinate2D, C: CLLocationCoordinate2D) -> Bool {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            // 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                             (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且
        // ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(A: p1, B: p3, C: p4) != ccw(A: p2, B: p3, C: p4) &&
               ccw(A: p1, B: p2, C: p3) != ccw(A: p1, B: p2, C: p4)
    }

    /// 检测路径是否自相交（画"8"字形则返回 true）
    /// - Returns: 是否有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // 步骤1：检查路径内部的线段是否相交
        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            // 从 i+2 开始比较（跳过相邻线段）
            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 只跳过首尾直接相连的线段比较（避免闭环时误判）
                // 即：第一条线段(0) 不与最后一条线段(segmentCount-1) 比较
                if i == 0 && j == segmentCount - 1 {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("  发现相交: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1)", type: .warning)
                    return true
                }
            }
        }

        // 步骤2：检查闭环线段（最后一个点回到第一个点）是否与路径相交
        guard let firstPoint = pathSnapshot.first,
              let lastPoint = pathSnapshot.last else {
            return false
        }

        // 闭环线段：从最后一个点到第一个点
        let closureP1 = lastPoint
        let closureP2 = firstPoint

        // 检查闭环线段是否与路径中的其他线段相交
        // 注意：跳过第一条线段(0-1)和最后一条线段(n-1到n)，因为它们与闭环线段共享端点
        for i in 1..<(segmentCount - 1) {
            guard i < pathSnapshot.count - 1 else { break }

            let p3 = pathSnapshot[i]
            let p4 = pathSnapshot[i + 1]

            if segmentsIntersect(p1: closureP1, p2: closureP2, p3: p3, p4: p4) {
                TerritoryLogger.shared.log("  发现闭环线段相交: 闭环线段 与 线段\(i)-\(i+1)", type: .warning)
                return true
            }
        }

        return false
    }

    // MARK: - 综合验证

    /// 验证领地是否符合所有规则（闭环后的完整验证）
    /// - Returns: (是否有效, 错误信息)
    private func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始完整验证...", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        TerritoryLogger.shared.log("【1/4】点数检查...", type: .info)
        if pointCount < minimumPathPoints {
            let errorMsg = "点数不足: \(pointCount)个点 (需≥\(minimumPathPoints)个点)"
            TerritoryLogger.shared.log("  ❌ " + errorMsg, type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("  ✓ 点数: \(pointCount)个点", type: .info)

        // 2. 距离检查
        TerritoryLogger.shared.log("【2/4】距离检查...", type: .info)
        let totalDistance = calculateTotalPathDistance()
        TerritoryLogger.shared.log("  总距离: \(String(format: "%.1f", totalDistance))m", type: .info)
        if totalDistance < minimumTotalDistance {
            let errorMsg = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            TerritoryLogger.shared.log("  ❌ " + errorMsg, type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("  ✓ 距离: \(String(format: "%.1f", totalDistance))m", type: .info)

        // 3. 自交检测
        TerritoryLogger.shared.log("【3/4】自交检测...", type: .info)
        if hasPathSelfIntersection() {
            let errorMsg = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("  ❌ " + errorMsg, type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("  ✓ 无自交", type: .info)

        // 4. 面积检查
        TerritoryLogger.shared.log("【4/4】面积检查...", type: .info)
        let area = calculatePolygonArea()
        TerritoryLogger.shared.log("  计算面积: \(String(format: "%.1f", area))m²", type: .info)
        if area < minimumEnclosedArea {
            let errorMsg = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("  ❌ " + errorMsg, type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("  ✓ 面积: \(String(format: "%.1f", area))m²", type: .info)

        // 全部通过
        return (true, nil)
    }

    // MARK: - Closure Detection

    /// 检查路径是否闭合
    /// 判断当前位置是否回到起点（≤30米）
    private func checkPathClosure() {
        // ⚠️ 至少需要5个点才开始闭环检测（避免过早触发）
        guard pathCoordinates.count >= 5 else {
            return
        }

        // 获取起点和当前位置
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distance = currentLocation.distance(from: startLocation)

        print("🔄 [闭环检测] 距离起点 \(String(format: "%.1f", distance))米，当前点数: \(pathCoordinates.count)")

        // 记录日志
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤30m), 点数: \(pathCoordinates.count)", type: .info)

        // 如果已经闭合且验证通过，不再重复检测
        if isPathClosed && territoryValidationPassed {
            return
        }

        // 如果已经闭合但验证失败，检查是否可以重新尝试
        if isPathClosed && !territoryValidationPassed {
            // 条件1：用户离开起点超过50米，重置闭环状态
            // 条件2：点数增加了（用户继续走动），允许重新验证
            if distance > 50 {
                print("🔄 [闭环检测] 用户已离开起点，重置闭环状态")
                isPathClosed = false
                territoryValidationPassed = false
                territoryValidationError = nil
                calculatedArea = 0
                lastClosureCheckPointCount = 0
            } else if pathCoordinates.count > lastClosureCheckPointCount {
                // 点数增加了，且仍在起点附近，允许重新验证
                print("🔄 [闭环检测] 点数增加 (\(lastClosureCheckPointCount) → \(pathCoordinates.count))，允许重新验证")
                isPathClosed = false
                territoryValidationPassed = false
                territoryValidationError = nil
                calculatedArea = 0
            } else {
                // 既没有离开起点，点数也没增加，保持当前状态
                return
            }
        }

        // 步骤1：先判定是否闭环
        if distance <= closureDistanceThreshold {
            // ✅ 闭环成功！
            isPathClosed = true
            lastClosureCheckPointCount = pathCoordinates.count  // 记录当前点数
            print("✅ [闭环检测] 路径已闭合！距离起点 \(String(format: "%.1f", distance))米")

            TerritoryLogger.shared.log("━━━━━━━━━━━━━━━━━━━━━━", type: .success)
            TerritoryLogger.shared.log("✅ 闭环成功！距起点 \(String(format: "%.1f", distance))m", type: .success)
            TerritoryLogger.shared.log("━━━━━━━━━━━━━━━━━━━━━━", type: .info)

            // 步骤2：闭环后进行完整验证（点数、距离、自交、面积）
            let validationResult = validateTerritory()

            // 步骤3：根据验证结果判定圈地是否成功
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage

            if validationResult.isValid {
                // 圈地成功
                calculatedArea = calculatePolygonArea()
                TerritoryLogger.shared.log("━━━━━━━━━━━━━━━━━━━━━━", type: .success)
                TerritoryLogger.shared.log("🎉 圈地成功！", type: .success)
                TerritoryLogger.shared.log("📐 领地面积: \(String(format: "%.1f", calculatedArea))m²", type: .success)
                TerritoryLogger.shared.log("━━━━━━━━━━━━━━━━━━━━━━", type: .success)
            } else {
                // 圈地失败
                calculatedArea = 0
                TerritoryLogger.shared.log("━━━━━━━━━━━━━━━━━━━━━━", type: .error)
                TerritoryLogger.shared.log("❌ 圈地失败: \(validationResult.errorMessage ?? "未知错误")", type: .error)
                TerritoryLogger.shared.log("━━━━━━━━━━━━━━━━━━━━━━", type: .error)
            }
        }
    }

    // MARK: - Speed Validation

    /// 验证移动速度（防止作弊）
    /// - Parameter newLocation: 新位置
    /// - Returns: 是否允许继续追踪（速度 ≤30 km/h 返回 true）
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // ⚠️ 检查 GPS 精度：精度差的位置不参与速度计算
        // horizontalAccuracy > 50 表示误差超过 50 米，不可靠
        guard newLocation.horizontalAccuracy > 0 && newLocation.horizontalAccuracy <= 50 else {
            print("⚠️ [速度检测] GPS 精度差 (\(newLocation.horizontalAccuracy)m)，跳过速度检测")
            return true
        }

        // ⚠️ 使用 CoreLocation 提供的 speed（m/s），已经过系统优化和平滑处理
        // speed < 0 表示无效速度
        guard newLocation.speed >= 0 else {
            print("⚠️ [速度检测] 速度值无效 (\(newLocation.speed))，跳过")
            return true
        }

        // 转换为 km/h
        let speed = newLocation.speed * 3.6

        print("🏃 [速度检测] 速度: \(String(format: "%.1f", speed)) km/h (精度: \(String(format: "%.1f", newLocation.horizontalAccuracy))m)")

        // 判断速度
        if speed > speedStopThreshold {
            // 超速 >30 km/h，自动停止追踪
            speedWarning = String(format: "速度过快（%.1f km/h），已自动停止圈地".localized, speed)
            isOverSpeed = true
            print("🚫 [速度检测] 速度过快，自动停止追踪")

            // 记录错误日志
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speed)) km/h，已停止追踪", type: .error)

            // 停止追踪
            DispatchQueue.main.async {
                self.stopPathTracking()
            }

            return false
        } else if speed > speedWarningThreshold {
            // ⚠️ 检查冷却时间：如果距离上次警告不到5秒，跳过（避免频繁弹窗）
            let now = Date()
            if let lastWarningTime = lastSpeedWarningTime {
                let timeSinceLastWarning = now.timeIntervalSince(lastWarningTime)
                if timeSinceLastWarning < speedWarningCooldown {
                    print("⏸️ [速度检测] 冷却中（已过 \(String(format: "%.1f", timeSinceLastWarning))秒），跳过警告")
                    return true
                }
            }

            // 警告 >15 km/h
            let warningMessage = String(format: "速度较快（%.1f km/h），请放慢速度".localized, speed)

            // 记录警告时间
            lastSpeedWarningTime = now

            // 确保在主线程更新 UI
            DispatchQueue.main.async {
                self.speedWarning = warningMessage
                self.isOverSpeed = false
            }

            print("⚠️ [速度检测] 速度较快，发出警告")

            // 记录警告日志
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speed)) km/h", type: .warning)

            // 取消之前的定时器
            speedWarningTimer?.invalidate()

            // 5秒后清除警告（使用 Timer 而不是 asyncAfter）
            speedWarningTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.speedWarning = nil
                }
            }

            return true
        } else {
            // 速度正常（不记录日志，避免日志过多）
            DispatchQueue.main.async {
                self.speedWarning = nil
                self.isOverSpeed = false
            }

            // 清除冷却时间，允许下次立即警告
            lastSpeedWarningTime = nil

            return true
        }
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        guard let location = currentLocation else {
            print("⚠️ [路径追踪] 当前位置为空，跳过采样")
            return
        }

        // ✅ 步骤1：将原始位置传入过滤器，获取过滤后的位置
        guard let filteredLocation = locationFilter.addLocation(location) else {
            print("⚠️ [路径追踪] 位置过滤失败（精度差或缓冲区不足），跳过")
            return
        }

        // ✅ 步骤2：速度验证（防止作弊）- 使用过滤后的位置
        guard validateMovementSpeed(newLocation: filteredLocation) else {
            print("🚫 [路径追踪] 速度验证失败，停止记录")
            return
        }

        let filteredCoordinate = filteredLocation.coordinate

        // ✅ 步骤4：检查与上一个记录点的距离（>10米才记录）
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = filteredLocation.distance(from: lastLocation)

            if distance < 10 {
                print("📏 [路径追踪] 距离上个点仅 \(String(format: "%.1f", distance))米 (<10m)，跳过")
                return
            }

            // ✅ 步骤5：GPS 漂移检测（距离过大且精度差 = 漂移）
            // 最高速度30km/h ≈ 8.3m/s，采样间隔2秒，理论最大距离16.6m
            // 考虑误差和加速过程，设置阈值为35米
            let timeDelta: TimeInterval
            if let lastTimestamp = lastRecordedTimestamp {
                timeDelta = filteredLocation.timestamp.timeIntervalSince(lastTimestamp)
            } else {
                timeDelta = 2.0  // 首次记录，使用采样间隔
            }

            let speed = timeDelta > 0 ? distance / timeDelta : 0  // m/s
            let accuracy = filteredLocation.horizontalAccuracy

            // 综合判断：距离过大 OR (速度异常 AND 精度差)
            if distance > 35 || (speed > 15 && accuracy > 20) {
                print("⚠️ [路径追踪] GPS跳跃检测: 距离\(String(format: "%.1f", distance))m, 速度\(String(format: "%.1f", speed))m/s, 精度\(String(format: "%.1f", accuracy))m - 疑似漂移，跳过")
                TerritoryLogger.shared.log("GPS跳跃检测: 距离\(String(format: "%.1f", distance))m - 跳过", type: .warning)
                return
            }
        }

        // ✅ 步骤6：记录过滤后的坐标点
        pathCoordinates.append(filteredCoordinate)
        pathUpdateVersion += 1
        lastRecordedTimestamp = filteredLocation.timestamp  // 更新时间戳

        let count = pathCoordinates.count
        print("📍 [路径追踪] 记录新点: 纬度 \(filteredCoordinate.latitude), 经度 \(filteredCoordinate.longitude)，当前共 \(count) 个点，过滤后精度 \(String(format: "%.1f", filteredLocation.horizontalAccuracy))m")

        // 记录日志
        if let lastCoordinate = pathCoordinates.dropLast().last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentLocation = CLLocation(latitude: filteredCoordinate.latitude, longitude: filteredCoordinate.longitude)
            let distance = currentLocation.distance(from: lastLocation)
            TerritoryLogger.shared.log("记录第 \(count) 个点，距上点 \(String(format: "%.1f", distance))m，过滤后精度 \(String(format: "%.1f", filteredLocation.horizontalAccuracy))m", type: .info)
        } else {
            TerritoryLogger.shared.log("记录第 \(count) 个点（起点），过滤后精度 \(String(format: "%.1f", filteredLocation.horizontalAccuracy))m", type: .info)
        }

        // 检查路径闭合
        checkPathClosure()
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
            self.currentFullLocation = location  // 发布完整位置供探索功能使用
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

    // MARK: - Geofence Delegate

    /// 进入地理围栏时调用
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        print("🎯 [围栏] 进入围栏: \(circularRegion.identifier)")

        // 发送通知，让ExplorationManager处理
        NotificationCenter.default.post(
            name: .didEnterPOIRegion,
            object: nil,
            userInfo: ["regionId": circularRegion.identifier]
        )
    }

    /// 围栏监控失败时调用
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("❌ [围栏] 监控失败: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }
}
