//
//  MapTabView.swift
//  new earth lord1
//
//  地图标签页
//  显示末日世界地图，支持定位、探索和圈占领地
//

import SwiftUI
import MapKit

struct MapTabView: View {

    // MARK: - Environment Objects

    /// GPS 定位管理器
    @EnvironmentObject private var locationManager: LocationManager

    /// 语言管理器
    @EnvironmentObject private var languageManager: LanguageManager

    /// 认证管理器
    @EnvironmentObject private var authManager: AuthManager

    // MARK: - State Properties

    /// 用户位置
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示权限提示
    @State private var showPermissionAlert = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 是否正在上传
    @State private var isUploading = false

    /// 上传成功消息
    @State private var uploadSuccessMessage: String?

    /// 上传错误消息
    @State private var uploadErrorMessage: String?

    /// 领地管理器
    @State private var territoryManager: TerritoryManager?

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    // MARK: - Body

    var body: some View {
        let _ = languageManager.currentLanguage // 触发语言切换

        return ZStack {
            // 背景地图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                currentUserId: authManager.currentUser?.id.uuidString
            )
            .edgesIgnoringSafeArea(.top) // 只忽略顶部安全区域，保留底部给标签栏

            // 权限被拒绝时的提示卡片
            if locationManager.isDenied {
                VStack {
                    Spacer()

                    // 提示卡片
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 50))
                            .foregroundColor(ApocalypseTheme.warning)

                        Text("定位权限被拒绝".localized)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("《地球新主》需要获取您的位置来显示您在末日世界中的坐标，帮助您探索和圈定领地。".localized)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // 前往设置按钮
                        Button(action: {
                            openSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("前往设置".localized)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.3), radius: 20)
                    .padding()

                    Spacer()
                }
            }

            // 速度警告横幅（使用 ZStack 确保在最上层）
            if let warning = locationManager.speedWarning {
                VStack {
                    HStack {
                        Image(systemName: locationManager.isOverSpeed ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)

                        Text(warning)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(locationManager.isOverSpeed ? Color.red : Color.orange)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.5), radius: 15)
                    .padding(.horizontal, 16)
                    .padding(.top, 60) // 避免遮挡状态栏

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: locationManager.speedWarning)
                .zIndex(1000) // 确保在最上层
            }

            // 验证结果横幅（根据验证结果显示成功或失败）
            if showValidationBanner {
                VStack {
                    validationResultBanner
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showValidationBanner)
                .zIndex(999) // 低于速度警告
            }

            // 上传成功横幅
            if let successMessage = uploadSuccessMessage {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                        Text(successMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .padding(.top, 50)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: uploadSuccessMessage)
                .zIndex(998)
            }

            // 上传失败横幅
            if let errorMessage = uploadErrorMessage {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                        Text(errorMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .padding(.top, 50)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: uploadErrorMessage)
                .zIndex(998)
            }

            // 右下角按钮组
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 16) {
                        // 圈地按钮
                        Button(action: {
                            togglePathTracking()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                                    .font(.system(size: 16))
                                Text(locationManager.isTracking ? "停止圈地".localized : "开始圈地".localized)
                                    .font(.system(size: 14, weight: .semibold))
                                if locationManager.isTracking && !locationManager.pathCoordinates.isEmpty {
                                    Text("(\(locationManager.pathCoordinates.count))")
                                        .font(.system(size: 12))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.3), radius: 10)
                        }

                        // 确认登记按钮（仅在验证通过时显示）
                        if locationManager.territoryValidationPassed && !isUploading {
                            Button(action: {
                                Task {
                                    await uploadCurrentTerritory()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                    Text("确认登记领地".localized)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.3), radius: 10)
                            }
                        }

                        // 上传中指示器
                        if isUploading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("上传中...".localized)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.3), radius: 10)
                        }

                        // 定位按钮
                        Button(action: {
                            requestLocationAndCenter()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding()
                                .background(ApocalypseTheme.primary)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                    }
                    .padding()
                }
            }

            // 左上角坐标显示（仅在有位置时显示）
            if let location = userLocation {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前坐标".localized)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("纬度: \(String(format: "%.6f", location.latitude))")
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("经度: \(String(format: "%.6f", location.longitude))")
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }
                        .padding()
                        .background(ApocalypseTheme.cardBackground.opacity(0.9))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 5)

                        Spacer()
                    }
                    .padding()

                    Spacer()
                }
            }
        }
        .onAppear {
            requestLocationPermission()
            // 初始化 TerritoryManager
            if territoryManager == nil {
                territoryManager = TerritoryManager(supabase: authManager.supabase)
            }
            // 加载领地
            Task {
                await loadTerritories()
            }
        }
        .onReceive(locationManager.$isPathClosed) { isClosed in
            // 当检测到闭环时，延迟显示验证横幅
            if isClosed {
                // 延迟 0.1 秒，确保验证逻辑已完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 5 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
        .id(languageManager.currentLanguage) // 语言切换时重新渲染
    }

    // MARK: - Computed Properties

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)
    }

    // MARK: - Private Methods

    /// 请求定位权限
    private func requestLocationPermission() {
        print("🗺️ [地图页] 请求定位权限")

        switch locationManager.authorizationStatus {
        case .notDetermined:
            // 首次请求权限
            locationManager.requestPermission()

        case .authorizedWhenInUse, .authorizedAlways:
            // 已授权，开始定位
            locationManager.startUpdatingLocation()

        case .denied, .restricted:
            // 被拒绝，显示提示
            print("⚠️ [地图页] 定位权限被拒绝")

        @unknown default:
            break
        }
    }

    /// 请求定位并居中
    private func requestLocationAndCenter() {
        if locationManager.isAuthorized {
            // 已授权，重置居中标志并开始定位
            hasLocatedUser = false
            locationManager.startUpdatingLocation()
        } else if locationManager.isDenied {
            // 被拒绝，提示前往设置
            openSettings()
        } else {
            // 未确定，请求权限
            locationManager.requestPermission()
        }
    }

    /// 切换路径追踪状态
    private func togglePathTracking() {
        if locationManager.isTracking {
            // 停止追踪
            locationManager.stopPathTracking()
            print("⏸️ [地图页] 停止圈地")
        } else {
            // 开始追踪
            if locationManager.isAuthorized {
                locationManager.startPathTracking()
                print("🚀 [地图页] 开始圈地")
            } else {
                // 未授权，请求权限
                print("⚠️ [地图页] 未授权定位，无法开始圈地")
                locationManager.requestPermission()
            }
        }
    }

    /// 加载所有领地
    private func loadTerritories() async {
        guard let manager = territoryManager else { return }

        do {
            territories = try await manager.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
            print("✅ [地图页] 加载了 \(territories.count) 个领地")
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
            print("❌ [地图页] 加载领地失败: \(error.localizedDescription)")
        }
    }

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            await MainActor.run {
                uploadErrorMessage = "领地验证未通过，无法上传".localized
            }
            // 3 秒后自动隐藏错误消息
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                uploadErrorMessage = nil
            }
            return
        }

        // 检查用户是否已登录
        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                uploadErrorMessage = "请先登录".localized
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                uploadErrorMessage = nil
            }
            return
        }

        // 检查 territoryManager 是否已初始化
        guard let manager = territoryManager else {
            await MainActor.run {
                uploadErrorMessage = "系统错误，请重试".localized
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                uploadErrorMessage = nil
            }
            return
        }

        // 保存数据副本（防止上传过程中被清空）
        let coordinates = locationManager.pathCoordinates
        let area = locationManager.calculatedArea
        let startTime = locationManager.trackingStartTime ?? Date()

        // 显示上传中
        await MainActor.run {
            isUploading = true
            uploadErrorMessage = nil
            uploadSuccessMessage = nil
        }

        do {
            // 上传领地
            try await manager.uploadTerritory(
                userId: currentUser.id,
                coordinates: coordinates,
                area: area,
                startTime: startTime
            )

            // 上传成功
            await MainActor.run {
                isUploading = false
                uploadSuccessMessage = "领地登记成功！".localized

                // ⚠️ 关键：上传成功后必须停止追踪！
                locationManager.stopPathTracking()

                print("✅ [地图页] 领地上传成功，已停止追踪")
            }

            // 刷新领地列表
            await loadTerritories()

            // 5 秒后自动隐藏成功消息
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                uploadSuccessMessage = nil
            }

        } catch {
            // 上传失败
            await MainActor.run {
                isUploading = false
                uploadErrorMessage = "上传失败: \(error.localizedDescription)".localized
                print("❌ [地图页] 领地上传失败: \(error.localizedDescription)")
            }

            // 5 秒后自动隐藏错误消息
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                uploadErrorMessage = nil
            }
        }
    }

    /// 打开系统设置
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
        .environmentObject(LanguageManager.shared)
        .environmentObject(LocationManager())
}
