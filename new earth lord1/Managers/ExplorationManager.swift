//
//  ExplorationManager.swift
//  new earth lord1
//
//  探索管理器
//  负责管理探索状态、GPS追踪、距离计算、速度检测、奖励生成
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 奖励等级
enum RewardTier: String, CaseIterable {
    case none = "none"
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case diamond = "diamond"

    /// 等级显示名称
    var displayName: String {
        switch self {
        case .none: return "无奖励".localized
        case .bronze: return "铜级".localized
        case .silver: return "银级".localized
        case .gold: return "金级".localized
        case .diamond: return "钻石级".localized
        }
    }

    /// 等级图标
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 等级对应的物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 获取等级对应的距离阈值
    static func tier(for distance: Double) -> RewardTier {
        switch distance {
        case 0..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }

    /// 下一等级
    var nextTier: RewardTier? {
        switch self {
        case .none: return .bronze
        case .bronze: return .silver
        case .silver: return .gold
        case .gold: return .diamond
        case .diamond: return nil
        }
    }

    /// 达到此等级的距离阈值
    var distanceThreshold: Double {
        switch self {
        case .none: return 0
        case .bronze: return 200
        case .silver: return 500
        case .gold: return 1000
        case .diamond: return 2000
        }
    }
}

/// 探索结果
struct ExplorationResult: Identifiable {
    let id: UUID
    let distance: Double
    let durationSeconds: Int
    let tier: RewardTier
    let items: [RewardItem]
    let hasFailed: Bool
    let failureReason: String?

    init(distance: Double, durationSeconds: Int, tier: RewardTier, items: [RewardItem], hasFailed: Bool, failureReason: String?) {
        self.id = UUID()
        self.distance = distance
        self.durationSeconds = durationSeconds
        self.tier = tier
        self.items = items
        self.hasFailed = hasFailed
        self.failureReason = failureReason
    }
}

/// 奖励物品
struct RewardItem: Identifiable {
    let id: UUID
    let itemId: String
    let name: String
    let quantity: Int
    let rarity: String
    let icon: String
    let category: String
    let story: String?  // AI生成的物品背景故事

    init(itemId: String, name: String, quantity: Int, rarity: String, icon: String, category: String, story: String? = nil) {
        self.id = UUID()
        self.itemId = itemId
        self.name = name
        self.quantity = quantity
        self.rarity = rarity
        self.icon = icon
        self.category = category
        self.story = story
    }
}

/// 物品定义（数据库模型）
struct DBItemDefinition: Codable {
    let id: String
    let name: String
    let description: String?
    let category: String
    let rarity: String
    let weight: Double?
    let icon: String?
}

/// 探索管理器
class ExplorationManager: ObservableObject {

    // MARK: - Published Properties

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前累计距离（米）
    @Published var currentDistance: Double = 0

    /// 当前时长（秒）
    @Published var currentDuration: Int = 0

    /// 当前奖励等级
    @Published var currentTier: RewardTier = .none

    /// 距离下一等级还差多少米
    @Published var distanceToNextTier: Double = 200

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 超速倒计时（10秒）
    @Published var overspeedCountdown: Int?

    /// 是否正在超速
    @Published var isOverspeed: Bool = false

    /// 物品定义是否已加载
    @Published var itemDefinitionsLoaded: Bool = false

    /// 探索结果（探索结束后设置）
    @Published var explorationResult: ExplorationResult?

    /// 是否显示结果页
    @Published var showResult: Bool = false

    // MARK: - POI相关属性

    /// 附近POI列表
    @Published var nearbyPOIs: [POI] = []

    /// 是否显示POI搜刮弹窗
    @Published var showPOIPopup: Bool = false

    /// 当前接近的POI
    @Published var currentPOI: POI?

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 当前搜刮结果
    @Published var scavengeResult: ScavengeResult?

    // MARK: - Private Properties

    /// Supabase客户端
    private var supabase: SupabaseClient?

    /// 当前用户ID
    private var userId: UUID?

    /// 物品定义缓存
    private var cachedItemDefinitions: [String: DBItemDefinition] = [:]

    /// 全局位置管理器引用
    private weak var locationManager: LocationManager?

    /// 位置更新订阅
    private var locationCancellable: AnyCancellable?

    /// 上一个位置点
    private var lastLocation: CLLocation?

    /// 探索开始时间
    private var startTime: Date?

    /// 探索开始位置
    private var startLocation: CLLocation?

    /// 时长计时器
    private var durationTimer: Timer?

    /// 超速检测定时器
    private var overspeedTimer: Timer?

    /// 超速开始时间
    private var overspeedStartTime: Date?

    /// 当前探索会话ID
    private var currentSessionId: UUID?

    /// 速度阈值（km/h）
    private let speedThreshold: Double = 30.0

    /// 超速超时时间（秒）
    private let overspeedTimeout: Int = 10

    /// 最小有效移动距离（米）- 小于此值的移动视为GPS漂移
    private let minimumMovementDistance: Double = 3.0

    /// 最大GPS精度误差（米）- 超过此值的位置更新将被忽略
    private let maximumAccuracyThreshold: Double = 20.0

    /// 上次有效位置更新时间
    private var lastValidUpdateTime: Date?

    /// 最小位置更新间隔（秒）
    private let minimumUpdateInterval: TimeInterval = 2.0

    /// POI围栏半径（米）
    private let poiGeofenceRadius: CLLocationDistance = 50.0

    /// 围栏通知订阅
    private var geofenceCancellable: AnyCancellable?

    /// 已触发弹窗的POI ID集合（防止重复触发）
    private var triggeredPOIIds: Set<UUID> = []

    // MARK: - Initialization

    init() {
    }

    /// 配置Supabase客户端、用户ID和位置管理器
    func configure(supabase: SupabaseClient, userId: UUID, locationManager: LocationManager) {
        self.supabase = supabase
        self.userId = userId
        self.locationManager = locationManager
    }

    // MARK: - Item Definitions

    /// 加载物品定义
    func loadItemDefinitions() async throws {
        guard let supabase = supabase else {
            print("❌ [探索] Supabase未配置")
            throw NSError(domain: "ExplorationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase未配置"])
        }

        let items: [DBItemDefinition] = try await supabase
            .from("item_definitions")
            .select()
            .execute()
            .value

        // 缓存到字典
        cachedItemDefinitions = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        await MainActor.run {
            self.itemDefinitionsLoaded = true
        }
    }

    /// 获取物品定义
    func getItemDefinition(for itemId: String) -> DBItemDefinition? {
        return cachedItemDefinitions[itemId]
    }

    // MARK: - Exploration Control

    /// 开始探索
    func startExploration() async throws {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [探索] Supabase或用户ID未配置")
            throw NSError(domain: "ExplorationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "请先登录"])
        }

        guard let locationManager = locationManager else {
            print("❌ [探索] LocationManager未配置")
            throw NSError(domain: "ExplorationManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "位置服务未初始化"])
        }

        // 确保物品定义已加载
        if !itemDefinitionsLoaded {
            try await loadItemDefinitions()
        }

        await MainActor.run {
            // 重置状态
            self.currentDistance = 0
            self.currentDuration = 0
            self.currentTier = .none
            self.distanceToNextTier = 200
            self.speedWarning = nil
            self.overspeedCountdown = nil
            self.isOverspeed = false
            self.explorationResult = nil
            self.showResult = false
            self.lastLocation = nil
            self.lastValidUpdateTime = nil
            self.startTime = Date()
            self.startLocation = nil
            self.overspeedStartTime = nil
            self.isExploring = true
        }

        // 创建探索会话记录
        let sessionId = UUID()
        self.currentSessionId = sessionId

        struct ExplorationSessionInsert: Encodable {
            let id: UUID
            let user_id: UUID
            let start_time: Date
            let status: String
        }

        let session = ExplorationSessionInsert(
            id: sessionId,
            user_id: userId,
            start_time: Date(),
            status: "active"
        )

        try await supabase
            .from("exploration_sessions")
            .insert(session)
            .execute()

        // 订阅位置更新（使用全局 LocationManager）
        await MainActor.run {
            // 确保定位已开启
            locationManager.startUpdatingLocation()

            // 订阅位置更新
            self.locationCancellable = locationManager.$currentFullLocation
                .compactMap { $0 }  // 过滤 nil 值
                .sink { [weak self] location in
                    self?.handleLocationUpdate(location)
                }

            print("🔍 [探索] 探索已开始")
            ExplorationLogger.shared.log("探索已开始", type: .success)

            // 启动时长计时器
            self.durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, self.isExploring else { return }
                self.currentDuration += 1
            }
        }

        // 搜索并设置POI
        await searchAndSetupPOIs()
    }

    /// 处理位置更新（从 LocationManager 订阅接收）
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isExploring else {
            // 不在探索状态，忽略
            return
        }

        // 过滤精度差的位置（更严格的过滤）
        guard location.horizontalAccuracy > 0 else {
            return
        }

        guard location.horizontalAccuracy <= maximumAccuracyThreshold else {
            return
        }

        // 更新距离和等级
        updateDistanceAndTier(newLocation: location)

        // 检测速度
        checkSpeed(location: location)

        // 检测POI接近（手动距离检测，作为地理围栏的补充）
        checkPOIProximity(location: location)
    }

    /// 停止探索（正常结束）
    func stopExploration() async {
        guard isExploring else { return }

        await MainActor.run {
            self.isExploring = false
            // 取消位置订阅
            self.locationCancellable?.cancel()
            self.locationCancellable = nil
            self.durationTimer?.invalidate()
            self.durationTimer = nil
            self.overspeedTimer?.invalidate()
            self.overspeedTimer = nil

            // 清理POI
            self.clearPOIs()
        }

        // 计算奖励
        let tier = RewardTier.tier(for: currentDistance)
        let items = await generateRewards(tier: tier)

        print("✅ [探索] 探索完成: 距离 \(String(format: "%.0f", currentDistance))m, 时长 \(currentDuration)s, 等级 \(tier.displayName)")
        ExplorationLogger.shared.log("探索完成: 距离 \(String(format: "%.0f", currentDistance))m, 时长 \(currentDuration)s, 等级 \(tier.displayName)", type: .success)

        // 更新数据库记录
        await updateExplorationSession(
            tier: tier,
            items: items,
            status: "completed"
        )

        // 将物品添加到背包
        await addItemsToInventory(items: items)

        // 设置结果
        let result = ExplorationResult(
            distance: currentDistance,
            durationSeconds: currentDuration,
            tier: tier,
            items: items,
            hasFailed: false,
            failureReason: nil
        )

        await MainActor.run {
            self.explorationResult = result
            self.showResult = true
        }
    }

    /// 探索失败（超速导致）
    private func failExploration(reason: String) async {
        print("🚫 [探索] 探索失败: \(reason)")

        await MainActor.run {
            self.isExploring = false
            // 取消位置订阅
            self.locationCancellable?.cancel()
            self.locationCancellable = nil
            self.durationTimer?.invalidate()
            self.durationTimer = nil
            self.overspeedTimer?.invalidate()
            self.overspeedTimer = nil
            self.speedWarning = nil
            self.overspeedCountdown = nil
            self.isOverspeed = false

            // 清理POI
            self.clearPOIs()
        }

        // 更新数据库记录
        await updateExplorationSession(
            tier: .none,
            items: [],
            status: "failed"
        )

        // 设置失败结果
        let result = ExplorationResult(
            distance: currentDistance,
            durationSeconds: currentDuration,
            tier: .none,
            items: [],
            hasFailed: true,
            failureReason: reason
        )

        await MainActor.run {
            self.explorationResult = result
            self.showResult = true
        }
    }

    // MARK: - Reward Generation

    /// 生成奖励物品
    private func generateRewards(tier: RewardTier) async -> [RewardItem] {
        guard tier != .none else { return [] }

        let itemCount = tier.itemCount
        var rewards: [RewardItem] = []

        // 获取各稀有度的概率
        let (commonProb, rareProb, _) = getProbabilities(for: tier)

        // 按稀有度分类物品
        let commonItems = cachedItemDefinitions.values.filter { $0.rarity == "common" }
        let rareItems = cachedItemDefinitions.values.filter { $0.rarity == "rare" }
        let epicItems = cachedItemDefinitions.values.filter { $0.rarity == "epic" }

        print("🎁 [探索] 生成奖励: \(tier.displayName), \(itemCount)个物品")

        for _ in 0..<itemCount {
            // 随机决定稀有度
            let roll = Double.random(in: 0..<100)
            let selectedRarity: String
            let itemPool: [DBItemDefinition]

            if roll < commonProb {
                selectedRarity = "common"
                itemPool = Array(commonItems)
            } else if roll < commonProb + rareProb {
                selectedRarity = "rare"
                itemPool = Array(rareItems)
            } else {
                selectedRarity = "epic"
                itemPool = Array(epicItems)
            }

            // 从物品池随机选择
            if let item = itemPool.randomElement() {
                let reward = RewardItem(
                    itemId: item.id,
                    name: item.name,
                    quantity: 1,
                    rarity: item.rarity,
                    icon: item.icon ?? "questionmark",
                    category: item.category
                )
                rewards.append(reward)
            }
        }

        return rewards
    }

    /// 获取各稀有度的概率
    private func getProbabilities(for tier: RewardTier) -> (common: Double, rare: Double, epic: Double) {
        switch tier {
        case .none:
            return (0, 0, 0)
        case .bronze:
            return (100, 0, 0)
        case .silver:
            return (80, 20, 0)
        case .gold:
            return (60, 35, 5)
        case .diamond:
            return (40, 45, 15)
        }
    }

    // MARK: - Database Operations

    /// 更新探索会话记录
    private func updateExplorationSession(tier: RewardTier, items: [RewardItem], status: String) async {
        guard let supabase = supabase, let sessionId = currentSessionId else { return }

        struct SessionUpdate: Encodable {
            let end_time: Date
            let duration_seconds: Int
            let total_distance: Double
            let reward_tier: String
            let items_rewarded: [[String: Any]]?
            let status: String
            let end_lat: Double?
            let end_lng: Double?

            enum CodingKeys: String, CodingKey {
                case end_time, duration_seconds, total_distance, reward_tier, status, end_lat, end_lng
                case items_rewarded
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(end_time, forKey: .end_time)
                try container.encode(duration_seconds, forKey: .duration_seconds)
                try container.encode(total_distance, forKey: .total_distance)
                try container.encode(reward_tier, forKey: .reward_tier)
                try container.encode(status, forKey: .status)
                try container.encodeIfPresent(end_lat, forKey: .end_lat)
                try container.encodeIfPresent(end_lng, forKey: .end_lng)
            }
        }

        // 将奖励物品转换为JSON
        let itemsJson = items.map { item -> [String: Any] in
            return [
                "item_id": item.itemId,
                "name": item.name,
                "quantity": item.quantity,
                "rarity": item.rarity
            ]
        }

        do {
            // 使用原始SQL更新，因为JSONB字段处理比较复杂
            let itemsJsonString = try JSONSerialization.data(withJSONObject: itemsJson, options: [])
            let itemsJsonStr = String(data: itemsJsonString, encoding: .utf8) ?? "[]"

            let query = """
                UPDATE exploration_sessions
                SET end_time = now(),
                    duration_seconds = \(currentDuration),
                    total_distance = \(currentDistance),
                    reward_tier = '\(tier.rawValue)',
                    items_rewarded = '\(itemsJsonStr)'::jsonb,
                    status = '\(status)',
                    end_lat = \(lastLocation?.coordinate.latitude ?? 0),
                    end_lng = \(lastLocation?.coordinate.longitude ?? 0)
                WHERE id = '\(sessionId.uuidString)'
            """

            // 由于Supabase Swift SDK对JSONB支持有限，这里使用简化的更新
            struct SimpleUpdate: Encodable {
                let end_time: Date
                let duration_seconds: Int
                let total_distance: Double
                let reward_tier: String
                let status: String
            }

            let update = SimpleUpdate(
                end_time: Date(),
                duration_seconds: currentDuration,
                total_distance: currentDistance,
                reward_tier: tier.rawValue,
                status: status
            )

            try await supabase
                .from("exploration_sessions")
                .update(update)
                .eq("id", value: sessionId.uuidString)
                .execute()
        } catch {
            print("❌ [探索] 更新探索记录失败: \(error.localizedDescription)")
        }
    }

    /// 将物品添加到背包
    private func addItemsToInventory(items: [RewardItem]) async {
        guard let supabase = supabase, let userId = userId else { return }

        for item in items {
            do {
                // ⚠️ 步骤1：确保物品定义存在（AI生成的物品需要动态创建定义）
                struct ItemDefinition: Codable {
                    let id: String
                }

                let existingDefinitions: [ItemDefinition] = try await supabase
                    .from("item_definitions")
                    .select("id")
                    .eq("id", value: item.itemId)
                    .execute()
                    .value

                if existingDefinitions.isEmpty {
                    // 物品定义不存在，创建新定义
                    struct NewItemDefinition: Encodable {
                        let id: String
                        let name: String
                        let category: String
                        let rarity: String
                        let icon: String
                        let description: String?
                        let weight: Int
                    }

                    try await supabase
                        .from("item_definitions")
                        .insert(NewItemDefinition(
                            id: item.itemId,
                            name: item.name,
                            category: item.category,
                            rarity: item.rarity,
                            icon: item.icon,
                            description: item.story, // 物品故事作为描述
                            weight: 1
                        ))
                        .execute()

                    print("✅ [背包] 创建物品定义: \(item.name) [\(item.itemId)]")
                }

                // ⚠️ 步骤2：添加或更新背包物品
                struct InventoryItem: Codable {
                    let id: UUID
                    let user_id: UUID
                    let item_id: String
                    let quantity: Int
                }

                let existingItems: [InventoryItem] = try await supabase
                    .from("inventory_items")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .eq("item_id", value: item.itemId)
                    .execute()
                    .value

                if let existing = existingItems.first {
                    // 更新数量
                    struct QuantityUpdate: Encodable {
                        let quantity: Int
                    }

                    try await supabase
                        .from("inventory_items")
                        .update(QuantityUpdate(quantity: existing.quantity + item.quantity))
                        .eq("id", value: existing.id.uuidString)
                        .execute()

                    print("✅ [背包] 更新物品数量: \(item.name) +\(item.quantity)")
                } else {
                    // 新增物品
                    struct NewInventoryItem: Encodable {
                        let user_id: UUID
                        let item_id: String
                        let quantity: Int
                    }

                    try await supabase
                        .from("inventory_items")
                        .insert(NewInventoryItem(
                            user_id: userId,
                            item_id: item.itemId,
                            quantity: item.quantity
                        ))
                        .execute()

                    print("✅ [背包] 添加新物品: \(item.name) x\(item.quantity)")
                }
            } catch {
                print("❌ [背包] 添加物品失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Distance Calculation

    /// 使用 Haversine 公式计算两点间距离
    private func haversineDistance(from: CLLocation, to: CLLocation) -> Double {
        return from.distance(from: to)
    }

    /// 更新距离和等级
    private func updateDistanceAndTier(newLocation: CLLocation) {
        let now = Date()

        // 第一次位置更新
        guard let lastLoc = lastLocation else {
            lastLocation = newLocation
            lastValidUpdateTime = now
            if startLocation == nil {
                startLocation = newLocation
            }
            return
        }

        // 检查时间间隔（防止过于频繁的更新）
        if let lastUpdate = lastValidUpdateTime {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < minimumUpdateInterval {
                // 更新太频繁，跳过
                return
            }
        }

        // 计算距离
        let distance = haversineDistance(from: lastLoc, to: newLocation)

        // 过滤GPS漂移（小于最小移动距离）
        guard distance >= minimumMovementDistance else {
            // 微小移动，可能是GPS漂移，不输出日志避免刷屏
            return
        }

        // 过滤异常跳跃（超过100米认为是GPS跳点）
        guard distance < 100 else {
            return
        }

        // 有效移动，累加距离
        currentDistance += distance
        lastLocation = newLocation
        lastValidUpdateTime = now

        // 更新等级
        let newTier = RewardTier.tier(for: currentDistance)
        if newTier != currentTier {
            let oldTier = currentTier
            currentTier = newTier
            print("🎖️ [探索] 等级提升: \(oldTier.displayName) → \(newTier.displayName)")
        }

        // 计算距下一等级的距离
        if let nextTier = currentTier.nextTier {
            distanceToNextTier = nextTier.distanceThreshold - currentDistance
        } else {
            distanceToNextTier = 0 // 已达最高等级
        }

        print("📍 [探索] 有效移动: +\(String(format: "%.1f", distance))m, 累计 \(String(format: "%.0f", currentDistance))m, 等级 \(currentTier.displayName)")
    }

    // MARK: - Speed Detection

    /// 检测速度
    private func checkSpeed(location: CLLocation) {
        // 使用CoreLocation提供的速度（m/s）
        guard location.speed >= 0 else { return }

        let speedKmh = location.speed * 3.6

        if speedKmh > speedThreshold {
            // 超速
            if !isOverspeed {
                // 刚开始超速
                isOverspeed = true
                overspeedStartTime = Date()
                overspeedCountdown = overspeedTimeout
                speedWarning = String(format: "速度过快（%.0f km/h）！请在 %d 秒内降速".localized, speedKmh, overspeedTimeout)

                print("⚠️ [探索] 速度警告: \(String(format: "%.1f", speedKmh))km/h > \(speedThreshold)km/h，开始倒计时")

                // 启动超速计时器
                startOverspeedTimer()
            } else {
                // 持续超速，更新倒计时显示
                if let startTime = overspeedStartTime {
                    let elapsed = Int(Date().timeIntervalSince(startTime))
                    let remaining = overspeedTimeout - elapsed

                    if remaining > 0 {
                        overspeedCountdown = remaining
                        speedWarning = String(format: "速度过快（%.0f km/h）！请在 %d 秒内降速".localized, speedKmh, remaining)
                    }
                }
            }
        } else {
            // 速度正常
            if isOverspeed {
                // 从超速恢复
                isOverspeed = false
                overspeedStartTime = nil
                overspeedCountdown = nil
                speedWarning = nil
                overspeedTimer?.invalidate()
                overspeedTimer = nil

                print("✅ [探索] 速度恢复正常: \(String(format: "%.1f", speedKmh))km/h")
            }
        }
    }

    /// 启动超速计时器
    private func startOverspeedTimer() {
        overspeedTimer?.invalidate()

        overspeedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            guard self.isOverspeed, let startTime = self.overspeedStartTime else {
                timer.invalidate()
                return
            }

            let elapsed = Int(Date().timeIntervalSince(startTime))
            let remaining = self.overspeedTimeout - elapsed

            if remaining <= 0 {
                // 超时，探索失败
                timer.invalidate()
                Task {
                    await self.failExploration(reason: "速度过快，探索中断")
                }
            } else {
                self.overspeedCountdown = remaining
            }
        }
    }

    // MARK: - Helper Methods

    /// 格式化时长显示
    func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// 格式化距离显示
    func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    // MARK: - POI Management

    /// 搜索并设置POI
    func searchAndSetupPOIs() async {
        guard let locationManager = locationManager,
              let currentLocation = locationManager.currentFullLocation else {
            print("❌ [POI] 无法获取当前位置")
            return
        }

        print("🔍 [POI] 开始搜索附近POI...")

        // 1. 先上报当前位置（确保自己被计入在线）
        await PlayerLocationManager.shared.reportCurrentLocation(isOnline: true)

        // 2. 查询附近玩家数量，获取密度等级
        let playerCount = await PlayerLocationManager.shared.queryNearbyPlayerCount()
        let densityLevel = PlayerDensityLevel.fromPlayerCount(playerCount)
        let maxPOICount = densityLevel.maxPOICount

        print("👥 [POI] 附近玩家: \(playerCount)人，密度等级: \(densityLevel.displayName)，POI数量: \(maxPOICount)")
        ExplorationLogger.shared.log("附近玩家: \(playerCount)人，密度: \(densityLevel.displayName)，POI: \(maxPOICount)个", type: .info)

        // 3. 根据密度动态搜索POI
        let pois = await POISearchManager.shared.searchNearbyPOIs(center: currentLocation.coordinate, maxCount: maxPOICount)

        await MainActor.run {
            self.nearbyPOIs = pois
            self.triggeredPOIIds.removeAll()  // 重置已触发记录
            print("✅ [POI] 找到 \(pois.count) 个POI")
            ExplorationLogger.shared.log("搜索到 \(pois.count) 个POI", type: .poi)
            for poi in pois {
                ExplorationLogger.shared.log("  - \(poi.name) (\(String(format: "%.0f", poi.distance))m)", type: .poi)
            }
        }

        // 设置地理围栏
        setupGeofences(for: pois)

        // 订阅围栏进入通知
        subscribeToGeofenceNotifications()
    }

    /// 为POI设置地理围栏
    private func setupGeofences(for pois: [POI]) {
        guard let locationManager = locationManager else { return }

        // 检查是否有"始终"位置权限（地理围栏需要）
        if !locationManager.hasAlwaysPermission {
            print("⚠️ [POI] 没有始终位置权限，请求权限...")
            ExplorationLogger.shared.log("没有始终位置权限，围栏可能失败", type: .warning)
            locationManager.requestAlwaysPermission()
            // 注意：权限请求是异步的，用户授权后下次探索会生效
        }

        print("📍 [POI] 设置地理围栏，共 \(pois.count) 个")
        ExplorationLogger.shared.log("设置地理围栏: \(pois.count) 个", type: .info)

        for poi in pois {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: poiGeofenceRadius,
                identifier: poi.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            locationManager.startMonitoringGeofence(region)
        }
    }

    /// 订阅围栏进入通知
    private func subscribeToGeofenceNotifications() {
        // 取消之前的订阅
        geofenceCancellable?.cancel()

        // 订阅新通知
        geofenceCancellable = NotificationCenter.default
            .publisher(for: .didEnterPOIRegion)
            .compactMap { $0.userInfo?["regionId"] as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] regionId in
                self?.handleEnterPOIRegion(identifier: regionId)
            }
    }

    /// 检测是否接近POI（手动距离检测，作为地理围栏的补充）
    private func checkPOIProximity(location: CLLocation) {
        // 如果没有POI，直接返回
        guard !nearbyPOIs.isEmpty else { return }

        // 第一步：更新所有 POI 的实时距离（无论是否显示弹窗）
        for index in nearbyPOIs.indices {
            let poiLocation = CLLocation(
                latitude: nearbyPOIs[index].coordinate.latitude,
                longitude: nearbyPOIs[index].coordinate.longitude
            )
            nearbyPOIs[index].distance = location.distance(from: poiLocation)
        }

        // 如果已经在显示弹窗，不进行接近检测
        guard !showPOIPopup, !showScavengeResult else { return }

        // 第二步：检测是否接近任何 POI
        for poi in nearbyPOIs {
            // 跳过已搜刮的POI
            guard poi.status != .looted else { continue }

            // 跳过已触发过弹窗的POI
            guard !triggeredPOIIds.contains(poi.id) else { continue }

            // 调试：输出当前距离POI的距离（现在是实时距离）
            print("📏 [POI检测] \(poi.name) 距离: \(String(format: "%.1f", poi.distance))m（阈值: \(poiGeofenceRadius)m）")
            ExplorationLogger.shared.log("\(poi.name) 距离: \(String(format: "%.1f", poi.distance))m", type: .distance)

            // 如果在50米范围内，触发弹窗
            if poi.distance <= poiGeofenceRadius {
                print("🎯 [POI] 手动检测接近POI: \(poi.name)，距离 \(String(format: "%.1f", poi.distance))m")
                ExplorationLogger.shared.log("✓ 接近POI: \(poi.name)，距离 \(String(format: "%.1f", poi.distance))m", type: .success)

                // 记录已触发，避免重复弹窗
                triggeredPOIIds.insert(poi.id)

                // 显示弹窗
                currentPOI = poi
                showPOIPopup = true
                break
            }
        }
    }

    /// 处理进入POI围栏（地理围栏触发）
    func handleEnterPOIRegion(identifier: String) {
        guard isExploring else { return }

        // 查找对应的POI
        guard let poi = nearbyPOIs.first(where: { $0.id.uuidString == identifier }) else {
            print("⚠️ [POI] 未找到对应POI: \(identifier)")
            return
        }

        // 检查是否已搜刮
        if poi.status == .looted {
            print("📍 [POI] POI已搜刮过: \(poi.name)")
            return
        }

        // 检查是否已通过手动检测触发过
        guard !triggeredPOIIds.contains(poi.id) else {
            print("📍 [POI] 围栏触发但已通过手动检测处理: \(poi.name)")
            return
        }

        print("🎯 [POI] 围栏触发进入POI范围: \(poi.name)")

        // 记录已触发，避免重复弹窗
        triggeredPOIIds.insert(poi.id)

        // 更新当前POI并显示弹窗
        currentPOI = poi
        showPOIPopup = true
    }

    /// 执行搜刮
    func scavengePOI(_ poi: POI) async -> [RewardItem] {
        print("🔍 [POI] 开始搜刮: \(poi.name)，危险等级: \(poi.dangerLevel.displayName)")

        // 根据危险等级计算物品数量
        let itemCount = calculateItemCount(for: poi.dangerLevel)
        var rewards: [RewardItem] = []

        // 尝试使用AI生成物品
        do {
            rewards = try await AIItemGenerator.shared.generateItems(for: poi, itemCount: itemCount)
            print("🤖 [POI] AI成功生成 \(rewards.count) 件物品")
        } catch {
            // AI生成失败，使用备用方案
            print("⚠️ [POI] AI生成失败: \(error.localizedDescription)，使用备用物品")
            rewards = AIItemGenerator.shared.generateFallbackItems(for: poi, count: itemCount)
        }

        // 输出获得的物品
        for reward in rewards {
            print("🎲 [POI] 获得物品: \(reward.name) [\(reward.rarity)] x\(reward.quantity)")
            if let story = reward.story {
                print("   📖 \(story)")
            }
        }

        // 将物品添加到背包
        await addItemsToInventory(items: rewards)

        // 更新POI状态为已搜刮
        await MainActor.run {
            if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
                nearbyPOIs[index].status = .looted
            }
        }

        print("✅ [POI] 搜刮完成，获得 \(rewards.count) 件物品")
        return rewards
    }

    /// 根据危险等级计算物品数量
    private func calculateItemCount(for dangerLevel: DangerLevel) -> Int {
        switch dangerLevel {
        case .low:
            return Int.random(in: 1...2)
        case .medium:
            return Int.random(in: 2...3)
        case .high:
            return Int.random(in: 2...4)
        case .extreme:
            return Int.random(in: 3...5)
        }
    }

    /// 确认搜刮POI（从UI调用）
    func confirmScavenge() async {
        guard let poi = currentPOI else { return }

        // 隐藏接近弹窗
        await MainActor.run {
            showPOIPopup = false
        }

        // 执行搜刮
        let items = await scavengePOI(poi)

        // 显示搜刮结果
        await MainActor.run {
            scavengeResult = ScavengeResult(poi: poi, items: items)
            showScavengeResult = true
            currentPOI = nil
        }
    }

    /// 取消搜刮（稍后再说）
    func dismissPOIPopup() {
        showPOIPopup = false
        currentPOI = nil
    }

    /// 确认搜刮结果
    func dismissScavengeResult() {
        showScavengeResult = false
        scavengeResult = nil
    }

    /// 清理POI（停止探索时调用）
    private func clearPOIs() {
        guard let locationManager = locationManager else { return }

        print("🧹 [POI] 清理POI和围栏")

        // 停止所有围栏监控
        for poi in nearbyPOIs {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: poiGeofenceRadius,
                identifier: poi.id.uuidString
            )
            locationManager.stopMonitoringGeofence(region)
        }

        // 取消通知订阅
        geofenceCancellable?.cancel()
        geofenceCancellable = nil

        // 清空POI列表和已触发记录
        nearbyPOIs.removeAll()
        triggeredPOIIds.removeAll()
        currentPOI = nil
        showPOIPopup = false
        scavengeResult = nil
        showScavengeResult = false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterPOIRegion = Notification.Name("didEnterPOIRegion")
}
