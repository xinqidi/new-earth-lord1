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

    // MARK: - State Properties

    /// 用户位置
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示权限提示
    @State private var showPermissionAlert = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

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
                isPathClosed: locationManager.isPathClosed
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
