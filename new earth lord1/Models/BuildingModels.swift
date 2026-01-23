//
//  BuildingModels.swift
//  new earth lord1
//
//  建筑系统数据模型
//  包含建筑分类、状态、模板和玩家建筑定义
//

import Foundation
import SwiftUI

// MARK: - BuildingCategory

/// 建筑分类枚举
enum BuildingCategory: String, Codable, CaseIterable {
    case all = "all"                 // 全部（仅用于UI筛选）
    case survival = "survival"       // 生存
    case storage = "storage"         // 储存
    case production = "production"   // 生产
    case energy = "energy"           // 能源

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .survival: return "生存"
        case .storage: return "储存"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .survival: return "flame.fill"
        case .storage: return "archivebox.fill"
        case .production: return "hammer.fill"
        case .energy: return "bolt.fill"
        }
    }
}

// MARK: - BuildingStatus

/// 建筑状态枚举
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 运行中

    /// 显示名称
    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "运行中"
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .constructing: return .blue
        case .active: return .green
        }
    }
}

// MARK: - BuildingTemplate

/// 建筑模板结构体（从 JSON 加载）
struct BuildingTemplate: Codable, Identifiable {
    let id: UUID
    let templateId: String           // 如 "campfire"
    let name: String                 // 如 "篝火"
    let category: BuildingCategory
    let tier: Int                    // 等级 1/2/3
    let description: String
    let icon: String
    let requiredResources: [String: Int]  // {"wood": 30, "stone": 20}
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name
        case category
        case tier
        case description
        case icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }
}

// MARK: - PlayerBuilding

/// 玩家建筑结构体（数据库模型）
struct PlayerBuilding: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let territoryId: String          // 与 Territory.id 一致，使用 String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 是否建造完成
    var isConstructionComplete: Bool {
        guard let completedAt = buildCompletedAt else { return false }
        return completedAt <= Date()
    }

    /// 建造剩余时间（秒）
    var remainingBuildTime: TimeInterval? {
        guard status == .constructing, let completedAt = buildCompletedAt else { return nil }
        let remaining = completedAt.timeIntervalSince(Date())
        return remaining > 0 ? remaining : 0
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        guard let remaining = remainingBuildTime else { return "" }
        if remaining <= 0 { return "即将完成" }

        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60

        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }

    /// 建造进度（0.0~1.0）
    var constructionProgress: Double {
        guard status == .constructing,
              let completedAt = buildCompletedAt else { return 1.0 }

        let totalTime = completedAt.timeIntervalSince(buildStartedAt)
        let elapsed = Date().timeIntervalSince(buildStartedAt)

        if totalTime <= 0 { return 1.0 }
        let progress = min(max(elapsed / totalTime, 0.0), 1.0)
        return progress
    }
}

// MARK: - BuildingError

/// 建筑系统错误枚举
enum BuildingError: LocalizedError {
    case insufficientResources([String: Int])  // 缺少的资源
    case maxBuildingsReached(Int)              // 达到上限
    case templateNotFound                       // 模板不存在
    case invalidStatus                          // 状态不对
    case maxLevelReached                        // 已达最高等级
    case databaseError(Error)                   // 数据库错误
    case notConfigured                          // 未配置
    case buildingNotFound                       // 建筑不存在

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let missing):
            let resourceList = missing.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return "资源不足，还需要: \(resourceList)"
        case .maxBuildingsReached(let limit):
            return "该建筑已达上限（最多 \(limit) 个）"
        case .templateNotFound:
            return "建筑模板不存在"
        case .invalidStatus:
            return "建筑状态无效"
        case .maxLevelReached:
            return "建筑已达最高等级"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        case .notConfigured:
            return "建筑管理器未配置"
        case .buildingNotFound:
            return "建筑不存在"
        }
    }
}

// MARK: - Database Insert/Update Models

/// 用于插入新建筑的结构体
struct NewPlayerBuilding: Encodable {
    let user_id: UUID
    let territory_id: String
    let template_id: String
    let building_name: String
    let status: String
    let level: Int
    let location_lat: Double?
    let location_lon: Double?
    let build_started_at: Date
    let build_completed_at: Date?
}

/// 用于更新建筑状态的结构体
struct BuildingStatusUpdate: Encodable {
    let status: String
    let updated_at: Date
}

/// 用于更新建筑等级的结构体
struct BuildingLevelUpdate: Encodable {
    let level: Int
    let updated_at: Date
}
