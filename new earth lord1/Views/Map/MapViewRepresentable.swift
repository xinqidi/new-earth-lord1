//
//  MapViewRepresentable.swift
//  new earth lord1
//
//  MKMapView 的 SwiftUI 包装器
//  负责显示地图、应用末世滤镜、处理用户位置更新和自动居中
//

import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
/// 将 UIKit 的 MKMapView 桥接到 SwiftUI，支持末世风格滤镜和自动居中
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    // MARK: - UIViewRepresentable Methods

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid // 卫星图 + 道路标签（末世风格）
        mapView.pointOfInterestFilter = .excludingAll // 隐藏所有 POI（星巴克、麦当劳等）
        mapView.showsBuildings = false // 隐藏 3D 建筑
        mapView.showsUserLocation = true // 显示用户位置蓝点（关键！）
        mapView.isZoomEnabled = true // 允许双指缩放
        mapView.isScrollEnabled = true // 允许拖动
        mapView.isPitchEnabled = false // 禁用 3D 视角倾斜
        mapView.isRotateEnabled = false // 禁用旋转

        // 设置代理（关键！没有这个 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜
        applyApocalypseFilter(to: mapView)

        print("🗺️ [地图] MKMapView 创建完成")

        return mapView
    }

    /// 更新 MKMapView（空实现即可）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 地图更新由 Coordinator 处理
    }

    /// 创建 Coordinator（处理地图代理事件）
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Apocalypse Filter

    /// 应用末世滤镜效果
    /// 降低饱和度、添加棕褐色调，营造废土泛黄效果
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey) // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey) // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey) // 泛黄强度

        // 应用滤镜到地图图层
        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
            print("🎨 [地图] 末世滤镜已应用")
        }
    }

    // MARK: - Coordinator

    /// 地图代理协调器
    /// 处理地图事件，负责首次自动居中逻辑
    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: MapViewRepresentable

        /// 首次居中标志（防止重复居中，不影响用户手动拖动）
        private var hasInitialCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        /// 负责首次自动居中地图到用户位置
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else {
                print("⚠️ [地图] 用户位置无效")
                return
            }

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            print("📍 [地图] 用户位置更新: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else {
                return // 已经居中过了，不再重复居中（允许用户手动拖动）
            }

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }

            print("🎯 [地图] 首次自动居中完成")
        }

        /// 地图区域改变时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里记录用户拖动地图的行为
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("✅ [地图] 地图加载完成")
        }
    }
}
