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

            let territories = try JSONDecoder().decode([Territory].self, from: response.data)

            print("✅ [领地管理器] 加载领地成功 - 数量: \(territories.count)")
            return territories

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
