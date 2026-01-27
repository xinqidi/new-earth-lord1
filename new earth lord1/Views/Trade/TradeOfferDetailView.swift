//
//  TradeOfferDetailView.swift
//  new earth lord1
//
//  交易挂单详情视图
//  显示完整的挂单信息，支持接受或取消操作
//

import SwiftUI

struct TradeOfferDetailView: View {
    let offer: TradeOffer
    let mode: DisplayMode

    @StateObject private var tradeManager = TradeManager.shared
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) var dismiss

    enum DisplayMode {
        case accept   // 接受交易（市场挂单）
        case cancel   // 取消挂单（我的挂单）
    }

    // MARK: - State Properties

    /// 显示确认对话框
    @State private var showConfirmation = false

    /// 显示错误对话框
    @State private var showError = false

    /// 错误信息
    @State private var errorMessage = ""

    /// 操作中状态
    @State private var isProcessing = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 发布者信息
                        ownerInfoCard

                        // 物品交换信息
                        itemsExchangeCard

                        // 留言（如果有）
                        if let message = offer.message, !message.isEmpty {
                            messageCard
                        }

                        // 操作按钮
                        actionButton
                    }
                    .padding()
                }
            }
            .navigationTitle("挂单详情".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭".localized) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("确认操作".localized, isPresented: $showConfirmation) {
                Button("取消".localized, role: .cancel) { }
                Button(mode == .accept ? "确认接受".localized : "确认取消".localized, role: mode == .accept ? .none : .destructive) {
                    handleAction()
                }
            } message: {
                Text(mode == .accept ? "确定要接受这个交易吗？".localized : "确定要取消这个挂单吗？物品将退回背包".localized)
            }
            .alert("错误".localized, isPresented: $showError) {
                Button("确定".localized, role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - 发布者信息卡片

    private var ownerInfoCard: some View {
        VStack(spacing: 12) {
            // 用户头像和名称
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.ownerUsername)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 8) {
                        StatusBadgeView(status: offer.status)

                        if offer.status == .active {
                            Text("•")
                                .foregroundColor(ApocalypseTheme.textMuted)

                            if offer.isExpired {
                                Text("已过期".localized)
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.danger)
                            } else {
                                Text("剩余 \(offer.formattedRemainingTime)")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                        }
                    }
                }

                Spacer()
            }

            Divider()

            // 发布时间
            HStack {
                Text("发布时间".localized + ":")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text(offer.formattedCreatedAt)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 物品交换卡片

    private var itemsExchangeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("交换物品".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 卖家提供
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text(mode == .accept ? "你将获得".localized : "你提供".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                ForEach(offer.offeringItems, id: \.itemId) { item in
                    TradeItemRowView(item: item, mode: .display)
                }
            }

            Divider()

            // 卖家需要
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(ApocalypseTheme.warning)
                    Text(mode == .accept ? "你需要支付".localized : "你需要".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                ForEach(offer.requestingItems, id: \.itemId) { item in
                    TradeItemRowView(item: item, mode: .display)
                }

                // 接受模式：显示库存检查
                if mode == .accept {
                    inventoryCheckView
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 库存检查视图

    private var inventoryCheckView: some View {
        VStack(spacing: 8) {
            ForEach(offer.requestingItems, id: \.itemId) { item in
                let available = inventoryManager.items.first { $0.itemId == item.itemId }?.quantity ?? 0
                let isEnough = available >= item.quantity

                HStack {
                    Image(systemName: isEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isEnough ? ApocalypseTheme.success : ApocalypseTheme.danger)

                    Text("\(inventoryManager.itemDefinitions[item.itemId]?.name ?? item.itemId):")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    Text("\(available) / \(item.quantity)")
                        .font(.caption)
                        .foregroundColor(isEnough ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isEnough ? ApocalypseTheme.success.opacity(0.1) : ApocalypseTheme.danger.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 留言卡片

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("留言".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text(offer.message ?? "")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ApocalypseTheme.background)
                .cornerRadius(8)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮

    private var actionButton: some View {
        Button(action: {
            showConfirmation = true
        }) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: mode == .accept ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(mode == .accept ? "接受交易".localized : "取消挂单".localized)
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(actionButtonColor)
            .cornerRadius(12)
        }
        .disabled(isProcessing || !canPerformAction)
        .opacity((isProcessing || !canPerformAction) ? 0.6 : 1.0)
    }

    // MARK: - 计算属性

    /// 操作按钮颜色
    private var actionButtonColor: Color {
        if mode == .accept {
            return canPerformAction ? ApocalypseTheme.primary : ApocalypseTheme.textMuted
        } else {
            return ApocalypseTheme.danger
        }
    }

    /// 是否可以执行操作
    private var canPerformAction: Bool {
        if mode == .accept {
            // 检查是否可以接受
            let (canAccept, _) = tradeManager.canAcceptOffer(offer)
            return canAccept
        } else {
            // 检查是否可以取消（仅活跃状态）
            return offer.status == .active
        }
    }

    // MARK: - Actions

    /// 处理操作
    private func handleAction() {
        isProcessing = true

        Task {
            do {
                if mode == .accept {
                    _ = try await tradeManager.acceptOffer(offer)
                    await MainActor.run {
                        isProcessing = false
                        dismiss()
                    }
                } else {
                    try await tradeManager.cancelOffer(offer)
                    await MainActor.run {
                        isProcessing = false
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TradeOfferDetailView(
        offer: TradeOffer(
            id: UUID(),
            ownerId: UUID(),
            ownerUsername: "玩家A",
            offeringItems: [
                TradeItem(itemId: "water", quantity: 5),
                TradeItem(itemId: "food", quantity: 3)
            ],
            requestingItems: [
                TradeItem(itemId: "wood", quantity: 10)
            ],
            status: .active,
            message: "急需木材，价格优惠",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600 * 24),
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        ),
        mode: .accept
    )
    .environmentObject(InventoryManager())
}
