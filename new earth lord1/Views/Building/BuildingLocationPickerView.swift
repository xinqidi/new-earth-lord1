import SwiftUI
import MapKit
import Supabase

/// 建筑位置选择器视图
/// 显示领地地图、多边形和已有建筑，允许用户点击选择建造位置
struct BuildingLocationPickerView: View {
    let territory: Territory
    let territoryManager: TerritoryManager
    let existingBuildings: [PlayerBuilding]
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            MapViewContainer(
                territory: territory,
                territoryManager: territoryManager,
                existingBuildings: existingBuildings,
                onLocationSelected: onLocationSelected
            )
            .ignoresSafeArea()
            .navigationTitle("选择建造位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - MapViewContainer

private struct MapViewContainer: UIViewRepresentable {
    let territory: Territory
    let territoryManager: TerritoryManager
    let existingBuildings: [PlayerBuilding]
    let onLocationSelected: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.delegate = context.coordinator

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        // 首次创建时立即设置地图区域到领地位置
        let region = calculateRegion()
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新 Coordinator 的引用
        context.coordinator.parent = self

        // 绘制领地多边形
        context.coordinator.drawTerritoryPolygon(mapView)

        // 显示已有建筑
        context.coordinator.drawExistingBuildings(mapView)

        // 只在首次时设置区域（使用标志位判断）
        if !context.coordinator.hasSetInitialRegion {
            let region = calculateRegion()
            mapView.setRegion(region, animated: false)
            context.coordinator.hasSetInitialRegion = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Calculate Region

    private func calculateRegion() -> MKCoordinateRegion {
        let coords = territory.toCoordinates()
        guard !coords.isEmpty else {
            // 如果没有坐标，使用默认位置（北京）
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
        }

        // ⚠️ 转换为GCJ-02坐标系（与地图显示一致）
        let gcj02Coords = coords.map { CoordinateConverter.wgs84ToGcj02($0) }

        // 计算边界框
        var minLat = gcj02Coords[0].latitude
        var maxLat = gcj02Coords[0].latitude
        var minLon = gcj02Coords[0].longitude
        var maxLon = gcj02Coords[0].longitude

        for coord in gcj02Coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,  // 增加一些边距
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewContainer
        var hasSetInitialRegion: Bool = false

        private var polygonOverlay: MKPolygon?

        init(_ parent: MapViewContainer) {
            self.parent = parent
        }

        // MARK: - Draw Territory Polygon

        func drawTerritoryPolygon(_ mapView: MKMapView) {
            // 移除旧的多边形
            if let oldPolygon = polygonOverlay {
                mapView.removeOverlay(oldPolygon)
            }

            // 添加新的多边形
            let coords = parent.territory.toCoordinates()
            guard !coords.isEmpty else { return }

            // ⚠️ 领地坐标存储为WGS-84，显示时需要转换为GCJ-02
            var coordinates = coords.map { CoordinateConverter.wgs84ToGcj02($0) }
            let polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count)
            polygonOverlay = polygon
            mapView.addOverlay(polygon)
        }

        // MARK: - Draw Existing Buildings

        func drawExistingBuildings(_ mapView: MKMapView) {
            // 移除旧的建筑标注
            let oldAnnotations = mapView.annotations.filter { $0 is BuildingAnnotation }
            mapView.removeAnnotations(oldAnnotations)

            // 添加新的建筑标注
            for building in parent.existingBuildings {
                guard let lat = building.locationLat,
                      let lon = building.locationLon else { continue }

                // ⚠️ 建筑坐标存储为WGS-84，显示时需要转换为GCJ-02
                let wgs84Coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let gcj02Coord = CoordinateConverter.wgs84ToGcj02(wgs84Coord)
                let annotation = BuildingAnnotation(building: building, coordinate: gcj02Coord)
                mapView.addAnnotation(annotation)
            }
        }

        // MARK: - Handle Tap

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let gcj02Coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // ⚠️ 验证点在领地内
            // 领地坐标是WGS-84，需要转换为GCJ-02来与地图点击坐标比较
            let wgs84Coords = parent.territory.toCoordinates()
            let gcj02Coords = wgs84Coords.map { CoordinateConverter.wgs84ToGcj02($0) }
            let isInside = parent.territoryManager.isPointInPolygon(
                point: gcj02Coordinate,
                polygon: gcj02Coords
            )

            if isInside {
                // 添加选择标注（使用GCJ-02坐标显示在地图上）
                let oldSelections = mapView.annotations.filter { $0 is SelectionAnnotation }
                mapView.removeAnnotations(oldSelections)

                let annotation = SelectionAnnotation(coordinate: gcj02Coordinate)
                mapView.addAnnotation(annotation)

                // ⚠️ 回调时转换回WGS-84格式保存到数据库
                let wgs84Coordinate = CoordinateConverter.gcj02ToWgs84(gcj02Coordinate)
                parent.onLocationSelected(wgs84Coordinate)

                print("✅ [位置选择] 已选择位置: GCJ-02(\(gcj02Coordinate.latitude), \(gcj02Coordinate.longitude)) → WGS-84(\(wgs84Coordinate.latitude), \(wgs84Coordinate.longitude))")
            } else {
                print("❌ [位置选择] 位置不在领地内")

                // 显示提示（可选）
                let alert = UIAlertController(
                    title: "位置无效",
                    message: "请在领地范围内选择建造位置",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default))

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(alert, animated: true)
                }
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = .systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = .systemGreen
                renderer.lineWidth = 2.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 处理建筑标注
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "BuildingAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                view.annotation = annotation
                view.canShowCallout = true

                // 根据建筑状态设置颜色
                switch buildingAnnotation.building.status {
                case .constructing:
                    view.markerTintColor = .systemBlue
                    view.glyphImage = UIImage(systemName: "hammer.fill")
                case .active:
                    view.markerTintColor = .systemGreen
                    view.glyphImage = UIImage(systemName: "checkmark.circle.fill")
                }

                return view
            }

            // 处理选择标注
            if annotation is SelectionAnnotation {
                let identifier = "SelectionAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                view.annotation = annotation
                view.markerTintColor = .systemOrange
                view.glyphImage = UIImage(systemName: "mappin.circle.fill")

                return view
            }

            return nil
        }
    }
}

#Preview {
    let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://ipvkhcrgbbcccwiwlofd.supabase.co")!,
        supabaseKey: "sb_publishable_DCfb2P7IEr46I6jX-Wu_3g_Es4DTHEJ"
    )
    let territoryManager = TerritoryManager(supabase: supabase)

    BuildingLocationPickerView(
        territory: Territory(
            id: "test",
            userId: "test-user",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41]
            ],
            area: 10000,
            pointCount: 4,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2025-01-22T12:00:00Z"
        ),
        territoryManager: territoryManager,
        existingBuildings: [],
        onLocationSelected: { _ in },
        onCancel: {}
    )
}
