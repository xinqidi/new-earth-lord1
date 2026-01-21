//
//  InventoryManager.swift
//  new earth lord1
//
//  背包管理器
//  负责从Supabase加载、添加、删除背包物品
//

import Foundation
import Supabase
import Combine

/// 背包物品（数据库模型）
struct DBInventoryItem: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let item_id: String
    var quantity: Int
    let quality: String?
    let obtained_at: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case item_id
        case quantity
        case quality
        case obtained_at
    }
}

/// 背包物品显示模型（包含物品定义信息）
struct InventoryDisplayItem: Identifiable {
    let id: UUID
    let itemId: String
    let name: String
    let description: String
    let category: String
    let rarity: String
    let weight: Double
    let icon: String
    var quantity: Int
    let quality: String?
    let obtainedAt: Date?

    /// 分类显示名称
    var categoryDisplayName: String {
        switch category {
        case "water": return "水类"
        case "food": return "食物"
        case "medical": return "医疗"
        case "material": return "材料"
        case "tool": return "工具"
        default: return category
        }
    }

    /// 稀有度显示名称
    var rarityDisplayName: String {
        switch rarity {
        case "common": return "普通"
        case "rare": return "稀有"
        case "epic": return "史诗"
        default: return rarity
        }
    }
}

/// 背包管理器
class InventoryManager: ObservableObject {

    // MARK: - Published Properties

    /// 背包物品列表
    @Published var items: [InventoryDisplayItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 物品定义缓存
    @Published var itemDefinitions: [String: DBItemDefinition] = [:]

    // MARK: - Private Properties

    /// Supabase客户端
    private var supabase: SupabaseClient?

    /// 当前用户ID
    private var userId: UUID?

    // MARK: - Computed Properties

    /// 背包物品总数
    var totalItemCount: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }

    /// 背包最大容量
    let maxCapacity = 100

    /// 容量使用百分比
    var capacityPercentage: Double {
        return Double(totalItemCount) / Double(maxCapacity)
    }

    // MARK: - Initialization

    init() {
        print("🎒 [背包] InventoryManager 初始化完成")
    }

    /// 配置Supabase客户端和用户ID
    func configure(supabase: SupabaseClient, userId: UUID) {
        self.supabase = supabase
        self.userId = userId
        print("🎒 [背包] 配置完成，用户ID: \(userId)")
    }

    // MARK: - Load Methods

    /// 加载物品定义
    func loadItemDefinitions() async throws {
        guard let supabase = supabase else {
            print("❌ [背包] Supabase未配置")
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase未配置"])
        }

        print("🎒 [背包] 开始加载物品定义...")

        let definitions: [DBItemDefinition] = try await supabase
            .from("item_definitions")
            .select()
            .execute()
            .value

        await MainActor.run {
            self.itemDefinitions = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        }

        print("✅ [背包] 物品定义加载完成，共 \(definitions.count) 种")
    }

    /// 加载背包物品
    func loadInventory() async {
        guard let supabase = supabase, let userId = userId else {
            print("❌ [背包] Supabase或用户ID未配置")
            await MainActor.run {
                self.errorMessage = "请先登录".localized
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            // 确保物品定义已加载
            if itemDefinitions.isEmpty {
                try await loadItemDefinitions()
            }

            print("🎒 [背包] 开始加载背包物品...")

            let inventoryItems: [DBInventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            // 转换为显示模型
            var displayItems: [InventoryDisplayItem] = []
            for item in inventoryItems {
                if let definition = itemDefinitions[item.item_id] {
                    let displayItem = InventoryDisplayItem(
                        id: item.id,
                        itemId: item.item_id,
                        name: definition.name,
                        description: definition.description ?? "",
                        category: definition.category,
                        rarity: definition.rarity,
                        weight: definition.weight ?? 0,
                        icon: definition.icon ?? "questionmark",
                        quantity: item.quantity,
                        quality: item.quality,
                        obtainedAt: item.obtained_at
                    )
                    displayItems.append(displayItem)
                }
            }

            await MainActor.run {
                self.items = displayItems
                self.isLoading = false
            }

            print("✅ [背包] 背包加载完成，共 \(displayItems.count) 种物品")

        } catch {
            print("❌ [背包] 加载失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "加载背包失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Item Operations

    /// 添加物品到背包
    func addItem(itemId: String, quantity: Int = 1) async throws {
        guard let supabase = supabase, let userId = userId else {
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "请先登录"])
        }

        // 检查是否已有该物品
        if let existingIndex = items.firstIndex(where: { $0.itemId == itemId }) {
            // 更新数量
            let existingItem = items[existingIndex]
            let newQuantity = existingItem.quantity + quantity

            struct QuantityUpdate: Encodable {
                let quantity: Int
            }

            try await supabase
                .from("inventory_items")
                .update(QuantityUpdate(quantity: newQuantity))
                .eq("id", value: existingItem.id.uuidString)
                .execute()

            await MainActor.run {
                self.items[existingIndex].quantity = newQuantity
            }

            print("🎒 [背包] 更新物品: \(existingItem.name) 数量 \(existingItem.quantity) → \(newQuantity)")
        } else {
            // 新增物品
            struct NewInventoryItem: Encodable {
                let user_id: UUID
                let item_id: String
                let quantity: Int
            }

            let newItem = NewInventoryItem(
                user_id: userId,
                item_id: itemId,
                quantity: quantity
            )

            try await supabase
                .from("inventory_items")
                .insert(newItem)
                .execute()

            // 重新加载背包
            await loadInventory()

            if let definition = itemDefinitions[itemId] {
                print("🎒 [背包] 添加物品: \(definition.name) x\(quantity)")
            }
        }
    }

    /// 移除物品
    func removeItem(itemId: String, quantity: Int = 1) async throws {
        guard let supabase = supabase else {
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "请先登录"])
        }

        guard let existingIndex = items.firstIndex(where: { $0.itemId == itemId }) else {
            throw NSError(domain: "InventoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "物品不存在"])
        }

        let existingItem = items[existingIndex]
        let newQuantity = existingItem.quantity - quantity

        if newQuantity <= 0 {
            // 删除物品
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("id", value: existingItem.id.uuidString)
                .execute()

            await MainActor.run {
                self.items.remove(at: existingIndex)
            }

            print("🎒 [背包] 删除物品: \(existingItem.name)")
        } else {
            // 减少数量
            struct QuantityUpdate: Encodable {
                let quantity: Int
            }

            try await supabase
                .from("inventory_items")
                .update(QuantityUpdate(quantity: newQuantity))
                .eq("id", value: existingItem.id.uuidString)
                .execute()

            await MainActor.run {
                self.items[existingIndex].quantity = newQuantity
            }

            print("🎒 [背包] 减少物品: \(existingItem.name) 数量 \(existingItem.quantity) → \(newQuantity)")
        }
    }

    /// 使用物品
    func useItem(itemId: String) async {
        do {
            try await removeItem(itemId: itemId, quantity: 1)
            print("🎒 [背包] 使用物品成功")
        } catch {
            print("❌ [背包] 使用物品失败: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "使用物品失败".localized
            }
        }
    }

    // MARK: - Filter Methods

    /// 按分类筛选物品
    func filterByCategory(_ category: String?) -> [InventoryDisplayItem] {
        guard let category = category else {
            return items
        }
        return items.filter { $0.category == category }
    }

    /// 按名称搜索物品
    func searchByName(_ query: String) -> [InventoryDisplayItem] {
        guard !query.isEmpty else {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// 按分类和名称筛选
    func filter(category: String?, searchText: String) -> [InventoryDisplayItem] {
        var result = items

        if let category = category {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }
}
