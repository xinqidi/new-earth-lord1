//
//  MockExplorationData.swift
//  new earth lord1
//
//  探索模块数据模型
//  包含POI（兴趣点）相关的数据结构和测试数据
//
//  注意：物品定义和背包数据已迁移至数据库，使用以下Manager加载：
//  - ExplorationManager: 探索功能、物品定义（DBItemDefinition）
//  - InventoryManager: 背包物品（InventoryDisplayItem）
//

import Foundation
import CoreLocation

// MARK: - POI（兴趣点）数据模型

/// POI状态
enum POIStatus {
    case undiscovered   // 未发现
    case discovered     // 已发现，有物资
    case looted         // 已发现，已被搜空
}

/// POI类型
enum POIType: String {
    case supermarket = "废弃超市"
    case hospital = "医院废墟"
    case gasStation = "加油站"
    case pharmacy = "药店废墟"
    case factory = "工厂废墟"
    case warehouse = "仓库"
    case school = "废弃学校"
}

/// POI兴趣点
struct POI: Identifiable {
    let id: UUID
    let name: String
    let type: POIType
    let coordinate: CLLocationCoordinate2D
    var status: POIStatus
    let distance: Double // 距离用户的距离（米）
    let description: String

    init(id: UUID = UUID(), name: String, type: POIType, coordinate: CLLocationCoordinate2D, status: POIStatus, distance: Double, description: String) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.status = status
        self.distance = distance
        self.description = description
    }
}

// MARK: - Mock数据

class MockExplorationData {

    // MARK: - POI假数据列表

    /// 5个不同状态的兴趣点
    static let mockPOIs: [POI] = [
        // 1. 废弃超市：已发现，有物资
        POI(
            name: "华联超市废墟",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), // 北京天安门附近
            status: .discovered,
            distance: 250,
            description: "一座废弃的大型超市，货架倒塌，但仍可能残留罐头食品和瓶装水。"
        ),

        // 2. 医院废墟：已发现，已被搜空
        POI(
            name: "人民医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 39.9052, longitude: 116.4084),
            status: .looted,
            distance: 580,
            description: "一座已经被废弃的医院，看起来已经被其他幸存者搜刮过了。"
        ),

        // 3. 加油站：未发现
        POI(
            name: "中石化加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 39.9032, longitude: 116.4064),
            status: .undiscovered,
            distance: 1200,
            description: "一座荒废的加油站，可能还有未被发现的物资。"
        ),

        // 4. 药店废墟：已发现，有物资
        POI(
            name: "百草堂药店",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 39.9062, longitude: 116.4094),
            status: .discovered,
            distance: 320,
            description: "一家小型药店的废墟，可能残留一些常用药品和医疗用品。"
        ),

        // 5. 工厂废墟：未发现
        POI(
            name: "重工机械厂",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 39.9022, longitude: 116.4054),
            status: .undiscovered,
            distance: 1850,
            description: "一座大型机械工厂的废墟，可能有金属材料和工具。"
        )
    ]
}
