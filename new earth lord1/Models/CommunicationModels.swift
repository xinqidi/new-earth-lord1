//
//  CommunicationModels.swift
//  new earth lord1
//
//  通讯系统数据模型
//  定义设备类型、设备模型和导航枚举
//

import Foundation

// MARK: - 设备类型

enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .radio: return "收音机".localized
        case .walkieTalkie: return "对讲机".localized
        case .campRadio: return "营地电台".localized
        case .satellite: return "卫星通讯".localized
        }
    }

    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "walkie.talkie.radio"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .radio: return "只能接收信号，无法发送消息".localized
        case .walkieTalkie: return "可在3公里范围内通讯".localized
        case .campRadio: return "可在30公里范围内广播".localized
        case .satellite: return "可在100公里+范围内联络".localized
        }
    }

    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    var rangeText: String {
        switch self {
        case .radio: return "无限制（仅接收）".localized
        case .walkieTalkie: return "3 公里".localized
        case .campRadio: return "30 公里".localized
        case .satellite: return "100+ 公里".localized
        }
    }

    var canSend: Bool {
        self != .radio
    }

    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有".localized
        case .campRadio: return "需建造「营地电台」建筑".localized
        case .satellite: return "需建造「通讯塔」建筑".localized
        }
    }
}

// MARK: - 设备模型

struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 导航枚举

enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call = "呼叫"
    case devices = "设备"

    var displayName: String {
        rawValue.localized
    }

    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型

enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case publicChannel = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official: return "官方频道".localized
        case .publicChannel: return "公开频道".localized
        case .walkie: return "对讲频道".localized
        case .camp: return "营地频道".localized
        case .satellite: return "卫星频道".localized
        }
    }

    var iconName: String {
        switch self {
        case .official: return "megaphone.fill"
        case .publicChannel: return "globe"
        case .walkie: return "walkie.talkie.radio"
        case .camp: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .official: return "系统官方公告频道".localized
        case .publicChannel: return "任何人可加入的公开频道".localized
        case .walkie: return "需要对讲机，范围3公里".localized
        case .camp: return "需要营地电台，范围30公里".localized
        case .satellite: return "需要卫星通讯，范围100+公里".localized
        }
    }

    var rangeText: String {
        switch self {
        case .official, .publicChannel: return "全局".localized
        case .walkie: return "3 公里".localized
        case .camp: return "30 公里".localized
        case .satellite: return "100+ 公里".localized
        }
    }

    var requiredDevice: DeviceType? {
        switch self {
        case .official, .publicChannel: return nil
        case .walkie: return .walkieTalkie
        case .camp: return .campRadio
        case .satellite: return .satellite
        }
    }

    /// 用户可创建的频道类型（排除官方）
    static var creatableTypes: [ChannelType] {
        [.publicChannel, .walkie, .camp, .satellite]
    }
}

// MARK: - 频道模型

struct CommunicationChannel: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case latitude
        case longitude
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        creatorId = try container.decode(UUID.self, forKey: .creatorId)

        // 处理 channelType，支持 "public" 映射到 .publicChannel
        let typeString = try container.decode(String.self, forKey: .channelType)
        if typeString == "public" {
            channelType = .publicChannel
        } else {
            channelType = ChannelType(rawValue: typeString) ?? .publicChannel
        }

        channelCode = try container.decode(String.self, forKey: .channelCode)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(creatorId, forKey: .creatorId)
        // 编码时 publicChannel 转回 "public"
        let typeString = channelType == .publicChannel ? "public" : channelType.rawValue
        try container.encode(typeString, forKey: .channelType)
        try container.encode(channelCode, forKey: .channelCode)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - 订阅模型

struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    var isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 已订阅频道组合模型

struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
}
