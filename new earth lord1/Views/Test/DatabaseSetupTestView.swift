//
//  DatabaseSetupTestView.swift
//  new earth lord1
//
//  数据库设置测试视图
//  用于检查交易系统数据库是否正确配置
//

import SwiftUI
import Supabase

struct DatabaseSetupTestView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    @State private var showResults = false

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 说明
                    infoCard

                    // 运行测试按钮
                    Button(action: runTests) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("检查数据库配置")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                    .disabled(isRunning)
                    .padding(.horizontal)

                    // 测试结果
                    if showResults {
                        resultsView
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("数据库配置检查")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("检查项目")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text("此工具会检查以下内容：")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                checkItem("trade_offers 表是否存在")
                checkItem("trade_history 表是否存在")
                checkItem("pending_items 表是否存在")
                checkItem("create_trade_offer 函数是否可用")
                checkItem("accept_trade_offer 函数是否可用")
                checkItem("process_expired_offers 函数是否可用")
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func checkItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(text)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 结果视图

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(testResults) { result in
                    resultCard(result)
                }

                // 总结
                if !testResults.isEmpty {
                    summaryCard
                }
            }
        }
    }

    private func resultCard(_ result: TestResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(result.passed ? ApocalypseTheme.success : ApocalypseTheme.danger)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(result.message)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private var summaryCard: some View {
        let passedCount = testResults.filter { $0.passed }.count
        let totalCount = testResults.count
        let allPassed = passedCount == totalCount

        return VStack(spacing: 16) {
            HStack {
                Image(systemName: allPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(allPassed ? ApocalypseTheme.success : ApocalypseTheme.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text(allPassed ? "配置完成" : "需要设置")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("\(passedCount)/\(totalCount) 项检查通过")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()
            }

            if !allPassed {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("需要执行的操作：")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("1. 打开 Supabase Dashboard")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("2. 进入 SQL Editor")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("3. 执行 create_trade_tables.sql 脚本")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("4. 重新运行此检查")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(allPassed ? ApocalypseTheme.success.opacity(0.1) : ApocalypseTheme.warning.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 测试逻辑

    private func runTests() {
        testResults.removeAll()
        isRunning = true
        showResults = true

        Task {
            // 测试 1: trade_offers 表
            await testTable("trade_offers")

            // 测试 2: trade_history 表
            await testTable("trade_history")

            // 测试 3: pending_items 表
            await testTable("pending_items")

            // 测试 4: create_trade_offer 函数
            await testFunction("create_trade_offer")

            // 测试 5: accept_trade_offer 函数
            await testFunction("accept_trade_offer")

            // 测试 6: process_expired_offers 函数
            await testFunctionNoParams("process_expired_offers")

            await MainActor.run {
                isRunning = false
            }
        }
    }

    private func testTable(_ tableName: String) async {
        do {
            let _: [EmptyResponse] = try await authManager.supabase
                .from(tableName)
                .select()
                .limit(1)
                .execute()
                .value

            await MainActor.run {
                testResults.append(TestResult(
                    name: "表: \(tableName)",
                    passed: true,
                    message: "✅ 表存在且可访问"
                ))
            }
        } catch {
            await MainActor.run {
                testResults.append(TestResult(
                    name: "表: \(tableName)",
                    passed: false,
                    message: "❌ 表不存在或无法访问: \(error.localizedDescription)"
                ))
            }
        }
    }

    private func testFunction(_ functionName: String) async {
        // 构造一个简单的测试调用（会因为参数不完整而失败，但能检测函数是否存在）
        do {
            let _: String = try await authManager.supabase.rpc(
                functionName,
                params: ["test": AnyJSON.string("test")]
            ).execute().value

            await MainActor.run {
                testResults.append(TestResult(
                    name: "函数: \(functionName)",
                    passed: true,
                    message: "✅ 函数存在"
                ))
            }
        } catch {
            let errorMessage = error.localizedDescription
            if errorMessage.contains("Could not find the function") || errorMessage.contains("schema cache") {
                await MainActor.run {
                    testResults.append(TestResult(
                        name: "函数: \(functionName)",
                        passed: false,
                        message: "❌ 函数不存在：需要执行 create_trade_tables.sql"
                    ))
                }
            } else {
                // 其他错误（如参数错误）说明函数存在
                await MainActor.run {
                    testResults.append(TestResult(
                        name: "函数: \(functionName)",
                        passed: true,
                        message: "✅ 函数存在（参数测试正常失败）"
                    ))
                }
            }
        }
    }

    private func testFunctionNoParams(_ functionName: String) async {
        do {
            let _: ProcessExpiredOffersResponse = try await authManager.supabase.rpc(
                functionName
            ).execute().value

            await MainActor.run {
                testResults.append(TestResult(
                    name: "函数: \(functionName)",
                    passed: true,
                    message: "✅ 函数存在且可调用"
                ))
            }
        } catch {
            let errorMessage = error.localizedDescription
            if errorMessage.contains("Could not find the function") || errorMessage.contains("schema cache") {
                await MainActor.run {
                    testResults.append(TestResult(
                        name: "函数: \(functionName)",
                        passed: false,
                        message: "❌ 函数不存在：需要执行 create_trade_tables.sql"
                    ))
                }
            } else {
                await MainActor.run {
                    testResults.append(TestResult(
                        name: "函数: \(functionName)",
                        passed: true,
                        message: "✅ 函数存在"
                    ))
                }
            }
        }
    }
}

// MARK: - Models

struct TestResult: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let message: String
}

// MARK: - Preview

#Preview {
    DatabaseSetupTestView()
        .environmentObject(AuthManager())
}
