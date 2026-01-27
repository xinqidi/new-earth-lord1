//
//  CreateOfferView.swift
//  new earth lord1
//
//  创建交易挂单视图
//  选择提供物品、需求物品、有效期和留言
//

import SwiftUI

struct CreateOfferView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) var dismiss

    // MARK: - State Properties

    /// 我提供的物品
    @State private var offeringItems: [TradeItem] = []

    /// 我需要的物品
    @State private var requestingItems: [TradeItem] = []

    /// 留言
    @State private var message: String = ""

    /// 过期时间（小时）
    @State private var expirationHours: Int = 24

    /// 显示物品选择器（提供）
    @State private var showOfferingSelector = false

    /// 显示物品选择器（需求）
    @State private var showRequestingSelector = false

    /// 创建中状态
    @State private var isCreating = false

    /// 显示错误
    @State private var showError = false

    /// 错误信息
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 我提供的物品
                        offeringItemsCard

                        // 我需要的物品
                        requestingItemsCard

                        // 有效期选择
                        expirationCard

                        // 留言
                        messageCard

                        // 发布按钮
                        publishButton
                    }
                    .padding()
                }
            }
            .navigationTitle("创建挂单".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消".localized) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showOfferingSelector) {
                ItemSelectorView(
                    mode: .fromInventory,
                    onSelect: { itemId, quantity in
                        addOfferingItem(itemId: itemId, quantity: quantity)
                        showOfferingSelector = false
                    },
                    onCancel: {
                        showOfferingSelector = false
                    }
                )
            }
            .sheet(isPresented: $showRequestingSelector) {
                ItemSelectorView(
                    mode: .allItems,
                    onSelect: { itemId, quantity in
                        addRequestingItem(itemId: itemId, quantity: quantity)
                        showRequestingSelector = false
                    },
                    onCancel: {
                        showRequestingSelector = false
                    }
                )
            }
            .alert("错误".localized, isPresented: $showError) {
                Button("确定".localized, role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - 我提供的物品卡片

    private var offeringItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text("我提供".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Button(action: {
                    showOfferingSelector = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加物品".localized)
                    }
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            if offeringItems.isEmpty {
                Text("点击添加你要出售的物品".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(offeringItems.enumerated()), id: \.element.itemId) { index, item in
                    TradeItemRowView(
                        item: item,
                        mode: .editable,
                        onRemove: {
                            removeOfferingItem(at: index)
                        }
                    )
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 我需要的物品卡片

    private var requestingItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text("我需要".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Button(action: {
                    showRequestingSelector = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加物品".localized)
                    }
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            if requestingItems.isEmpty {
                Text("点击添加你需要的物品".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(requestingItems.enumerated()), id: \.element.itemId) { index, item in
                    TradeItemRowView(
                        item: item,
                        mode: .editable,
                        onRemove: {
                            removeRequestingItem(at: index)
                        }
                    )
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 有效期卡片

    private var expirationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("有效期".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            HStack(spacing: 12) {
                expirationButton(hours: 12, label: "12小时")
                expirationButton(hours: 24, label: "24小时")
                expirationButton(hours: 48, label: "48小时")
                expirationButton(hours: 72, label: "72小时")
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 有效期按钮
    private func expirationButton(hours: Int, label: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                expirationHours = hours
            }
        }) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(expirationHours == hours ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(expirationHours == hours ? ApocalypseTheme.primary : ApocalypseTheme.background)
                .cornerRadius(8)
        }
    }

    // MARK: - 留言卡片

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("留言（可选）".localized)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            TextEditor(text: $message)
                .frame(height: 80)
                .padding(8)
                .background(ApocalypseTheme.background)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )

            Text("\(message.count) / 200")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 发布按钮

    private var publishButton: some View {
        Button(action: createOffer) {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("发布挂单".localized)
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canPublish ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canPublish || isCreating)
        .opacity((!canPublish || isCreating) ? 0.6 : 1.0)
    }

    // MARK: - 计算属性

    /// 是否可以发布
    private var canPublish: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty
    }

    // MARK: - Actions

    /// 添加提供物品
    private func addOfferingItem(itemId: String, quantity: Int) {
        // 检查是否已存在
        if let index = offeringItems.firstIndex(where: { $0.itemId == itemId }) {
            // 更新数量
            offeringItems[index] = TradeItem(
                itemId: itemId,
                quantity: offeringItems[index].quantity + quantity
            )
        } else {
            // 添加新物品
            offeringItems.append(TradeItem(itemId: itemId, quantity: quantity))
        }
    }

    /// 移除提供物品
    private func removeOfferingItem(at index: Int) {
        withAnimation {
            offeringItems.remove(at: index)
        }
    }

    /// 添加需求物品
    private func addRequestingItem(itemId: String, quantity: Int) {
        // 检查是否已存在
        if let index = requestingItems.firstIndex(where: { $0.itemId == itemId }) {
            // 更新数量
            requestingItems[index] = TradeItem(
                itemId: itemId,
                quantity: requestingItems[index].quantity + quantity
            )
        } else {
            // 添加新物品
            requestingItems.append(TradeItem(itemId: itemId, quantity: quantity))
        }
    }

    /// 移除需求物品
    private func removeRequestingItem(at index: Int) {
        withAnimation {
            requestingItems.remove(at: index)
        }
    }

    /// 创建挂单
    private func createOffer() {
        // 验证可以创建
        let (canCreate, error) = tradeManager.canCreateOffer(offeringItems: offeringItems)
        if !canCreate {
            errorMessage = error?.localizedDescription ?? "无法创建挂单"
            showError = true
            return
        }

        isCreating = true

        Task {
            do {
                // 限制留言长度
                let trimmedMessage = String(message.prefix(200))

                _ = try await tradeManager.createOffer(
                    offeringItems: offeringItems,
                    requestingItems: requestingItems,
                    message: trimmedMessage.isEmpty ? nil : trimmedMessage,
                    expiresInHours: expirationHours
                )

                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateOfferView()
        .environmentObject(InventoryManager())
}
