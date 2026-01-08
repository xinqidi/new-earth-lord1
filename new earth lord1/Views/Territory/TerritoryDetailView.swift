//
//  TerritoryDetailView.swift
//  new earth lord1
//
//  领地详情页面
//  显示领地详细信息、地图预览、支持删除
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据
    let territory: Territory

    /// 领地管理器
    let territoryManager: TerritoryManager?

    /// 删除回调
    let onDelete: (() -> Void)?

    // MARK: - State Properties

    /// 是否显示删除确认对话框
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 环境：关闭当前页面
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed Properties

    /// 领地坐标（已转换为 GCJ-02）
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates().map { CoordinateConverter.wgs84ToGcj02($0) }
    }

    /// 地图区域（居中显示领地）
    private var mapRegion: MKCoordinateRegion {
        guard !territoryCoordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        // 计算边界框
        let lats = territoryCoordinates.map { $0.latitude }
        let lons = territoryCoordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreviewSection

                    // 基本信息
                    infoSection

                    // 功能区（未来功能占位）
                    futureFeaturesSection

                    // 危险区域（删除按钮）
                    dangerZoneSection
                }
                .padding()
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭".localized) {
                        dismiss()
                    }
                }
            }
            .alert("确认删除".localized, isPresented: $showDeleteAlert) {
                Button("取消".localized, role: .cancel) { }
                Button("删除".localized, role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("确定要删除这块领地吗？此操作无法撤销。".localized)
            }
        }
    }

    // MARK: - Subviews

    /// 地图预览区域
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("地图预览".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Map(position: .constant(.region(mapRegion))) {
                // 绘制领地多边形
                if !territoryCoordinates.isEmpty {
                    MapPolygon(coordinates: territoryCoordinates)
                        .foregroundStyle(Color.green.opacity(0.3))
                        .stroke(Color.green, lineWidth: 2)
                }
            }
            .frame(height: 300)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5)
        }
    }

    /// 基本信息区域
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基本信息".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 12) {
                // 面积
                InfoRowView(
                    icon: "map.fill",
                    label: "面积".localized,
                    value: territory.formattedArea,
                    color: .blue
                )

                Divider()

                // 边界点数
                InfoRowView(
                    icon: "point.3.connected.trianglepath.dotted",
                    label: "边界点数".localized,
                    value: "\(territory.pointCount ?? 0) 个点",
                    color: .purple
                )

                Divider()

                // 创建时间
                if let createdAt = territory.createdAt {
                    InfoRowView(
                        icon: "clock.fill",
                        label: "创建时间".localized,
                        value: formatDate(createdAt),
                        color: .orange
                    )
                }
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5)
        }
    }

    /// 未来功能区域
    private var futureFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("更多功能".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 12) {
                // 重命名
                FutureFeatureRowView(
                    icon: "pencil",
                    label: "重命名领地".localized,
                    color: .blue
                )

                Divider()

                // 建筑系统
                FutureFeatureRowView(
                    icon: "building.2",
                    label: "建筑系统".localized,
                    color: .green
                )

                Divider()

                // 领地交易
                FutureFeatureRowView(
                    icon: "arrow.left.arrow.right",
                    label: "领地交易".localized,
                    color: .purple
                )
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5)
        }
    }

    /// 危险区域（删除按钮）
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("危险操作".localized)
                .font(.headline)
                .foregroundColor(.red)

            Button(action: {
                showDeleteAlert = true
            }) {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "trash.fill")
                        Text("删除领地".localized)
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
            .disabled(isDeleting)
        }
    }

    // MARK: - Methods

    /// 删除领地
    private func deleteTerritory() async {
        guard let manager = territoryManager else { return }

        isDeleting = true

        let success = await manager.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            // 删除成功，关闭详情页并刷新列表
            dismiss()
            onDelete?()
        } else {
            // 删除失败，可以显示错误提示
            print("❌ [领地详情] 删除失败")
        }
    }

    /// 格式化日期
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "zh_CN")
        return displayFormatter.string(from: date)
    }
}

// MARK: - Info Row View

/// 信息行视图
struct InfoRowView: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)

            Text(label)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

// MARK: - Future Feature Row View

/// 未来功能行视图
struct FutureFeatureRowView: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)

            Text(label)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text("敬请期待".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.textSecondary.opacity(0.2))
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleTerritory = Territory(
        id: "1",
        userId: "user1",
        name: "测试领地",
        path: [
            ["lat": 39.9042, "lon": 116.4074],
            ["lat": 39.9052, "lon": 116.4074],
            ["lat": 39.9052, "lon": 116.4084],
            ["lat": 39.9042, "lon": 116.4084]
        ],
        area: 10000,
        pointCount: 4,
        isActive: true,
        completedAt: nil,
        startedAt: nil,
        createdAt: "2025-01-07T12:00:00Z"
    )

    return TerritoryDetailView(
        territory: sampleTerritory,
        territoryManager: nil,
        onDelete: nil
    )
}
