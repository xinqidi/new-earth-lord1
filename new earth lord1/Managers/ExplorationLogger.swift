//
//  ExplorationLogger.swift
//  new earth lord1
//
//  探索功能日志管理器
//  用于记录探索过程中的调试信息，支持日志清空和导出
//

import Foundation
import SwiftUI
import Combine

/// 探索日志管理器（单例 + ObservableObject）
/// 用于在 App 内显示探索模块的调试日志，方便真机测试
class ExplorationLogger: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = ExplorationLogger()

    // MARK: - Log Entry

    /// 日志类型
    enum LogType: String {
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARNING"
        case error = "ERROR"
        case poi = "POI"
        case distance = "DIST"

        /// 日志颜色
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .poi: return .purple
            case .distance: return .cyan
            }
        }
    }

    /// 日志条目
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let type: LogType
    }

    // MARK: - Properties

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 300

    /// 时间格式化器（显示格式：HH:mm:ss）
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 时间格式化器（导出格式：yyyy-MM-dd HH:mm:ss）
    private let exportTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        print("📋 [探索日志] 初始化完成")
    }

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        // 确保在主线程更新（SwiftUI 需要）
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), message: message, type: type)
            self.logs.append(entry)

            // 限制日志数量
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst()
            }

            // 更新格式化文本
            self.updateLogText()

            // 同时输出到控制台
            print("🔍 [\(type.rawValue)] \(message)")
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.logText = ""
            print("📋 [探索日志] 日志已清空")
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息和完整时间戳的日志文本
    func export() -> String {
        let header = """
        === 探索功能测试日志 ===
        导出时间: \(exportTimeFormatter.string(from: Date()))
        日志条数: \(logs.count)

        """

        let logLines = logs.map { entry in
            let time = exportTimeFormatter.string(from: entry.timestamp)
            return "[\(time)] [\(entry.type.rawValue)] \(entry.message)"
        }.joined(separator: "\n")

        return header + logLines
    }

    // MARK: - Private Methods

    /// 更新格式化的日志文本
    private func updateLogText() {
        logText = logs.map { entry in
            let time = timeFormatter.string(from: entry.timestamp)
            return "[\(time)] [\(entry.type.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
