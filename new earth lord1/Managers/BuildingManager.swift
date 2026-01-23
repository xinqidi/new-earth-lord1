//
//  BuildingManager.swift
//  new earth lord1
//
//  建筑管理器
//  负责建筑模板加载、建造、升级和状态管理
//

import Foundation
import Supabase
import Combine
import CoreLocation

/// 建筑管理器（单例）
class BuildingManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BuildingManager()

    // MARK: - Published Properties

    /// 建筑模板列表
    @Published var buildingTemplates: [BuildingTemplate] = []

    /// 玩家建筑列表
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient?

    /// 当前用户 ID
    private var userId: UUID?

    /// 背包管理器引用
    private var inventoryManager: InventoryManager?

    /// 建造完成检测定时器
    private var constructionCheckTimer: Timer?

    /// 是否已配置
    private var isConfigured: Bool = false

    // MARK: - Initialization

    private init() {
        print("🏗️ [建筑] BuildingManager 初始化完成")
    }

    // MARK: - Configuration

    /// 配置建筑管理器
    func configure(supabase: SupabaseClient, userId: UUID, inventoryManager: InventoryManager) {
        self.supabase = supabase
        self.userId = userId
        self.inventoryManager = inventoryManager
        self.isConfigured = true

        print("🏗️ [建筑] 配置完成，用户ID: \(userId)")

        // 启动建造完成检测
        startConstructionCheck()
    }

    // MARK: - Template Loading

    /// 从 JSON 加载建筑模板
    func loadTemplates() {
        print("🏗️ [建筑] 开始加载建筑模板...")

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("❌ [建筑] 找不到 building_templates.json 文件")
            DispatchQueue.main.async {
                self.errorMessage = "找不到建筑模板配置文件"
            }
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let templates = try decoder.decode([BuildingTemplate].self, from: data)

            DispatchQueue.main.async {
                self.buildingTemplates = templates
            }

            print("🏗️ [建筑] ✅ 成功加载 \(templates.count) 个建筑模板")

            // 打印模板信息
            for template in templates {
                print("   - \(template.name) (Tier \(template.tier), \(template.category.displayName))")
            }

        } catch {
            print("❌ [建筑] 加载模板失败: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "加载建筑模板失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Can Build Check

    /// 检查是否可以建造指定建筑
    func canBuild(template: BuildingTemplate, territoryId: String) -> (canBuild: Bool, error: BuildingError?) {
        guard let inventoryManager = inventoryManager else {
            return (false, .notConfigured)
        }

        // 1. 检查资源是否足够
        var missingResources: [String: Int] = [:]
        for (resourceId, required) in template.requiredResources {
            let available = inventoryManager.items.first { $0.itemId == resourceId }?.quantity ?? 0
            if available < required {
                missingResources[resourceId] = required - available
            }
        }

        if !missingResources.isEmpty {
            return (false, .insufficientResources(missingResources))
        }

        // 2. 检查数量是否达到上限
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count

        if existingCount >= template.maxPerTerritory {
            return (false, .maxBuildingsReached(template.maxPerTerritory))
        }

        return (true, nil)
    }

    // MARK: - Construction

    /// 开始建造建筑
    func startConstruction(templateId: String, territoryId: String, location: CLLocationCoordinate2D?) async throws {
        guard let supabase = supabase, let userId = userId, let inventoryManager = inventoryManager else {
            throw BuildingError.notConfigured
        }

        // 查找模板
        guard let template = buildingTemplates.first(where: { $0.templateId == templateId }) else {
            throw BuildingError.templateNotFound
        }

        // 检查是否可以建造
        let (canBuild, error) = self.canBuild(template: template, territoryId: territoryId)
        if !canBuild {
            throw error ?? BuildingError.invalidStatus
        }

        print("🏗️ [建筑] 开始建造: \(template.name)")

        // 扣除资源
        for (resourceId, quantity) in template.requiredResources {
            try await inventoryManager.removeItem(itemId: resourceId, quantity: quantity)
            print("   - 消耗 \(resourceId) x\(quantity)")
        }

        // 计算建造完成时间
        let now = Date()
        let completedAt = now.addingTimeInterval(TimeInterval(template.buildTimeSeconds))

        // 创建建筑记录
        let newBuilding = NewPlayerBuilding(
            user_id: userId,
            territory_id: territoryId,
            template_id: templateId,
            building_name: template.name,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            location_lat: location?.latitude,
            location_lon: location?.longitude,
            build_started_at: now,
            build_completed_at: completedAt
        )

        let insertedBuilding: PlayerBuilding = try await supabase
            .from("player_buildings")
            .insert(newBuilding)
            .select()
            .single()
            .execute()
            .value

        await MainActor.run {
            self.playerBuildings.append(insertedBuilding)
        }

        print("🏗️ [建筑] ✅ 建造已开始: \(template.name)，预计 \(template.buildTimeSeconds) 秒后完成")

        // 发送通知
        NotificationCenter.default.post(name: .buildingUpdated, object: nil)
    }

    // MARK: - Complete Construction

    /// 完成建造（更新状态为 active）
    func completeConstruction(buildingId: UUID) async throws {
        guard let supabase = supabase else {
            throw BuildingError.notConfigured
        }

        // 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = playerBuildings[index]

        // 检查状态
        guard building.status == .constructing else {
            throw BuildingError.invalidStatus
        }

        print("🏗️ [建筑] 完成建造: \(building.buildingName)")

        // 更新数据库
        let update = BuildingStatusUpdate(
            status: BuildingStatus.active.rawValue,
            updated_at: Date()
        )

        try await supabase
            .from("player_buildings")
            .update(update)
            .eq("id", value: buildingId.uuidString)
            .execute()

        // 更新本地状态
        await MainActor.run {
            self.playerBuildings[index].status = .active
            self.playerBuildings[index].updatedAt = Date()
        }

        print("🏗️ [建筑] ✅ 建造完成: \(building.buildingName)")

        // 发送通知
        NotificationCenter.default.post(name: .buildingUpdated, object: nil)
    }

    // MARK: - Upgrade

    /// 升级建筑
    func upgradeBuilding(buildingId: UUID) async throws {
        guard let supabase = supabase, let inventoryManager = inventoryManager else {
            throw BuildingError.notConfigured
        }

        // 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = playerBuildings[index]

        // 检查状态必须是 active
        guard building.status == .active else {
            throw BuildingError.invalidStatus
        }

        // 查找模板
        guard let template = buildingTemplates.first(where: { $0.templateId == building.templateId }) else {
            throw BuildingError.templateNotFound
        }

        // 检查是否已达最高等级
        guard building.level < template.maxLevel else {
            throw BuildingError.maxLevelReached
        }

        print("🏗️ [建筑] 升级建筑: \(building.buildingName) Lv.\(building.level) → Lv.\(building.level + 1)")

        // 计算升级所需资源（等级 * 基础资源）
        let levelMultiplier = building.level + 1
        var missingResources: [String: Int] = [:]

        for (resourceId, baseQuantity) in template.requiredResources {
            let required = baseQuantity * levelMultiplier / 2  // 升级消耗为基础的一半 * 等级
            let available = inventoryManager.items.first { $0.itemId == resourceId }?.quantity ?? 0
            if available < required {
                missingResources[resourceId] = required - available
            }
        }

        if !missingResources.isEmpty {
            throw BuildingError.insufficientResources(missingResources)
        }

        // 扣除资源
        for (resourceId, baseQuantity) in template.requiredResources {
            let required = baseQuantity * levelMultiplier / 2
            try await inventoryManager.removeItem(itemId: resourceId, quantity: required)
            print("   - 消耗 \(resourceId) x\(required)")
        }

        // 更新数据库
        let update = BuildingLevelUpdate(
            level: building.level + 1,
            updated_at: Date()
        )

        try await supabase
            .from("player_buildings")
            .update(update)
            .eq("id", value: buildingId.uuidString)
            .execute()

        // 更新本地状态
        await MainActor.run {
            self.playerBuildings[index].level += 1
            self.playerBuildings[index].updatedAt = Date()
        }

        print("🏗️ [建筑] ✅ 升级完成: \(building.buildingName) 已升至 Lv.\(building.level + 1)")

        // 发送通知
        NotificationCenter.default.post(name: .buildingUpdated, object: nil)
    }

    // MARK: - Demolish

    /// 拆除建筑
    func demolishBuilding(buildingId: UUID) async throws {
        guard let supabase = supabase else {
            throw BuildingError.notConfigured
        }

        // 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = playerBuildings[index]

        print("🏗️ [建筑] 拆除建筑: \(building.buildingName)")

        // 从数据库删除
        try await supabase
            .from("player_buildings")
            .delete()
            .eq("id", value: buildingId.uuidString)
            .execute()

        // 从本地列表移除
        await MainActor.run {
            self.playerBuildings.remove(at: index)
        }

        print("🏗️ [建筑] ✅ 拆除完成: \(building.buildingName)")

        // 发送通知
        NotificationCenter.default.post(name: .buildingUpdated, object: nil)
    }

    // MARK: - Fetch Buildings

    /// 获取玩家建筑列表
    func fetchPlayerBuildings(territoryId: String?) async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [建筑] Supabase或用户ID未配置")
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
            print("🏗️ [建筑] 开始加载玩家建筑...")

            var query = supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)

            if let territoryId = territoryId {
                query = query.eq("territory_id", value: territoryId)
            }

            let buildings: [PlayerBuilding] = try await query.execute().value

            await MainActor.run {
                self.playerBuildings = buildings
                self.isLoading = false
            }

            print("🏗️ [建筑] ✅ 加载完成，共 \(buildings.count) 个建筑")

            // 检查是否有需要自动完成的建筑
            await checkAndCompleteConstructions()

        } catch {
            print("❌ [建筑] 加载失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "加载建筑失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Construction Check

    /// 启动建造完成检测定时器
    private func startConstructionCheck() {
        // 停止已有的定时器
        constructionCheckTimer?.invalidate()

        // 每 10 秒检查一次
        constructionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkAndCompleteConstructions()
            }
        }

        print("🏗️ [建筑] 建造完成检测已启动（每10秒）")
    }

    /// 检查并自动完成已到期的建造
    private func checkAndCompleteConstructions() async {
        let now = Date()

        // 找到所有需要完成的建筑
        let buildingsToComplete = playerBuildings.filter { building in
            guard building.status == .constructing,
                  let completedAt = building.buildCompletedAt else {
                return false
            }
            return completedAt <= now
        }

        // 自动完成这些建筑
        for building in buildingsToComplete {
            do {
                try await completeConstruction(buildingId: building.id)
            } catch {
                print("❌ [建筑] 自动完成建造失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helper Methods

    /// 获取指定领地的建筑列表
    func getBuildingsForTerritory(_ territoryId: String) -> [PlayerBuilding] {
        return playerBuildings.filter { $0.territoryId == territoryId }
    }

    /// 获取指定模板的建筑
    func getTemplate(for templateId: String) -> BuildingTemplate? {
        return buildingTemplates.first { $0.templateId == templateId }
    }

    /// 按分类筛选模板
    func getTemplatesByCategory(_ category: BuildingCategory) -> [BuildingTemplate] {
        return buildingTemplates.filter { $0.category == category }
    }

    /// 获取指定领地某类型建筑的数量
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == templateId
        }.count
    }

    // MARK: - Cleanup

    /// 停止定时器
    func stopConstructionCheck() {
        constructionCheckTimer?.invalidate()
        constructionCheckTimer = nil
        print("🏗️ [建筑] 建造完成检测已停止")
    }

    // MARK: - Testing

    /// 添加测试资源（仅用于测试）
    func addTestResources() async {
        guard let inventoryManager = inventoryManager else {
            print("❌ [测试] InventoryManager 未配置")
            return
        }

        print("🧪 [测试] 开始添加测试资源...")

        do {
            // 添加建造所需的资源
            try await inventoryManager.addItem(itemId: "wood", quantity: 500)
            try await inventoryManager.addItem(itemId: "stone", quantity: 300)
            try await inventoryManager.addItem(itemId: "metal", quantity: 200)
            try await inventoryManager.addItem(itemId: "glass", quantity: 100)

            print("✅ [测试] 测试资源添加成功！")
            print("   - 木材(wood): 500")
            print("   - 石头(stone): 300")
            print("   - 金属(metal): 200")
            print("   - 玻璃(glass): 100")

            // 重新加载背包
            await inventoryManager.loadInventory()

        } catch {
            print("❌ [测试] 添加测试资源失败: \(error.localizedDescription)")
        }
    }

    deinit {
        stopConstructionCheck()
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// 建筑更新通知（建造、升级、拆除后发送）
    static let buildingUpdated = Notification.Name("buildingUpdated")
}
