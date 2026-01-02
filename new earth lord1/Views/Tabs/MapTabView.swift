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

    // MARK: - State Objects

    /// GPS 定位管理器
    @StateObject private var locationManager = LocationManager()

    /// 语言管理器
    @EnvironmentObject private var languageManager: LanguageManager

    // MARK: - State Properties

    /// 用户位置
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示权限提示
    @State private var showPermissionAlert = false

    // MARK: - Body

    var body: some View {
        let _ = languageManager.currentLanguage // 触发语言切换

        return ZStack {
            // 背景地图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser
            )
            .ignoresSafeArea()

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

            // 右下角定位按钮
            VStack {
                Spacer()

                HStack {
                    Spacer()

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
        .id(languageManager.currentLanguage) // 语言切换时重新渲染
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
}
