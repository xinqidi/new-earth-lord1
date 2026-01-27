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
