//
//  RatingView.swift
//  new earth lord1
//
//  交易评价视图
//  对已完成的交易进行评分和评语
//

import SwiftUI

struct RatingView: View {
    let history: TradeHistory

    @StateObject private var tradeManager = TradeManager.shared
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    // MARK: - State Properties

    /// 评分（1-5星）
    @State private var rating: Int = 5

    /// 评语
    @State private var comment: String = ""

    /// 提交中状态
    @State private var isSubmitting = false

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
                    VStack(spacing: 24) {
                        // 交易摘要卡片
                        tradeSummaryCard

                        // 评分选择器
                        ratingSelector

                        // 评语输入框
                        commentEditor

                        // 提交按钮
                        submitButton
                    }
                    .padding()
                }
            }
            .navigationTitle("评价交易".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消".localized) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("错误".localized, isPresented: $showError) {
                Button("确定".localized, role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - 交易摘要卡片

    private var tradeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交易摘要".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 交易对象
            HStack {
                Text(isSeller ? "买家".localized : "卖家".localized + ":")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text(tradePartnerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Divider()

            // 物品交换
            VStack(alignment: .leading, spacing: 8) {
                Text("交换物品".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    // 我给出的
                    Label("\(myGaveCount) 件", systemImage: "arrow.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.warning)

                    Text("↔")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    // 我收到的
                    Label("\(myReceivedCount) 件", systemImage: "arrow.left")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                }
            }

            Divider()

            // 完成时间
            HStack {
                Text("完成时间".localized + ":")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text(history.formattedCompletedAt)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 评分选择器

    private var ratingSelector: some View {
        VStack(spacing: 16) {
            Text("请为此次交易评分".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            rating = star
                        }
                    }) {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundColor(star <= rating ? .yellow : ApocalypseTheme.textMuted)
                    }
                }
            }

            Text(ratingDescription)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 评语输入框

    private var commentEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("评语（可选）".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            TextEditor(text: $comment)
                .frame(height: 120)
                .padding(8)
                .background(ApocalypseTheme.background)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )

            Text("\(comment.count) / 200")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 提交按钮

    private var submitButton: some View {
        Button(action: submitRating) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("提交评价".localized)
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(ApocalypseTheme.primary)
            .cornerRadius(12)
        }
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.6 : 1.0)
    }

    // MARK: - 计算属性

    /// 是否为卖家
    private var isSeller: Bool {
        history.sellerId == authManager.currentUser?.id
    }

    /// 交易对象名称
    private var tradePartnerName: String {
        isSeller ? history.buyerUsername : history.sellerUsername
    }

    /// 我给出的物品数量
    private var myGaveCount: Int {
        isSeller ? history.itemsExchanged.sellerGave.count : history.itemsExchanged.buyerGave.count
    }

    /// 我收到的物品数量
    private var myReceivedCount: Int {
        isSeller ? history.itemsExchanged.buyerGave.count : history.itemsExchanged.sellerGave.count
    }

    /// 评分描述
    private var ratingDescription: String {
        switch rating {
        case 1:
            return "非常不满意"
        case 2:
            return "不满意"
        case 3:
            return "一般"
        case 4:
            return "满意"
        case 5:
            return "非常满意"
        default:
            return ""
        }
    }

    // MARK: - Actions

    /// 提交评价
    private func submitRating() {
        // 限制评语长度
        let trimmedComment = String(comment.prefix(200))

        isSubmitting = true

        Task {
            do {
                try await tradeManager.addRating(
                    historyId: history.id,
                    rating: rating,
                    comment: trimmedComment.isEmpty ? nil : trimmedComment
                )

                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let currentUserId = UUID()

    return RatingView(
        history: TradeHistory(
            id: UUID(),
            offerId: UUID(),
            sellerId: currentUserId,
            sellerUsername: "我",
            buyerId: UUID(),
            buyerUsername: "玩家A",
            itemsExchanged: TradeExchangeInfo(
                sellerGave: [
                    TradeItem(itemId: "water", quantity: 5),
                    TradeItem(itemId: "food", quantity: 3)
                ],
                buyerGave: [
                    TradeItem(itemId: "wood", quantity: 10)
                ]
            ),
            completedAt: Date(),
            sellerRating: nil,
            buyerRating: 5,
            sellerComment: nil,
            buyerComment: "很好的卖家"
        )
    )
    .environmentObject(AuthManager())
}
