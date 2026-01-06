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

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

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

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 记录日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

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

        // 使用第一个点作为参考原点，将所有点投影到局部平面坐标系
        guard let origin = pathCoordinates.first else {
            return 0
        }

        // 将经纬度坐标转换为以米为单位的平面坐标 (x, y)
        var points: [(x: Double, y: Double)] = []

        for coord in pathCoordinates {
            let x = coordToMeters(lat: origin.latitude, lon1: origin.longitude, lon2: coord.longitude)
            let y = coordToMeters(lat: origin.latitude, lat1: origin.latitude, lat2: coord.latitude)
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

    /// 将经纬度差值转换为米（用于面积计算）
    /// - Parameters:
    ///   - lat: 参考纬度
    ///   - lon1: 起始经度（或纬度）
    ///   - lon2: 结束经度（或纬度）
    /// - Returns: 距离（米）
    private func coordToMeters(lat: Double, lon1: Double, lon2: Double) -> Double {
        let earthRadius: Double = 6371000  // ✅ 地球半径（米）

        // ✅ 转换为弧度
        let lat1Rad = lat * .pi / 180
        let lon1Rad = lon1 * .pi / 180
        let lon2Rad = lon2 * .pi / 180

        // 计算经度差对应的距离（在给定纬度下）
        let dLon = lon2Rad - lon1Rad
        let distance = earthRadius * cos(lat1Rad) * dLon

        return distance
    }

    /// 将纬度差值转换为米（用于面积计算）
    /// - Parameters:
    ///   - lat: 参考纬度（未使用，但保持接口一致）
    ///   - lat1: 起始纬度
    ///   - lat2: 结束纬度
    /// - Returns: 距离（米）
    private func coordToMeters(lat: Double, lat1: Double, lat2: Double) -> Double {
        let earthRadius: Double = 6371000  // ✅ 地球半径（米）

        // ✅ 转换为弧度
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180

        // 计算纬度差对应的距离
        let dLat = lat2Rad - lat1Rad
        let distance = earthRadius * dLat

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
        // ⚠️ 已闭合则不再检测（避免重复判断）
        guard !isPathClosed else {
            return
        }

        // 检查点数是否足够（至少要有最小点数才判定）
        guard pathCoordinates.count >= minimumPathPoints else {
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

        print("🔄 [闭环检测] 距离起点 \(String(format: "%.1f", distance))米")

        // 记录日志（点数 ≥10 且未闭环时）
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤30m)", type: .info)

        // 步骤1：先判定是否闭环
        if distance <= closureDistanceThreshold {
            // ✅ 闭环成功！
            isPathClosed = true
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

        // ✅ GPS 精度检查：只接受精度 ≤ 20 米的位置
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 20 else {
            print("⚠️ [路径追踪] GPS 精度差 (\(String(format: "%.1f", location.horizontalAccuracy))m)，跳过采样")
            TerritoryLogger.shared.log("GPS 精度差 (\(String(format: "%.1f", location.horizontalAccuracy))m)，跳过", type: .warning)
            return
        }

        // 速度验证（防止作弊）
        guard validateMovementSpeed(newLocation: location) else {
            print("🚫 [路径追踪] 速度验证失败，停止记录")
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

        let count = pathCoordinates.count
        print("📍 [路径追踪] 记录新点: 纬度 \(coordinate.latitude), 经度 \(coordinate.longitude)，当前共 \(count) 个点，精度 \(String(format: "%.1f", location.horizontalAccuracy))m")

        // 记录日志
        if let lastCoordinate = pathCoordinates.dropLast().last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = currentLocation.distance(from: lastLocation)
            TerritoryLogger.shared.log("记录第 \(count) 个点，距上点 \(String(format: "%.1f", distance))m，精度 \(String(format: "%.1f", location.horizontalAccuracy))m", type: .info)
        } else {
            TerritoryLogger.shared.log("记录第 \(count) 个点（起点），精度 \(String(format: "%.1f", location.horizontalAccuracy))m", type: .info)
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
