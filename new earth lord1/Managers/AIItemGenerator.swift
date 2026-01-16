//
//  AIItemGenerator.swift
//  new earth lord1
//
//  AI物品生成器
//  调用 Supabase Edge Function 生成搜刮物品
//

import Foundation
import Supabase

/// AI生成物品的响应结构
struct AIItemResponse: Codable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}

/// AI生成的单个物品
struct AIGeneratedItem: Codable {
    let itemId: String
    let name: String
    let category: String
    let rarity: String
    let story: String
    let icon: String
    let quantity: Int
}

/// AI物品生成错误
enum AIItemGeneratorError: Error {
    case notConfigured
    case networkError(String)
    case apiError(String)
    case parseError

    var localizedDescription: String {
        switch self {
        case .notConfigured:
            return "AI生成器未配置"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .apiError(let msg):
            return "API错误: \(msg)"
        case .parseError:
            return "解析错误"
        }
    }
}

/// AI物品生成器
/// 负责调用 Edge Function 生成 POI 搜刮物品
class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    private init() {}

    // MARK: - Private Properties

    /// Supabase客户端
    private var supabase: SupabaseClient?

    /// Edge Function URL
    private let functionUrl = "https://ipvkhcrgbbcccwiwlofd.supabase.co/functions/v1/generate-ai-items"

    // MARK: - Configuration

    /// 配置Supabase客户端
    func configure(supabase: SupabaseClient) {
        self.supabase = supabase
        print("🤖 [AI生成器] 配置完成")
    }

    // MARK: - Item Generation

    /// 为POI生成搜刮物品
    /// - Parameters:
    ///   - poi: 要搜刮的POI
    ///   - itemCount: 生成物品数量
    /// - Returns: 生成的奖励物品列表
    func generateItems(for poi: POI, itemCount: Int) async throws -> [RewardItem] {
        guard let supabase = supabase else {
            print("❌ [AI生成器] 未配置Supabase")
            throw AIItemGeneratorError.notConfigured
        }

        print("🤖 [AI生成器] 开始为 \(poi.name) 生成 \(itemCount) 个物品，危险等级: \(poi.dangerLevel.displayName)")

        // 构建请求体
        let requestBody: [String: Any] = [
            "poiType": poi.type.rawValue,
            "poiName": poi.name,
            "dangerLevel": poi.dangerLevel.rawValue,
            "itemCount": itemCount
        ]

        // 获取访问令牌
        let session = try await supabase.auth.session
        let accessToken = session.accessToken

        // 构建请求
        guard let url = URL(string: functionUrl) else {
            throw AIItemGeneratorError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIItemGeneratorError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [AI生成器] HTTP错误 \(httpResponse.statusCode): \(errorMsg)")
            throw AIItemGeneratorError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // 解析响应
        let decoder = JSONDecoder()
        let aiResponse = try decoder.decode(AIItemResponse.self, from: data)

        guard aiResponse.success, let aiItems = aiResponse.items else {
            let errorMsg = aiResponse.error ?? "Unknown error"
            print("❌ [AI生成器] API返回错误: \(errorMsg)")
            throw AIItemGeneratorError.apiError(errorMsg)
        }

        // 转换为 RewardItem
        let rewardItems = aiItems.map { aiItem in
            RewardItem(
                itemId: aiItem.itemId,
                name: aiItem.name,
                quantity: aiItem.quantity,
                rarity: aiItem.rarity,
                icon: aiItem.icon,
                category: aiItem.category,
                story: aiItem.story
            )
        }

        print("✅ [AI生成器] 成功生成 \(rewardItems.count) 个物品")
        for item in rewardItems {
            print("   - \(item.name) [\(item.rarity)] \(item.story ?? "")")
        }

        return rewardItems
    }

    // MARK: - Fallback Generation

    /// 生成备用物品（当AI失败时使用）
    /// - Parameters:
    ///   - poi: POI
    ///   - count: 物品数量
    /// - Returns: 备用物品列表
    func generateFallbackItems(for poi: POI, count: Int) -> [RewardItem] {
        print("⚠️ [AI生成器] 使用备用物品生成")

        // 根据危险等级确定稀有度分布
        let rarities = determineFallbackRarities(dangerLevel: poi.dangerLevel, count: count)

        var items: [RewardItem] = []
        let timestamp = Int(Date().timeIntervalSince1970)

        for (index, rarity) in rarities.enumerated() {
            let (name, category, icon) = getFallbackItem(for: poi.type, rarity: rarity)

            let item = RewardItem(
                itemId: "fallback_\(timestamp)_\(index)",
                name: name,
                quantity: 1,
                rarity: rarity,
                icon: icon,
                category: category,
                story: "在\(poi.name)的废墟中发现的物品。"
            )
            items.append(item)
        }

        return items
    }

    /// 根据危险等级确定备用稀有度
    private func determineFallbackRarities(dangerLevel: DangerLevel, count: Int) -> [String] {
        var rarities: [String] = []

        for _ in 0..<count {
            let roll = Double.random(in: 0..<100)
            let rarity: String

            switch dangerLevel {
            case .low:
                // 普通70%, 优秀25%, 稀有5%
                if roll < 70 { rarity = "common" }
                else if roll < 95 { rarity = "uncommon" }
                else { rarity = "rare" }

            case .medium:
                // 普通50%, 优秀30%, 稀有15%, 史诗5%
                if roll < 50 { rarity = "common" }
                else if roll < 80 { rarity = "uncommon" }
                else if roll < 95 { rarity = "rare" }
                else { rarity = "epic" }

            case .high:
                // 优秀40%, 稀有35%, 史诗20%, 传奇5%
                if roll < 40 { rarity = "uncommon" }
                else if roll < 75 { rarity = "rare" }
                else if roll < 95 { rarity = "epic" }
                else { rarity = "legendary" }

            case .extreme:
                // 稀有30%, 史诗40%, 传奇30%
                if roll < 30 { rarity = "rare" }
                else if roll < 70 { rarity = "epic" }
                else { rarity = "legendary" }
            }

            rarities.append(rarity)
        }

        return rarities
    }

    /// 获取备用物品信息
    private func getFallbackItem(for poiType: POIType, rarity: String) -> (name: String, category: String, icon: String) {
        // 根据POI类型和稀有度返回合适的备用物品
        switch poiType {
        case .supermarket:
            switch rarity {
            case "legendary": return ("完好的压缩饼干箱", "food", "takeoutbag.and.cup.and.straw.fill")
            case "epic": return ("未开封的蛋白粉", "food", "cup.and.saucer.fill")
            case "rare": return ("罐装肉类", "food", "fork.knife")
            case "uncommon": return ("瓶装矿泉水", "food", "cup.and.saucer.fill")
            default: return ("过期饼干", "food", "fork.knife")
            }

        case .hospital:
            switch rarity {
            case "legendary": return ("实验性抗生素", "medicine", "cross.case.fill")
            case "epic": return ("急救医疗包", "medicine", "cross.case.fill")
            case "rare": return ("止痛药", "medicine", "pills.fill")
            case "uncommon": return ("医用绷带", "medicine", "bandage.fill")
            default: return ("创可贴", "medicine", "bandage.fill")
            }

        case .pharmacy:
            switch rarity {
            case "legendary": return ("稀有特效药", "medicine", "pills.fill")
            case "epic": return ("广谱抗生素", "medicine", "pills.fill")
            case "rare": return ("消炎药", "medicine", "pills.fill")
            case "uncommon": return ("维生素片", "medicine", "pills.fill")
            default: return ("感冒药", "medicine", "pills.fill")
            }

        case .gasStation:
            switch rarity {
            case "legendary": return ("军用燃料桶", "material", "flame.fill")
            case "epic": return ("汽油桶", "material", "flame.fill")
            case "rare": return ("润滑油", "material", "gear")
            case "uncommon": return ("打火机", "tool", "flame.fill")
            default: return ("空瓶子", "material", "hammer.fill")
            }

        case .factory:
            switch rarity {
            case "legendary": return ("工业级电池组", "material", "bolt.fill")
            case "epic": return ("精密仪器", "tool", "wrench.and.screwdriver.fill")
            case "rare": return ("电机马达", "material", "gear")
            case "uncommon": return ("钢管", "material", "hammer.fill")
            default: return ("螺丝螺母", "material", "gear")
            }

        case .warehouse:
            switch rarity {
            case "legendary": return ("密封储备箱", "material", "shippingbox.fill")
            case "epic": return ("防水帆布", "clothing", "tshirt.fill")
            case "rare": return ("工具箱", "tool", "wrench.and.screwdriver.fill")
            case "uncommon": return ("绳索", "material", "hammer.fill")
            default: return ("纸箱", "material", "shippingbox.fill")
            }

        case .school:
            switch rarity {
            case "legendary": return ("教师急救箱", "medicine", "cross.case.fill")
            case "epic": return ("运动器材", "tool", "hammer.fill")
            case "rare": return ("文具套装", "material", "pencil")
            case "uncommon": return ("书本", "material", "book.fill")
            default: return ("废纸", "material", "doc.fill")
            }
        }
    }
}
