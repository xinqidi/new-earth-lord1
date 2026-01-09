//
//  MockExplorationData.swift
//  new earth lord1
//
//  探索模块测试假数据
//  包含POI、背包物品、物品定义、探索结果等模拟数据
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

// MARK: - 物品数据模型

/// 物品分类
enum ItemCategory: String {
    case water = "水类"
    case food = "食物"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"
}

/// 物品品质（部分物品有品质）
enum ItemQuality: String {
    case poor = "破损"
    case normal = "普通"
    case good = "良好"
    case excellent = "优秀"
}

/// 稀有度
enum ItemRarity: String {
    case common = "常见"
    case uncommon = "罕见"
    case rare = "稀有"
    case epic = "史诗"
}

/// 物品定义（物品的静态属性）
struct ItemDefinition: Identifiable {
    let id: String // 物品ID（如 "water_bottle"）
    let name: String // 中文名
    let category: ItemCategory
    let weight: Double // 重量（千克）
    let volume: Double // 体积（升）
    let rarity: ItemRarity
    let canStack: Bool // 是否可堆叠
    let maxStack: Int // 最大堆叠数
    let hasQuality: Bool // 是否有品质
    let description: String
}

/// 背包物品实例
struct BackpackItem: Identifiable {
    let id: UUID
    let itemId: String // 对应 ItemDefinition 的 id
    var quantity: Int
    var quality: ItemQuality? // 有品质的物品才有此字段

    init(id: UUID = UUID(), itemId: String, quantity: Int, quality: ItemQuality? = nil) {
        self.id = id
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality
    }
}

// MARK: - 探索结果数据模型

/// 探索统计
struct ExplorationStats {
    // 本次探索
    let distanceThisSession: Double // 行走距离（米）
    let areaThisSession: Double // 探索面积（平方米）
    let durationMinutes: Int // 探索时长（分钟）
    let itemsFound: [String: Int] // 获得物品 [物品ID: 数量]

    // 累计统计
    let totalDistance: Double // 累计行走距离（米）
    let totalArea: Double // 累计探索面积（平方米）
    let distanceRank: Int // 距离排名
    let areaRank: Int // 面积排名
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

    // MARK: - 物品定义表

    /// 所有物品的定义（静态数据）
    static let itemDefinitions: [String: ItemDefinition] = [
        // 水类
        "water_bottle": ItemDefinition(
            id: "water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            canStack: true,
            maxStack: 10,
            hasQuality: false,
            description: "一瓶500ml的瓶装矿泉水，生存的必需品。"
        ),

        // 食物类
        "canned_food": ItemDefinition(
            id: "canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            canStack: true,
            maxStack: 20,
            hasQuality: false,
            description: "密封的罐头食品，保质期长，是理想的储备食物。"
        ),

        "instant_noodles": ItemDefinition(
            id: "instant_noodles",
            name: "方便面",
            category: .food,
            weight: 0.15,
            volume: 0.2,
            rarity: .common,
            canStack: true,
            maxStack: 30,
            hasQuality: false,
            description: "一包方便面，需要热水泡制。"
        ),

        // 医疗类
        "bandage": ItemDefinition(
            id: "bandage",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.05,
            rarity: .common,
            canStack: true,
            maxStack: 50,
            hasQuality: true,
            description: "用于包扎伤口的医用绷带。"
        ),

        "medicine": ItemDefinition(
            id: "medicine",
            name: "药品",
            category: .medical,
            weight: 0.1,
            volume: 0.08,
            rarity: .uncommon,
            canStack: true,
            maxStack: 30,
            hasQuality: true,
            description: "常用药品，可治疗轻微疾病。"
        ),

        "antibiotic": ItemDefinition(
            id: "antibiotic",
            name: "抗生素",
            category: .medical,
            weight: 0.08,
            volume: 0.06,
            rarity: .rare,
            canStack: true,
            maxStack: 20,
            hasQuality: true,
            description: "稀有的抗生素药物，可治疗感染。"
        ),

        // 材料类
        "wood": ItemDefinition(
            id: "wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 5.0,
            rarity: .common,
            canStack: true,
            maxStack: 10,
            hasQuality: true,
            description: "可用于建造和修理的木材。"
        ),

        "scrap_metal": ItemDefinition(
            id: "scrap_metal",
            name: "废金属",
            category: .material,
            weight: 3.0,
            volume: 2.0,
            rarity: .common,
            canStack: true,
            maxStack: 10,
            hasQuality: true,
            description: "各种废弃金属，可用于制作工具或加固建筑。"
        ),

        "cloth": ItemDefinition(
            id: "cloth",
            name: "布料",
            category: .material,
            weight: 0.3,
            volume: 1.0,
            rarity: .common,
            canStack: true,
            maxStack: 20,
            hasQuality: true,
            description: "可用于制作衣物或绷带的布料。"
        ),

        // 工具类
        "flashlight": ItemDefinition(
            id: "flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.5,
            rarity: .uncommon,
            canStack: false,
            maxStack: 1,
            hasQuality: true,
            description: "一支便携式手电筒，夜间探索的必备工具。"
        ),

        "rope": ItemDefinition(
            id: "rope",
            name: "绳子",
            category: .tool,
            weight: 0.8,
            volume: 1.5,
            rarity: .common,
            canStack: true,
            maxStack: 5,
            hasQuality: true,
            description: "一捆结实的绳子，用途广泛。"
        ),

        "backpack": ItemDefinition(
            id: "backpack",
            name: "背包",
            category: .tool,
            weight: 0.5,
            volume: 2.0,
            rarity: .uncommon,
            canStack: false,
            maxStack: 1,
            hasQuality: true,
            description: "可以增加携带容量的背包。"
        )
    ]

    // MARK: - 背包物品假数据

    /// 背包中的物品实例（8种不同类型的物品）
    static let mockBackpackItems: [BackpackItem] = [
        // 水类
        BackpackItem(itemId: "water_bottle", quantity: 5),

        // 食物类
        BackpackItem(itemId: "canned_food", quantity: 8),
        BackpackItem(itemId: "instant_noodles", quantity: 3),

        // 医疗类
        BackpackItem(itemId: "bandage", quantity: 12, quality: .normal),
        BackpackItem(itemId: "medicine", quantity: 6, quality: .good),
        BackpackItem(itemId: "antibiotic", quantity: 2, quality: .excellent),

        // 材料类
        BackpackItem(itemId: "wood", quantity: 7, quality: .normal),
        BackpackItem(itemId: "scrap_metal", quantity: 4, quality: .poor),
        BackpackItem(itemId: "cloth", quantity: 10, quality: .normal),

        // 工具类
        BackpackItem(itemId: "flashlight", quantity: 1, quality: .good),
        BackpackItem(itemId: "rope", quantity: 2, quality: .normal)
    ]

    // MARK: - 探索结果示例

    /// 探索结果示例数据
    static let mockExplorationStats = ExplorationStats(
        // 本次探索
        distanceThisSession: 2500,      // 本次行走2500米
        areaThisSession: 50000,         // 本次探索5万平方米
        durationMinutes: 30,            // 探索时长30分钟
        itemsFound: [                   // 获得物品
            "wood": 5,                  // 木材 x5
            "water_bottle": 3,          // 矿泉水 x3
            "canned_food": 2,           // 罐头 x2
            "bandage": 4,               // 绷带 x4
            "scrap_metal": 1            // 废金属 x1
        ],

        // 累计统计
        totalDistance: 15000,           // 累计行走15000米
        totalArea: 250000,              // 累计探索25万平方米
        distanceRank: 42,               // 距离排名第42
        areaRank: 38                    // 面积排名第38
    )

    // MARK: - 辅助方法

    /// 根据物品ID获取物品定义
    static func getItemDefinition(for itemId: String) -> ItemDefinition? {
        return itemDefinitions[itemId]
    }

    /// 计算背包总重量
    static func calculateTotalWeight(items: [BackpackItem]) -> Double {
        var totalWeight: Double = 0
        for item in items {
            if let definition = getItemDefinition(for: item.itemId) {
                totalWeight += definition.weight * Double(item.quantity)
            }
        }
        return totalWeight
    }

    /// 计算背包总体积
    static func calculateTotalVolume(items: [BackpackItem]) -> Double {
        var totalVolume: Double = 0
        for item in items {
            if let definition = getItemDefinition(for: item.itemId) {
                totalVolume += definition.volume * Double(item.quantity)
            }
        }
        return totalVolume
    }

    /// 按分类筛选物品
    static func filterItemsByCategory(items: [BackpackItem], category: ItemCategory) -> [BackpackItem] {
        return items.filter { item in
            if let definition = getItemDefinition(for: item.itemId) {
                return definition.category == category
            }
            return false
        }
    }

    /// 获取背包中某个物品的数量
    static func getItemQuantity(items: [BackpackItem], itemId: String) -> Int {
        if let item = items.first(where: { $0.itemId == itemId }) {
            return item.quantity
        }
        return 0
    }
}
