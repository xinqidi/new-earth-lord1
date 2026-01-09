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

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告横幅
    @State private var showCollisionWarning = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态

    /// 是否正在探索
    @State private var isExploring = false

    /// 是否显示探索结果
    @State private var showExplorationResult = false

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

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
            }

            // 右上角辅助按钮（确认登记/上传中）
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 16) {
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
                    }
                    .padding()
                    .padding(.bottom, 100) // 给底部按钮留出空间
                }
            }

            // 底部三个按钮（水平排列）
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    // 左侧：开始圈地按钮
                    Button(action: {
                        togglePathTracking()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                                .font(.system(size: 22))
                            Text(locationManager.isTracking ? "停止圈地".localized : "开始圈地".localized)
                                .font(.system(size: 12, weight: .semibold))
                            if locationManager.isTracking && !locationManager.pathCoordinates.isEmpty {
                                Text("(\(locationManager.pathCoordinates.count))")
                                    .font(.system(size: 10))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                    }
                    .disabled(isExploring)

                    // 中间：定位按钮
                    Button(action: {
                        requestLocationAndCenter()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 22))
                            Text("定位".localized)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                    }
                    .disabled(isExploring)

                    // 右侧：探索按钮
                    Button(action: {
                        startExploration()
                    }) {
                        VStack(spacing: 4) {
                            if isExploring {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "binoculars.fill")
                                    .font(.system(size: 22))
                            }
                            Text(isExploring ? "探索中...".localized : "探索".localized)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isExploring ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                    }
                    .disabled(isExploring)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
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
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(stats: MockExplorationData.mockExplorationStats)
        }
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

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
        .zIndex(997) // 低于上传横幅
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
            stopCollisionMonitoring()  // Day 19: 完全停止，清除警告
            locationManager.stopPathTracking()
            print("⏸️ [地图页] 停止圈地")
        } else {
            // 开始追踪 - Day 19: 带碰撞检测
            if locationManager.isAuthorized {
                startClaimingWithCollisionCheck()
            } else {
                // 未授权，请求权限
                print("⚠️ [地图页] 未授权定位，无法开始圈地")
                locationManager.requestPermission()
            }
        }
    }

    /// 开始探索
    private func startExploration() {
        print("🔍 [地图页] 开始探索")

        // 设置为探索中状态
        isExploring = true

        // 模拟1.5秒的搜索过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 探索完成
            isExploring = false
            // 显示探索结果
            showExplorationResult = true
            print("✅ [地图页] 探索完成，显示结果")
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let manager = territoryManager,
              let userId = authManager.currentUser?.id.uuidString else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = manager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        locationManager.startPathTracking()
        startCollisionMonitoring()
        print("🚀 [地图页] 开始圈地")
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let manager = territoryManager,
              let userId = authManager.currentUser?.id.uuidString else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = manager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
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
                stopCollisionMonitoring()  // Day 19: 完全停止，清除警告
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
