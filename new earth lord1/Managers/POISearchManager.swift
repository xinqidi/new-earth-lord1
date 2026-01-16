//
//  POISearchManager.swift
//  new earth lord1
//
//  POI搜索管理器
//  使用MapKit MKLocalSearch搜索附近真实地点
//

import Foundation
import CoreLocation
import MapKit

/// POI搜索管理器
/// 负责搜索附近真实POI并映射为游戏POI类型
class POISearchManager {

    // MARK: - Singleton

    static let shared = POISearchManager()

    private init() {}

    // MARK: - Constants

    /// 搜索半径（米）
    private let searchRadius: CLLocationDistance = 1000

    /// 最大POI数量（iOS围栏限制为20个）
    private let maxPOICount = 15

    // MARK: - Apple POI类型映射

    /// 将MKPointOfInterestCategory映射为游戏POIType
    private func mapToGamePOIType(category: MKPointOfInterestCategory?) -> POIType? {
        guard let category = category else { return nil }

        switch category {
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation:
            return .gasStation
        case .store, .foodMarket:
            return .supermarket
        case .school, .university:
            return .school
        default:
            // 其他类型映射为仓库
            return .warehouse
        }
    }

    /// 获取POI类型的末世风格名称
    private func getApocalypticName(for type: POIType, originalName: String) -> String {
        // 为真实地点名称添加末世风格
        let prefixes = ["废弃的", "荒废的", "破败的", "遗弃的"]
        let prefix = prefixes.randomElement() ?? "废弃的"
        return "\(prefix)\(originalName)"
    }

    /// 获取POI类型的描述
    private func getDescription(for type: POIType) -> String {
        switch type {
        case .supermarket:
            return "一座废弃的商店，货架凌乱，但可能还有未被发现的食物和日用品。"
        case .hospital:
            return "医院的废墟，空荡的走廊里回荡着风声，可能残留珍贵的医疗物资。"
        case .pharmacy:
            return "药店的残骸，玻璃柜台破碎，但药品储藏区可能有惊喜。"
        case .gasStation:
            return "荒废的加油站，油泵锈迹斑斑，便利店区域值得搜索。"
        case .school:
            return "废弃的学校，教室里落满灰尘，物资可能藏在办公区域。"
        case .warehouse:
            return "一座仓库建筑的废墟，货物散落一地，值得仔细搜索。"
        case .factory:
            return "工厂废墟，机器停转已久，但可能有工具和材料留存。"
        }
    }

    // MARK: - Search Methods

    /// 搜索指定位置附近的POI
    /// - Parameters:
    ///   - center: 搜索中心点
    ///   - radius: 搜索半径（默认1000米）
    ///   - maxCount: 最大返回数量（默认使用maxPOICount，可根据玩家密度动态调整）
    /// - Returns: 游戏POI列表
    func searchNearbyPOIs(center: CLLocationCoordinate2D, radius: CLLocationDistance? = nil, maxCount: Int? = nil) async -> [POI] {
        let searchRadius = radius ?? self.searchRadius
        let limitCount = maxCount ?? self.maxPOICount

        print("🔍 [POI搜索] 开始搜索附近POI，中心: (\(center.latitude), \(center.longitude))，半径: \(searchRadius)m，最大数量: \(limitCount)")

        // 搜索多种类型的POI
        let categoriesToSearch: [MKPointOfInterestCategory] = [
            .hospital,
            .pharmacy,
            .gasStation,
            .store,
            .foodMarket,
            .school
        ]

        var allPOIs: [POI] = []

        // 并行搜索所有类型
        await withTaskGroup(of: [POI].self) { group in
            for category in categoriesToSearch {
                group.addTask {
                    await self.searchPOIs(center: center, radius: searchRadius, category: category)
                }
            }

            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        // 去重（基于坐标）
        var uniquePOIs: [POI] = []
        var seenCoordinates: Set<String> = []

        for poi in allPOIs {
            let key = "\(poi.coordinate.latitude.rounded(toPlaces: 5)),\(poi.coordinate.longitude.rounded(toPlaces: 5))"
            if !seenCoordinates.contains(key) {
                seenCoordinates.insert(key)
                uniquePOIs.append(poi)
            }
        }

        // 按距离排序
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        uniquePOIs.sort { poi1, poi2 in
            let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
            let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
            return centerLocation.distance(from: loc1) < centerLocation.distance(from: loc2)
        }

        // 限制数量（优先取最近的POI，根据玩家密度动态调整）
        let limitedPOIs = Array(uniquePOIs.prefix(limitCount))

        print("✅ [POI搜索] 搜索完成，找到 \(limitedPOIs.count) 个POI（已按距离从近到远排序）")
        print("📍 [POI搜索] 玩家位置: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))")

        // 输出每个POI的详细信息，便于调试位置偏移问题
        for (index, poi) in limitedPOIs.enumerated() {
            print("   \(index + 1). \(poi.name)")
            print("      坐标: (\(String(format: "%.6f", poi.coordinate.latitude)), \(String(format: "%.6f", poi.coordinate.longitude)))")
            print("      距离: \(String(format: "%.0f", poi.distance))m")
        }

        return limitedPOIs
    }

    /// 搜索单一类型的POI
    private func searchPOIs(center: CLLocationCoordinate2D, radius: CLLocationDistance, category: MKPointOfInterestCategory) async -> [POI] {
        let request = MKLocalSearch.Request()

        // 设置搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        request.region = region

        // 设置POI类型过滤
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

            let pois = response.mapItems.compactMap { mapItem -> POI? in
                guard let name = mapItem.name else { return nil }

                let coordinate = mapItem.placemark.coordinate
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = centerLocation.distance(from: location)

                // 只保留在搜索半径内的POI
                guard distance <= radius else { return nil }

                // 映射为游戏POI类型
                let poiType = mapToGamePOIType(category: category) ?? .warehouse

                return POI(
                    name: getApocalypticName(for: poiType, originalName: name),
                    type: poiType,
                    coordinate: coordinate,
                    status: .undiscovered,
                    distance: distance,
                    description: getDescription(for: poiType)
                )
            }

            print("📍 [POI搜索] 类型 \(category.rawValue) 找到 \(pois.count) 个POI")
            return pois

        } catch {
            print("❌ [POI搜索] 搜索失败 (\(category.rawValue)): \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Double Extension

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
