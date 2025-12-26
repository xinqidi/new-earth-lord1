//
//  SupabaseTestView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI
import Supabase

// MARK: - Supabase Client 初始化
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://ipvkhcrgbbcccwiwlofd.supabase.co")!,
    supabaseKey: "sb_publishable_DCfb2P7IEr46I6jX-Wu_3g_Es4DTHEJ"
)

struct SupabaseTestView: View {
    // MARK: - 状态变量

    /// 连接状态：nil=未测试, true=成功, false=失败
    @State private var connectionStatus: Bool? = nil

    /// 调试日志信息
    @State private var debugLog: String = "点击按钮开始测试连接..."

    /// 是否正在测试
    @State private var isTesting: Bool = false

    // MARK: - UI 布局

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.top, 20)

                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusBackgroundColor)
                        .frame(width: 120, height: 120)
                        .shadow(color: statusBackgroundColor.opacity(0.5), radius: 20)

                    Image(systemName: statusIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 20)

                // 调试日志框
                ScrollView {
                    Text(debugLog)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(10)
                }
                .frame(height: 300)
                .padding(.horizontal)

                // 测试按钮
                Button(action: testConnection) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wifi.circle.fill")
                                .font(.title2)
                        }

                        Text(isTesting ? "测试中..." : "测试连接")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTesting ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                    .cornerRadius(10)
                }
                .disabled(isTesting)
                .padding(.horizontal)

                Spacer()
            }
        }
    }

    // MARK: - 计算属性

    /// 状态图标
    private var statusIcon: String {
        if isTesting {
            return "hourglass"
        }

        guard let status = connectionStatus else {
            return "questionmark.circle.fill"
        }

        return status ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    /// 状态背景颜色
    private var statusBackgroundColor: Color {
        if isTesting {
            return ApocalypseTheme.info
        }

        guard let status = connectionStatus else {
            return ApocalypseTheme.textMuted
        }

        return status ? ApocalypseTheme.success : ApocalypseTheme.danger
    }

    // MARK: - 测试连接方法

    private func testConnection() {
        // 重置状态
        connectionStatus = nil
        isTesting = true

        // 添加初始日志
        debugLog = """
        [开始测试]
        时间: \(getCurrentTime())
        URL: https://ipvkhcrgbbcccwiwlofd.supabase.co

        正在尝试连接到 Supabase...
        """

        // 执行异步测试
        Task {
            do {
                // 使用 v2.0 语法：故意查询一个不存在的表
                let _: [EmptyResponse] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（极少见），说明表存在
                await MainActor.run {
                    connectionStatus = true
                    debugLog += """


                    [意外结果]
                    表 'non_existent_table' 存在！
                    这通常不应该发生。

                    ✅ 连接成功（服务器已响应）
                    """
                    isTesting = false
                }

            } catch {
                // 分析错误类型
                await MainActor.run {
                    analyzeError(error)
                    isTesting = false
                }
            }
        }
    }

    // MARK: - 错误分析

    private func analyzeError(_ error: Error) {
        let errorMessage = error.localizedDescription
        let errorString = String(describing: error)

        debugLog += """


        [错误信息]
        \(errorMessage)

        [详细信息]
        \(errorString)

        """

        // 判断错误类型
        if errorString.contains("PGRST") ||
           errorString.contains("PGRST205") ||
           errorMessage.contains("Could not find the table") ||
           errorString.contains("relation") && errorString.contains("does not exist") {

            // 这是预期的错误：表不存在，说明连接成功
            connectionStatus = true
            debugLog += """
            [结果分析]
            检测到 PostgreSQL 错误响应。
            这表明：
            • Supabase 服务器成功响应
            • 数据库连接正常
            • 仅查询的表不存在（符合预期）

            ✅ 连接成功（服务器已响应）
            """

        } else if errorMessage.contains("hostname") ||
                  errorMessage.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorMessage.contains("network") {

            // URL错误或网络问题
            connectionStatus = false
            debugLog += """
            [结果分析]
            检测到网络或URL错误。
            可能原因：
            • URL配置错误
            • 无网络连接
            • 防火墙阻止

            ❌ 连接失败：URL错误或无网络
            """

        } else {
            // 其他未知错误
            connectionStatus = false
            debugLog += """
            [结果分析]
            遇到未知错误类型。

            ❌ 连接失败：\(errorMessage)
            """
        }
    }

    // MARK: - 辅助方法

    /// 获取当前时间字符串
    private func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - 空响应模型（用于解析）

struct EmptyResponse: Decodable {}

// MARK: - Preview

#Preview {
    SupabaseTestView()
}
