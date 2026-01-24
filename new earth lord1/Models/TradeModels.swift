//
//  TradeModels.swift
//  new earth lord1
//
//  交易系统数据模型
//  包含交易挂单、交易历史、交易物品等定义
//

import Foundation

// MARK: - TradeOfferStatus

/// 交易挂单状态枚举
enum TradeOfferStatus: String, Codable, CaseIterable {
    case active = "active"           // 活跃（可交易）
    case completed = "completed"     // 已完成
    case cancelled = "cancelled"     // 已取消
    case expired = "expired"         // 已过期

    /// 显示名称
    var displayName: String {
        switch self {
        case .active: return "可交易"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired: return "已过期"
        }
    }
}

// MARK: - TradeItem

/// 交易物品
struct TradeItem: Codable, Equatable, Hashable {
    let itemId: String      // 物品ID（如 "wood", "stone"）
    let quantity: Int       // 数量

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }

    /// 用于JSON编码（发送到数据库）
    func toDictionary() -> [String: Any] {
        return [
            "item_id": itemId,
            "quantity": quantity
        ]
    }
}

// MARK: - TradeOffer

/// 交易挂单结构体
struct TradeOffer: Codable, Identifiable {
    let id: UUID
    let ownerId: UUID               // 发布者ID
    let ownerUsername: String       // 发布者用户名
    let offeringItems: [TradeItem]  // 出售的物品列表
    let requestingItems: [TradeItem] // 需要的物品列表
    let status: TradeOfferStatus
    let message: String?            // 留言（可选）
    let createdAt: Date
    let expiresAt: Date?            // 过期时间（可选）
    let completedAt: Date?          // 完成时间
    let completedByUserId: UUID?    // 接受者ID
    let completedByUsername: String? // 接受者用户名

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }

    /// 是否已过期
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt <= Date()
    }

    /// 是否为活跃状态且未过期
    var isActive: Bool {
        return status == .active && !isExpired
    }

    /// 格式化创建时间
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }

    /// 剩余有效时间（秒）
    var remainingTime: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        let remaining = expiresAt.timeIntervalSince(Date())
        return remaining > 0 ? remaining : 0
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        guard let remaining = remainingTime else { return "永久" }
        if remaining <= 0 { return "已过期" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - TradeExchangeInfo

/// 交易交换信息（用于历史记录的JSON字段）
struct TradeExchangeInfo: Codable {
    let sellerGave: [TradeItem]     // 卖家提供的物品
    let buyerGave: [TradeItem]      // 买家提供的物品

    enum CodingKeys: String, CodingKey {
        case sellerGave = "seller_gave"
        case buyerGave = "buyer_gave"
    }
}

// MARK: - TradeHistory

/// 交易历史记录
struct TradeHistory: Codable, Identifiable {
    let id: UUID
    let offerId: UUID               // 关联的挂单ID
    let sellerId: UUID              // 卖家ID
    let sellerUsername: String      // 卖家用户名
    let buyerId: UUID               // 买家ID
    let buyerUsername: String       // 买家用户名
    let itemsExchanged: TradeExchangeInfo  // 交换详情
    let completedAt: Date           // 完成时间
    var sellerRating: Int?          // 卖家对买家的评分(1-5)
    var buyerRating: Int?           // 买家对卖家的评分(1-5)
    var sellerComment: String?      // 卖家评语
    var buyerComment: String?       // 买家评语

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
        case completedAt = "completed_at"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }

    /// 格式化完成时间
    var formattedCompletedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: completedAt)
    }
}

// MARK: - TradeError

/// 交易系统错误枚举
enum TradeError: LocalizedError {
    case notConfigured                      // 未配置
    case insufficientItems([String: Int])   // 物品不足
    case offerNotFound                      // 挂单不存在
    case offerNotActive                     // 挂单非活跃状态
    case offerExpired                       // 挂单已过期
    case cannotAcceptOwnOffer               // 不能接受自己的挂单
    case invalidQuantity                    // 无效数量
    case databaseError(Error)               // 数据库错误
    case rpcError(String)                   // RPC调用错误
    case inventoryError(Error)              // 库存操作错误
    case historyNotFound                    // 历史记录不存在
    case alreadyRated                       // 已评价过
    case invalidRating                      // 无效评分

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "交易系统未配置"
        case .insufficientItems(let missing):
            let itemList = missing.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return "物品不足，还需要: \(itemList)"
        case .offerNotFound:
            return "交易挂单不存在"
        case .offerNotActive:
            return "交易挂单已不可用"
        case .offerExpired:
            return "交易挂单已过期"
        case .cannotAcceptOwnOffer:
            return "不能接受自己的挂单"
        case .invalidQuantity:
            return "物品数量无效"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        case .rpcError(let message):
            return "交易失败: \(message)"
        case .inventoryError(let error):
            return "库存操作失败: \(error.localizedDescription)"
        case .historyNotFound:
            return "交易记录不存在"
        case .alreadyRated:
            return "已经评价过了"
        case .invalidRating:
            return "评分必须在1-5之间"
        }
    }
}

// MARK: - Database Insert/Update Models

/// 用于创建新挂单的结构体（RPC参数）
struct NewTradeOfferParams: Encodable {
    let owner_username: String
    let offering_items: [[String: Any]]
    let requesting_items: [[String: Any]]
    let message: String?
    let expires_in_hours: Int?

    enum CodingKeys: String, CodingKey {
        case owner_username
        case offering_items
        case requesting_items
        case message
        case expires_in_hours
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(owner_username, forKey: .owner_username)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(expires_in_hours, forKey: .expires_in_hours)
        // JSON arrays need special handling
    }
}

/// 用于更新挂单状态的结构体
struct TradeOfferStatusUpdate: Encodable {
    let status: String
    let updated_at: Date

    init(status: TradeOfferStatus) {
        self.status = status.rawValue
        self.updated_at = Date()
    }
}

/// 用于添加评价的结构体
struct TradeRatingUpdate: Encodable {
    let seller_rating: Int?
    let buyer_rating: Int?
    let seller_comment: String?
    let buyer_comment: String?
}

// MARK: - RPC Response Models

/// 创建挂单RPC响应
struct CreateTradeOfferResponse: Codable {
    let success: Bool
    let offerId: UUID?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case offerId = "offer_id"
        case error
    }
}

/// 接受交易RPC响应
struct AcceptTradeOfferResponse: Codable {
    let success: Bool
    let historyId: UUID?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case historyId = "history_id"
        case error
    }
}

/// 取消挂单RPC响应
struct CancelTradeOfferResponse: Codable {
    let success: Bool
    let error: String?
}

/// 处理过期挂单RPC响应
struct ProcessExpiredOffersResponse: Codable {
    let processedCount: Int

    enum CodingKeys: String, CodingKey {
        case processedCount = "processed_count"
    }
}

// MARK: - PendingItem

/// 待领取物品
struct PendingItem: Codable, Identifiable {
    let id: UUID
    let itemId: String              // 物品ID
    let quantity: Int               // 数量
    let sourceType: String          // 来源类型（trade/gift/reward）
    let sourceDescription: String?  // 来源描述
    let createdAt: Date             // 创建时间

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case quantity
        case sourceType = "source_type"
        case sourceDescription = "source_description"
        case createdAt = "created_at"
    }

    /// 格式化创建时间
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }

    /// 来源类型显示名称
    var sourceTypeDisplayName: String {
        switch sourceType {
        case "trade": return "交易"
        case "gift": return "赠送"
        case "reward": return "奖励"
        default: return sourceType
        }
    }
}

/// 获取待领取物品RPC响应
struct GetPendingItemsResponse: Codable {
    let success: Bool
    let items: [PendingItem]?
    let error: String?
}

/// 领取单个物品RPC响应
struct ClaimPendingItemResponse: Codable {
    let success: Bool
    let itemId: String?
    let quantity: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case itemId = "item_id"
        case quantity
        case error
    }
}

/// 批量领取物品RPC响应
struct ClaimAllPendingItemsResponse: Codable {
    let success: Bool
    let items: [TradeItem]?
    let claimedCount: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case items
        case claimedCount = "claimed_count"
        case error
    }
}
