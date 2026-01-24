//
//  TradeManager.swift
//  new earth lord1
//
//  交易管理器
//  负责交易挂单创建、接受、取消和历史记录管理
//

import Foundation
import Supabase
import Combine

/// 交易管理器（单例）
class TradeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TradeManager()

    // MARK: - Published Properties

    /// 市场挂单列表（其他玩家的活跃挂单）
    @Published var marketOffers: [TradeOffer] = []

    /// 我的挂单列表
    @Published var myOffers: [TradeOffer] = []

    /// 交易历史
    @Published var tradeHistory: [TradeHistory] = []

    /// 待领取物品列表
    @Published var pendingItems: [PendingItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient?

    /// 当前用户 ID
    private var userId: UUID?

    /// 当前用户名
    private var username: String = ""

    /// 背包管理器引用
    private var inventoryManager: InventoryManager?

    /// 过期检测定时器
    private var expirationCheckTimer: Timer?

    /// 是否已配置
    private var isConfigured: Bool = false

    // MARK: - Initialization

    private init() {
        print("💰 [交易] TradeManager 初始化完成")
    }

    // MARK: - Configuration

    /// 配置交易管理器
    func configure(supabase: SupabaseClient, userId: UUID, username: String, inventoryManager: InventoryManager) {
        self.supabase = supabase
        self.userId = userId
        self.username = username
        self.inventoryManager = inventoryManager
        self.isConfigured = true

        print("💰 [交易] 配置完成，用户ID: \(userId)，用户名: \(username)")

        // 启动过期检测
        startExpirationCheck()
    }

    // MARK: - Validation Methods

    /// 检查是否可以创建挂单（验证物品数量）
    func canCreateOffer(offeringItems: [TradeItem]) -> (canCreate: Bool, error: TradeError?) {
        guard let inventoryManager = inventoryManager else {
            return (false, .notConfigured)
        }

        // 检查所有物品数量是否足够
        var missingItems: [String: Int] = [:]
        for item in offeringItems {
            guard item.quantity > 0 else {
                return (false, .invalidQuantity)
            }

            let available = inventoryManager.items.first { $0.itemId == item.itemId }?.quantity ?? 0
            if available < item.quantity {
                missingItems[item.itemId] = item.quantity - available
            }
        }

        if !missingItems.isEmpty {
            return (false, .insufficientItems(missingItems))
        }

        return (true, nil)
    }

    /// 检查是否可以接受挂单（验证物品数量和状态）
    func canAcceptOffer(_ offer: TradeOffer) -> (canAccept: Bool, error: TradeError?) {
        guard let inventoryManager = inventoryManager, let userId = userId else {
            return (false, .notConfigured)
        }

        // 不能接受自己的挂单
        if offer.ownerId == userId {
            return (false, .cannotAcceptOwnOffer)
        }

        // 检查挂单状态
        if offer.status != .active {
            return (false, .offerNotActive)
        }

        // 检查是否过期
        if offer.isExpired {
            return (false, .offerExpired)
        }

        // 检查请求的物品数量是否足够
        var missingItems: [String: Int] = [:]
        for item in offer.requestingItems {
            let available = inventoryManager.items.first { $0.itemId == item.itemId }?.quantity ?? 0
            if available < item.quantity {
                missingItems[item.itemId] = item.quantity - available
            }
        }

        if !missingItems.isEmpty {
            return (false, .insufficientItems(missingItems))
        }

        return (true, nil)
    }

    // MARK: - Create Offer

    /// 创建交易挂单
    /// - Parameters:
    ///   - offeringItems: 出售的物品列表
    ///   - requestingItems: 需要的物品列表
    ///   - message: 留言（可选）
    ///   - expiresInHours: 过期时间（小时，可选，nil表示永不过期）
    /// - Returns: 创建的挂单
    func createOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        message: String? = nil,
        expiresInHours: Int? = 24
    ) async throws -> TradeOffer {
        guard let supabase = supabase, let userId = userId, let inventoryManager = inventoryManager else {
            throw TradeError.notConfigured
        }

        // 验证可以创建
        let (canCreate, error) = canCreateOffer(offeringItems: offeringItems)
        if !canCreate {
            throw error ?? TradeError.insufficientItems([:])
        }

        print("💰 [交易] 开始创建挂单...")

        // 1. 先从库存扣除物品（锁定）
        for item in offeringItems {
            try await inventoryManager.removeItem(itemId: item.itemId, quantity: item.quantity)
            print("   - 锁定 \(item.itemId) x\(item.quantity)")
        }

        // 2. 调用RPC创建挂单
        do {
            // 准备物品JSON数组
            let offeringItemsJson: [AnyJSON] = offeringItems.map { item in
                AnyJSON.object([
                    "item_id": AnyJSON.string(item.itemId),
                    "quantity": AnyJSON.integer(item.quantity)
                ])
            }
            let requestingItemsJson: [AnyJSON] = requestingItems.map { item in
                AnyJSON.object([
                    "item_id": AnyJSON.string(item.itemId),
                    "quantity": AnyJSON.integer(item.quantity)
                ])
            }

            var params: [String: AnyJSON] = [
                "p_owner_username": AnyJSON.string(username),
                "p_offering_items": AnyJSON.array(offeringItemsJson),
                "p_requesting_items": AnyJSON.array(requestingItemsJson)
            ]

            if let message = message {
                params["p_message"] = AnyJSON.string(message)
            } else {
                params["p_message"] = AnyJSON.null
            }

            if let hours = expiresInHours {
                params["p_expires_in_hours"] = AnyJSON.integer(hours)
            } else {
                params["p_expires_in_hours"] = AnyJSON.null
            }

            let response: CreateTradeOfferResponse = try await supabase.rpc(
                "create_trade_offer",
                params: params
            ).execute().value

            if response.success, let offerId = response.offerId {
                // 获取创建的挂单
                let offer: TradeOffer = try await supabase
                    .from("trade_offers")
                    .select()
                    .eq("id", value: offerId.uuidString)
                    .single()
                    .execute()
                    .value

                await MainActor.run {
                    self.myOffers.insert(offer, at: 0)
                }

                print("💰 [交易] ✅ 挂单创建成功: \(offerId)")

                // 发送通知
                NotificationCenter.default.post(name: .tradeOfferCreated, object: offer)

                return offer
            } else {
                // 创建失败，需要退还物品
                print("❌ [交易] 创建挂单失败: \(response.error ?? "未知错误")")
                for item in offeringItems {
                    try await inventoryManager.addItem(itemId: item.itemId, quantity: item.quantity)
                    print("   - 退还 \(item.itemId) x\(item.quantity)")
                }
                throw TradeError.rpcError(response.error ?? "创建挂单失败")
            }
        } catch let error as TradeError {
            throw error
        } catch {
            // 发生错误，退还物品
            print("❌ [交易] 创建挂单异常: \(error.localizedDescription)")
            for item in offeringItems {
                try? await inventoryManager.addItem(itemId: item.itemId, quantity: item.quantity)
            }
            throw TradeError.databaseError(error)
        }
    }

    // MARK: - Accept Offer

    /// 接受交易挂单
    /// - Parameter offer: 要接受的挂单
    /// - Returns: 交易历史记录
    func acceptOffer(_ offer: TradeOffer) async throws -> TradeHistory {
        guard let supabase = supabase, let userId = userId, let inventoryManager = inventoryManager else {
            throw TradeError.notConfigured
        }

        // 验证可以接受
        let (canAccept, error) = canAcceptOffer(offer)
        if !canAccept {
            throw error ?? TradeError.offerNotActive
        }

        print("💰 [交易] 开始接受挂单: \(offer.id)")

        // 1. 先从买家库存扣除物品
        for item in offer.requestingItems {
            try await inventoryManager.removeItem(itemId: item.itemId, quantity: item.quantity)
            print("   - 买家支付 \(item.itemId) x\(item.quantity)")
        }

        // 2. 调用RPC完成交易（带行级锁）
        do {
            let response: AcceptTradeOfferResponse = try await supabase.rpc(
                "accept_trade_offer",
                params: [
                    "p_offer_id": AnyJSON.string(offer.id.uuidString),
                    "p_buyer_username": AnyJSON.string(username)
                ]
            ).execute().value

            if response.success, let historyId = response.historyId {
                // 3. 买家获得卖家的物品
                for item in offer.offeringItems {
                    try await inventoryManager.addItem(itemId: item.itemId, quantity: item.quantity)
                    print("   - 买家获得 \(item.itemId) x\(item.quantity)")
                }

                // 获取历史记录
                let history: TradeHistory = try await supabase
                    .from("trade_history")
                    .select()
                    .eq("id", value: historyId.uuidString)
                    .single()
                    .execute()
                    .value

                await MainActor.run {
                    // 从市场列表移除
                    self.marketOffers.removeAll { $0.id == offer.id }
                    // 添加到历史
                    self.tradeHistory.insert(history, at: 0)
                }

                print("💰 [交易] ✅ 交易完成: \(historyId)")

                // 发送通知
                NotificationCenter.default.post(name: .tradeCompleted, object: history)

                return history
            } else {
                // 交易失败，退还买家物品
                print("❌ [交易] 接受挂单失败: \(response.error ?? "未知错误")")
                for item in offer.requestingItems {
                    try await inventoryManager.addItem(itemId: item.itemId, quantity: item.quantity)
                    print("   - 退还买家 \(item.itemId) x\(item.quantity)")
                }
                throw TradeError.rpcError(response.error ?? "接受交易失败")
            }
        } catch let error as TradeError {
            throw error
        } catch {
            // 发生错误，退还买家物品
            print("❌ [交易] 接受挂单异常: \(error.localizedDescription)")
            for item in offer.requestingItems {
                try? await inventoryManager.addItem(itemId: item.itemId, quantity: item.quantity)
            }
            throw TradeError.databaseError(error)
        }
    }

    // MARK: - Cancel Offer

    /// 取消交易挂单
    /// - Parameter offer: 要取消的挂单
    func cancelOffer(_ offer: TradeOffer) async throws {
        guard let supabase = supabase, let userId = userId, let inventoryManager = inventoryManager else {
            throw TradeError.notConfigured
        }

        // 验证是自己的挂单
        guard offer.ownerId == userId else {
            throw TradeError.offerNotFound
        }

        // 验证状态为活跃
        guard offer.status == .active else {
            throw TradeError.offerNotActive
        }

        print("💰 [交易] 开始取消挂单: \(offer.id)")

        // 调用RPC取消挂单
        let response: CancelTradeOfferResponse = try await supabase.rpc(
            "cancel_trade_offer",
            params: [
                "p_offer_id": AnyJSON.string(offer.id.uuidString)
            ]
        ).execute().value

        if response.success {
            // 退还锁定的物品
            for item in offer.offeringItems {
                try await inventoryManager.addItem(itemId: item.itemId, quantity: item.quantity)
                print("   - 退还 \(item.itemId) x\(item.quantity)")
            }

            await MainActor.run {
                // 更新本地状态
                if let index = self.myOffers.firstIndex(where: { $0.id == offer.id }) {
                    self.myOffers.remove(at: index)
                }
            }

            print("💰 [交易] ✅ 挂单已取消: \(offer.id)")

            // 发送通知
            NotificationCenter.default.post(name: .tradeOfferCancelled, object: offer)
        } else {
            throw TradeError.rpcError(response.error ?? "取消挂单失败")
        }
    }

    // MARK: - Fetch Methods

    /// 获取市场挂单列表（其他玩家的活跃挂单）
    func fetchMarketOffers() async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [交易] Supabase或用户ID未配置")
            await MainActor.run {
                self.errorMessage = "请先登录"
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            print("💰 [交易] 开始加载市场挂单...")

            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: "active")
                .neq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            // 过滤掉已过期的
            let activeOffers = offers.filter { !$0.isExpired }

            await MainActor.run {
                self.marketOffers = activeOffers
                self.isLoading = false
            }

            print("💰 [交易] ✅ 市场挂单加载完成，共 \(activeOffers.count) 个")

        } catch {
            print("❌ [交易] 加载市场挂单失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "加载市场挂单失败: \(error.localizedDescription)"
            }
        }
    }

    /// 获取我的挂单列表
    func fetchMyOffers() async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [交易] Supabase或用户ID未配置")
            return
        }

        do {
            print("💰 [交易] 开始加载我的挂单...")

            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.myOffers = offers
            }

            print("💰 [交易] ✅ 我的挂单加载完成，共 \(offers.count) 个")

        } catch {
            print("❌ [交易] 加载我的挂单失败: \(error.localizedDescription)")
        }
    }

    /// 获取交易历史
    func fetchTradeHistory() async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [交易] Supabase或用户ID未配置")
            return
        }

        do {
            print("💰 [交易] 开始加载交易历史...")

            // 查询作为卖家或买家的历史记录
            let history: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
                .order("completed_at", ascending: false)
                .limit(50)
                .execute()
                .value

            await MainActor.run {
                self.tradeHistory = history
            }

            print("💰 [交易] ✅ 交易历史加载完成，共 \(history.count) 条")

        } catch {
            print("❌ [交易] 加载交易历史失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Pending Items

    /// 获取待领取物品列表
    func fetchPendingItems() async {
        guard let supabase = supabase else {
            print("❌ [交易] Supabase未配置")
            return
        }

        do {
            print("💰 [交易] 开始加载待领取物品...")

            let response: GetPendingItemsResponse = try await supabase.rpc(
                "get_pending_items"
            ).execute().value

            if response.success, let items = response.items {
                await MainActor.run {
                    self.pendingItems = items
                }
                print("💰 [交易] ✅ 待领取物品加载完成，共 \(items.count) 个")
            } else {
                print("❌ [交易] 加载待领取物品失败: \(response.error ?? "未知错误")")
            }

        } catch {
            print("❌ [交易] 加载待领取物品失败: \(error.localizedDescription)")
        }
    }

    /// 领取单个待领取物品
    /// - Parameter itemId: 待领取物品ID
    func claimPendingItem(_ itemId: UUID) async throws {
        guard let supabase = supabase, let inventoryManager = inventoryManager else {
            throw TradeError.notConfigured
        }

        print("💰 [交易] 开始领取物品: \(itemId)")

        let response: ClaimPendingItemResponse = try await supabase.rpc(
            "claim_pending_item",
            params: [
                "p_pending_item_id": AnyJSON.string(itemId.uuidString)
            ]
        ).execute().value

        if response.success, let itemIdStr = response.itemId, let quantity = response.quantity {
            // 添加到背包
            try await inventoryManager.addItem(itemId: itemIdStr, quantity: quantity)

            await MainActor.run {
                // 从待领取列表移除
                self.pendingItems.removeAll { $0.id == itemId }
            }

            print("💰 [交易] ✅ 领取成功: \(itemIdStr) x\(quantity)")
        } else {
            throw TradeError.rpcError(response.error ?? "领取失败")
        }
    }

    /// 批量领取所有待领取物品
    func claimAllPendingItems() async throws -> Int {
        guard let supabase = supabase, let inventoryManager = inventoryManager else {
            throw TradeError.notConfigured
        }

        print("💰 [交易] 开始批量领取所有待领取物品...")

        let response: ClaimAllPendingItemsResponse = try await supabase.rpc(
            "claim_all_pending_items"
        ).execute().value

        if response.success, let items = response.items, let claimedCount = response.claimedCount {
            // 添加所有物品到背包
            for item in items {
                try await inventoryManager.addItem(itemId: item.itemId, quantity: item.quantity)
                print("   - 领取 \(item.itemId) x\(item.quantity)")
            }

            await MainActor.run {
                // 清空待领取列表
                self.pendingItems.removeAll()
            }

            print("💰 [交易] ✅ 批量领取完成，共 \(claimedCount) 个物品")
            return claimedCount
        } else {
            throw TradeError.rpcError(response.error ?? "批量领取失败")
        }
    }

    /// 待领取物品数量
    var pendingItemsCount: Int {
        return pendingItems.count
    }

    // MARK: - Rating

    /// 添加评价
    /// - Parameters:
    ///   - historyId: 交易历史ID
    ///   - rating: 评分(1-5)
    ///   - comment: 评语（可选）
    func addRating(historyId: UUID, rating: Int, comment: String? = nil) async throws {
        guard let supabase = supabase, let userId = userId else {
            throw TradeError.notConfigured
        }

        // 验证评分
        guard rating >= 1 && rating <= 5 else {
            throw TradeError.invalidRating
        }

        // 查找历史记录
        guard let index = tradeHistory.firstIndex(where: { $0.id == historyId }) else {
            throw TradeError.historyNotFound
        }

        let history = tradeHistory[index]

        // 判断当前用户是卖家还是买家
        let isSeller = history.sellerId == userId
        let isBuyer = history.buyerId == userId

        guard isSeller || isBuyer else {
            throw TradeError.historyNotFound
        }

        // 检查是否已评价
        if isSeller && history.sellerRating != nil {
            throw TradeError.alreadyRated
        }
        if isBuyer && history.buyerRating != nil {
            throw TradeError.alreadyRated
        }

        print("💰 [交易] 添加评价: \(historyId), 评分: \(rating)")

        // 更新数据库
        if isSeller {
            let update = TradeRatingUpdate(
                seller_rating: rating,
                buyer_rating: nil,
                seller_comment: comment,
                buyer_comment: nil
            )
            try await supabase
                .from("trade_history")
                .update(update)
                .eq("id", value: historyId.uuidString)
                .execute()
        } else {
            let update = TradeRatingUpdate(
                seller_rating: nil,
                buyer_rating: rating,
                seller_comment: nil,
                buyer_comment: comment
            )
            try await supabase
                .from("trade_history")
                .update(update)
                .eq("id", value: historyId.uuidString)
                .execute()
        }

        // 更新本地状态
        await MainActor.run {
            if isSeller {
                self.tradeHistory[index].sellerRating = rating
                self.tradeHistory[index].sellerComment = comment
            } else {
                self.tradeHistory[index].buyerRating = rating
                self.tradeHistory[index].buyerComment = comment
            }
        }

        print("💰 [交易] ✅ 评价添加成功")
    }

    // MARK: - Expiration Check

    /// 启动过期检测定时器
    private func startExpirationCheck() {
        // 停止已有的定时器
        expirationCheckTimer?.invalidate()

        // 每 60 秒检查一次
        expirationCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.processExpiredOffers()
            }
        }

        print("💰 [交易] 过期检测已启动（每60秒）")
    }

    /// 处理过期挂单
    private func processExpiredOffers() async {
        guard let supabase = supabase else { return }

        do {
            let response: ProcessExpiredOffersResponse = try await supabase.rpc(
                "process_expired_offers"
            ).execute().value

            if response.processedCount > 0 {
                print("💰 [交易] 处理了 \(response.processedCount) 个过期挂单")
                // 重新加载我的挂单
                await fetchMyOffers()
            }
        } catch {
            print("❌ [交易] 处理过期挂单失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    /// 刷新所有数据
    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.fetchMarketOffers()
            }
            group.addTask {
                await self.fetchMyOffers()
            }
            group.addTask {
                await self.fetchTradeHistory()
            }
            group.addTask {
                await self.fetchPendingItems()
            }
        }
    }

    /// 获取活跃的我的挂单数量
    var activeMyOffersCount: Int {
        return myOffers.filter { $0.status == .active && !$0.isExpired }.count
    }

    // MARK: - Cleanup

    /// 停止定时器
    func stopExpirationCheck() {
        expirationCheckTimer?.invalidate()
        expirationCheckTimer = nil
        print("💰 [交易] 过期检测已停止")
    }

    deinit {
        stopExpirationCheck()
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// 交易挂单创建通知
    static let tradeOfferCreated = Notification.Name("tradeOfferCreated")

    /// 交易完成通知
    static let tradeCompleted = Notification.Name("tradeCompleted")

    /// 交易挂单取消通知
    static let tradeOfferCancelled = Notification.Name("tradeOfferCancelled")

    /// 有新的待领取物品通知
    static let pendingItemsReceived = Notification.Name("pendingItemsReceived")
}
