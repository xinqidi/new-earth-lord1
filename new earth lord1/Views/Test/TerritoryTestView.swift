//
//  TerritoryTestView.swift
//  new earth lord1
//
//  圈地功能测试界面
//  显示圈地过程的调试日志，支持清空和导出
//

import SwiftUI

struct TerritoryTestView: View {

    // MARK: - Environment Objects

    /// 定位管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - Observed Objects

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - State Properties

    /// 滚动视图代理（用于自动滚动到底部）
    @State private var scrollProxy: ScrollViewProxy?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 状态指示器

            HStack {
                Circle()
                    .frame(width: 12, height: 12)

                Text(locationManager.isTracking ? "● 追踪中" : "○ 未追踪")
                    .font(.headline)
                    .foregroundColor(locationManager.isTracking ? .green : .gray)

                Spacer()

                Text("日志: \(logger.logs.count)/200")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)

            Divider()

            // MARK: - 日志滚动区域

            if logger.logText.isEmpty {
                // 空状态提示
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

                    Text("暂无日志")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("开始圈地追踪后，这里将显示调试信息")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ApocalypseTheme.background)
            } else {
                // 日志内容
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(logger.logText)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .padding()
                                .id("logBottom") // 用于滚动定位
                        }
                    }
                    .background(ApocalypseTheme.background)
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: logger.logText) { _ in
                        // 日志更新时自动滚动到底部
                        withAnimation {
                            proxy.scrollTo("logBottom", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // MARK: - 操作按钮

            HStack(spacing: 16) {
                // 清空日志按钮
                Button(action: {
                    logger.clear()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清空日志")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(logger.logs.isEmpty)
                .opacity(logger.logs.isEmpty ? 0.5 : 1.0)

                // 导出日志按钮
                ShareLink(
                    item: logger.export(),
                    preview: SharePreview(
                        "圈地测试日志",
                        image: Image(systemName: "doc.text")
                    )
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出日志")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .disabled(logger.logs.isEmpty)
                .opacity(logger.logs.isEmpty ? 0.5 : 1.0)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
