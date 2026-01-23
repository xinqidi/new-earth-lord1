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

    /// 追踪路径坐标数组（WGS-84）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否已闭合
    var isPathClosed: Bool

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID（用于区分我的领地和他人领地）
    var currentUserId: String?

    /// 附近POI列表
    var nearbyPOIs: [POI]

    /// 玩家建筑列表
    var playerBuildings: [PlayerBuilding]

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

    /// 更新 MKMapView
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新追踪路径
        context.coordinator.updateTrackingPath(on: uiView, path: trackingPath, isClosed: isPathClosed)

        // 绘制领地
        context.coordinator.drawTerritories(on: uiView, territories: territories, currentUserId: currentUserId)

        // 绘制POI标注
        context.coordinator.updatePOIAnnotations(on: uiView, pois: nearbyPOIs)

        // 更新建筑标注
        context.coordinator.updateBuildingAnnotations(on: uiView, buildings: playerBuildings)
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

        /// 路径是否已闭合（用于渲染时判断颜色）
        private var isPathClosed = false

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

        // MARK: - Territory Display

        /// 绘制领地多边形
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - territories: 领地列表
        ///   - currentUserId: 当前用户 ID
        func drawTerritories(on mapView: MKMapView, territories: [Territory], currentUserId: String?) {
            // 移除旧的领地多边形（保留路径轨迹）
            let territoryOverlays = mapView.overlays.filter { overlay in
                if let polygon = overlay as? MKPolygon {
                    return polygon.title == "mine" || polygon.title == "others"
                }
                return false
            }
            mapView.removeOverlays(territoryOverlays)

            // 绘制每个领地
            for territory in territories {
                var coords = territory.toCoordinates()

                // ⚠️ 中国大陆需要坐标转换 WGS-84 → GCJ-02
                coords = coords.map { coord in
                    CoordinateConverter.wgs84ToGcj02(coord)
                }

                guard coords.count >= 3 else { continue }

                let polygon = MKPolygon(coordinates: coords, count: coords.count)

                // ⚠️ 关键：比较 userId 时必须统一大小写！
                // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
                // 如果不转换，会导致自己的领地显示为橙色
                let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
                polygon.title = isMine ? "mine" : "others"

                mapView.addOverlay(polygon, level: .aboveRoads)
            }

            print("🗺️ [领地显示] 绘制了 \(territories.count) 个领地")
        }

        // MARK: - Path Tracking

        /// 更新追踪路径
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - path: 路径坐标数组（WGS-84）
        ///   - isClosed: 路径是否已闭合
        func updateTrackingPath(on mapView: MKMapView, path: [CLLocationCoordinate2D], isClosed: Bool) {
            // 保存闭合状态（用于渲染）
            self.isPathClosed = isClosed

            // 移除旧的轨迹和多边形
            let oldOverlays = mapView.overlays.filter { $0 is MKPolyline || $0 is MKPolygon }
            mapView.removeOverlays(oldOverlays)

            // 如果没有路径点，直接返回
            guard path.count >= 2 else { return }

            // 转换坐标：WGS-84 → GCJ-02（解决中国 GPS 偏移问题）
            var convertedPath = path.map { CoordinateConverter.wgs84ToGcj02($0) }

            // ⚠️ 如果路径已闭合，添加一条线段连接到起点（视觉闭合）
            if isClosed && path.count >= 3, let firstPoint = convertedPath.first {
                convertedPath.append(firstPoint)
            }

            // 创建轨迹线
            let polyline = MKPolyline(coordinates: convertedPath, count: convertedPath.count)
            mapView.addOverlay(polyline)

            // 如果路径已闭合，创建多边形填充
            if isClosed && path.count >= 3 {
                // 多边形使用原始路径（不需要手动闭合）
                let originalConverted = path.map { CoordinateConverter.wgs84ToGcj02($0) }
                let polygon = MKPolygon(coordinates: originalConverted, count: originalConverted.count)
                mapView.addOverlay(polygon)
                print("🟢 [轨迹] 路径已闭合，添加多边形填充")
            }

            print("🛤️ [轨迹] 更新轨迹，共 \(path.count) 个点，闭合状态: \(isClosed)")
        }

        /// ⭐ 关键方法：渲染轨迹线和多边形（必须实现，否则不显示！）
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - overlay: 覆盖物（轨迹线或多边形）
        /// - Returns: 渲染器
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 渲染轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // 根据闭合状态选择颜色：闭合 = 绿色，未闭合 = 青色
                renderer.strokeColor = isPathClosed ? UIColor.systemGreen : UIColor.cyan
                renderer.lineWidth = 5 // 线宽 5pt
                renderer.lineCap = .round // 圆头
                return renderer
            }

            // 渲染多边形填充
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据 title 区分领地类型
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth = 2.0
                } else {
                    // 当前追踪的多边形（无 title）：绿色，无边框
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = .clear // 不绘制边框（轨迹线已经绘制）
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - POI Annotations

        /// 更新POI标注
        func updatePOIAnnotations(on mapView: MKMapView, pois: [POI]) {
            // 移除旧的POI标注
            let existingPOIAnnotations = mapView.annotations.filter { $0 is POIAnnotation }
            mapView.removeAnnotations(existingPOIAnnotations)

            // 如果没有POI，直接返回
            guard !pois.isEmpty else { return }

            // 添加新的POI标注
            for poi in pois {
                // ⚠️ 注意：MKLocalSearch返回的坐标在中国已经是GCJ-02格式
                // 不需要再次转换，直接使用原始坐标
                let annotation = POIAnnotation(poi: poi, coordinate: poi.coordinate)
                mapView.addAnnotation(annotation)
            }

            print("📍 [POI] 更新了 \(pois.count) 个POI标注（使用原始坐标，无需转换）")
        }

        // MARK: - Building Annotations

        /// 更新建筑标注
        func updateBuildingAnnotations(on mapView: MKMapView, buildings: [PlayerBuilding]) {
            // 移除旧的建筑标注
            let existingBuildingAnnotations = mapView.annotations.filter { $0 is BuildingAnnotation }
            mapView.removeAnnotations(existingBuildingAnnotations)

            // 如果没有建筑，直接返回
            guard !buildings.isEmpty else { return }

            // 添加新的建筑标注
            for building in buildings {
                guard let lat = building.locationLat,
                      let lon = building.locationLon else { continue }

                // ⚠️ 建筑坐标存储为WGS-84，显示时需要转换为GCJ-02
                let wgs84Coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let gcj02Coord = CoordinateConverter.wgs84ToGcj02(wgs84Coord)
                let annotation = BuildingAnnotation(building: building, coordinate: gcj02Coord)
                mapView.addAnnotation(annotation)
            }

            print("🏗️ [建筑标注] 更新了 \(buildings.count) 个建筑标注（已转换坐标）")
        }

        /// POI标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置不需要自定义
            if annotation is MKUserLocation {
                return nil
            }

            // 建筑标注
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "BuildingAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = buildingAnnotation
                }

                // 根据建筑状态设置样式
                switch buildingAnnotation.building.status {
                case .constructing:
                    annotationView?.markerTintColor = .systemBlue
                    annotationView?.glyphImage = UIImage(systemName: "hammer.fill")
                case .active:
                    annotationView?.markerTintColor = .systemGreen
                    annotationView?.glyphImage = UIImage(systemName: "building.2.fill")
                }

                return annotationView
            }

            // POI标注
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = poiAnnotation
                }

                // 根据POI类型设置样式
                annotationView?.markerTintColor = poiAnnotation.markerColor
                annotationView?.glyphImage = UIImage(systemName: poiAnnotation.iconName)

                // 已搜刮的POI显示为灰色
                if poiAnnotation.poi.status == .looted {
                    annotationView?.markerTintColor = .gray
                    annotationView?.alpha = 0.6
                } else {
                    annotationView?.alpha = 1.0
                }

                return annotationView
            }

            return nil
        }
    }
}

// MARK: - POI Annotation Class

/// POI标注类
class POIAnnotation: NSObject, MKAnnotation {
    let poi: POI
    let coordinate: CLLocationCoordinate2D

    var title: String? {
        return poi.name
    }

    var subtitle: String? {
        return poi.type.rawValue
    }

    init(poi: POI, coordinate: CLLocationCoordinate2D) {
        self.poi = poi
        self.coordinate = coordinate
        super.init()
    }

    /// 标注颜色
    var markerColor: UIColor {
        switch poi.type {
        case .hospital:
            return .systemRed
        case .supermarket:
            return .systemGreen
        case .pharmacy:
            return .systemBlue
        case .gasStation:
            return .systemOrange
        case .factory:
            return .systemGray
        case .warehouse:
            return .brown
        case .school:
            return .systemPurple
        }
    }

    /// 图标名称
    var iconName: String {
        switch poi.type {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .factory:
            return "gearshape.2.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .school:
            return "book.fill"
        }
    }
}
