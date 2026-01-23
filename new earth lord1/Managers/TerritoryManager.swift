//
//  TerritoryManager.swift
//  new earth lord1
//
//  领地管理器
//  负责领地数据的上传和拉取
//

import Foundation
import CoreLocation
import Supabase

class TerritoryManager {

    // MARK: - Properties

    /// Supabase 客户端
    private let supabase: SupabaseClient

    /// 缓存的领地数据（用于碰撞检测）
    var territories: [Territory] = []

    // MARK: - Initialization

    /// 初始化领地管理器
    /// - Parameter supabase: Supabase 客户端实例
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Public Methods

    /// 上传领地数据到 Supabase
    /// - Parameters:
    ///   - userId: 用户 ID
    ///   - coordinates: 路径坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(userId: UUID, coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        // 1. 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)

        // 2. 构建上传数据
        struct TerritoryUploadData: Encodable {
            let user_id: String
            let path: [[String: Double]]
            let polygon: String
            let bbox_min_lat: Double
            let bbox_max_lat: Double
            let bbox_min_lon: Double
            let bbox_max_lon: Double
            let area: Double
            let point_count: Int
            let started_at: String
            let is_active: Bool
        }

        let territoryData = TerritoryUploadData(
            user_id: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bbox_min_lat: bbox.minLat,
            bbox_max_lat: bbox.maxLat,
            bbox_min_lon: bbox.minLon,
            bbox_max_lon: bbox.maxLon,
            area: area,
            point_count: coordinates.count,
            started_at: startTime.ISO8601Format(),
            is_active: true
        )

        // 3. 上传到 Supabase
        do {
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("✅ [领地管理器] 上传成功 - 面积: \(String(format: "%.0f", area))m², 点数: \(coordinates.count)")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)

        } catch {
            print("❌ [领地管理器] 上传失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw TerritoryError.uploadFailed(error)
        }
    }

    /// 加载所有活跃的领地
    /// - Returns: 领地数组
    /// - Throws: 查询失败时抛出错误
    func loadAllTerritories() async throws -> [Territory] {
        do {
            let response = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()

            let loadedTerritories = try JSONDecoder().decode([Territory].self, from: response.data)

            // 更新缓存
            self.territories = loadedTerritories

            print("✅ [领地管理器] 加载领地成功 - 数量: \(loadedTerritories.count)")
            return loadedTerritories

        } catch {
            print("❌ [领地管理器] 加载领地失败: \(error.localizedDescription)")
            throw TerritoryError.loadFailed(error)
        }
    }

    /// 加载我的领地
    /// - Parameter userId: 用户 ID
    /// - Returns: 我的领地数组
    /// - Throws: 查询失败时抛出错误
    func loadMyTerritories(userId: UUID) async throws -> [Territory] {
        do {
            let response = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()

            let territories = try JSONDecoder().decode([Territory].self, from: response.data)

            print("✅ [领地管理器] 加载我的领地成功 - 数量: \(territories.count)")
            TerritoryLogger.shared.log("加载我的领地成功 - 数量: \(territories.count)", type: .info)
            return territories

        } catch {
            print("❌ [领地管理器] 加载我的领地失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("加载我的领地失败: \(error.localizedDescription)", type: .error)
            throw TerritoryError.loadFailed(error)
        }
    }

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: String) async -> Bool {
        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            print("✅ [领地管理器] 删除领地成功 - ID: \(territoryId)")
            TerritoryLogger.shared.log("删除领地成功", type: .info)
            return true

        } catch {
            print("❌ [领地管理器] 删除领地失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("删除领地失败: \(error.localizedDescription)", type: .error)
            return false
        }
    }

    /// 更新领地名称
    /// - Parameters:
    ///   - territoryId: 领地 ID
    ///   - newName: 新名称
    /// - Throws: 更新失败时抛出错误
    func updateTerritoryName(territoryId: String, newName: String) async throws {
        struct NameUpdate: Encodable {
            let name: String
        }

        do {
            try await supabase
                .from("territories")
                .update(NameUpdate(name: newName))
                .eq("id", value: territoryId)
                .execute()

            print("✅ [领地管理器] 更新名称成功 - ID: \(territoryId), 新名称: \(newName)")
            TerritoryLogger.shared.log("重命名领地成功: \(newName)", type: .info)

            // 发送通知刷新列表
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)

        } catch {
            print("❌ [领地管理器] 更新名称失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("重命名领地失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - Private Methods

    /// 将坐标数组转换为 JSON 格式的 path
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...]
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            [
                "lat": coord.latitude,
                "lon": coord.longitude
            ]
        }
    }

    /// 将坐标数组转换为 WKT (Well-Known Text) 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 格式的多边形字符串
    /// - Note: WKT 格式是「经度在前，纬度在后」，多边形必须闭合（首尾相同）
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        // 确保多边形闭合
        var coords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            // 只有当首尾不相同时才添加
            if first.latitude != last.latitude || first.longitude != last.longitude {
                coords.append(first)
            }
        }

        // 转换为 WKT 格式：SRID=4326;POLYGON((lon lat, lon lat, ...))
        let pointStrings = coords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        let wkt = "SRID=4326;POLYGON((\(pointStrings.joined(separator: ", "))))"
        return wkt
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        return (
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLon: lons.min() ?? 0,
            maxLon: lons.max() ?? 0
        )
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: 点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    /// - Parameters:
    ///   - location: 起始位置
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 碰撞检测结果
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 第一条线段起点
    ///   - p2: 第一条线段终点
    ///   - p3: 第二条线段起点
    ///   - p4: 第二条线段终点
    /// - Returns: 两条线段是否相交
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越领地边界
    /// - Parameters:
    ///   - path: 当前路径坐标数组
    ///   - currentUserId: 当前用户 ID
    ///   - includeOwnTerritories: 是否包含自己的领地（默认false，只检测他人领地）
    /// - Returns: 碰撞检测结果
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String, includeOwnTerritories: Bool = false) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 根据参数决定检测哪些领地
        let targetTerritories: [Territory]
        if includeOwnTerritories {
            // 检测所有领地（包括自己的）
            targetTerritories = territories
        } else {
            // 只检测他人领地
            targetTerritories = territories.filter { territory in
                territory.userId.lowercased() != currentUserId.lowercased()
            }
        }

        guard !targetTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in targetTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 判断是否为自己的领地
                let isOwnTerritory = territory.userId.lowercased() == currentUserId.lowercased()

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        let message = isOwnTerritory ? "轨迹不能穿越自己已有的领地！".localized : "轨迹不能穿越他人领地！".localized
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越\(isOwnTerritory ? "自己的" : "他人")领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: message,
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    let message = isOwnTerritory ? "轨迹不能进入自己已有的领地！".localized : "轨迹不能进入他人领地！".localized
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入\(isOwnTerritory ? "自己的" : "他人")领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: message,
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到领地的最近距离
    /// - Parameters:
    ///   - location: 当前位置
    ///   - currentUserId: 当前用户 ID
    ///   - includeOwnTerritories: 是否包含自己的领地（默认false，只计算到他人领地的距离）
    /// - Returns: (最近距离（米）, 是否为自己的领地)
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String, includeOwnTerritories: Bool = false) -> (distance: Double, isOwnTerritory: Bool) {
        // 根据参数决定检测哪些领地
        let targetTerritories: [Territory]
        if includeOwnTerritories {
            // 检测所有领地（包括自己的）
            targetTerritories = territories
        } else {
            // 只检测他人领地
            targetTerritories = territories.filter { territory in
                territory.userId.lowercased() != currentUserId.lowercased()
            }
        }

        guard !targetTerritories.isEmpty else { return (Double.infinity, false) }

        var minDistance = Double.infinity
        var isClosestOwnTerritory = false
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in targetTerritories {
            let polygon = territory.toCoordinates()
            let isOwnTerritory = territory.userId.lowercased() == currentUserId.lowercased()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)

                if distance < minDistance {
                    minDistance = distance
                    isClosestOwnTerritory = isOwnTerritory
                }
            }
        }

        return (minDistance, isClosestOwnTerritory)
    }

    /// 综合碰撞检测（主方法）
    /// - Parameters:
    ///   - path: 当前路径坐标数组
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 碰撞检测结果
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越所有领地（包括自己已有的领地）
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId, includeOwnTerritories: true)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离（包括自己的领地）
        guard let lastPoint = path.last else { return .safe }
        let (minDistance, isOwnTerritory) = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId, includeOwnTerritories: true)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?
        let territoryType = isOwnTerritory ? "已有领地" : "他人领地"

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = String(format: "注意：距离%@ %dm".localized, territoryType, Int(minDistance))
        } else if minDistance > 25 {
            warningLevel = .warning
            message = String(format: "警告：正在靠近%@（%dm）".localized, territoryType, Int(minDistance))
        } else {
            warningLevel = .danger
            message = String(format: "危险：即将进入%@！（%dm）".localized, territoryType, Int(minDistance))
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离\(territoryType) \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }
}

// MARK: - TerritoryError

enum TerritoryError: LocalizedError {
    case uploadFailed(Error)
    case loadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .uploadFailed(let error):
            return "上传失败: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "加载失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// 领地更新通知（重命名、删除后发送）
    static let territoryUpdated = Notification.Name("territoryUpdated")
}
