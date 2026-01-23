import SwiftUI
import MapKit

/// 领地地图视图
/// 专用于TerritoryDetailView，显示领地多边形和建筑标注
struct TerritoryMapView: View {
    let territory: Territory
    let buildings: [PlayerBuilding]
    let onBuildingTap: ((PlayerBuilding) -> Void)?

    var body: some View {
        TerritoryMapContainer(
            territory: territory,
            buildings: buildings,
            onBuildingTap: onBuildingTap
        )
    }
}

// MARK: - TerritoryMapContainer

private struct TerritoryMapContainer: UIViewRepresentable {
    let territory: Territory
    let buildings: [PlayerBuilding]
    let onBuildingTap: ((PlayerBuilding) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false

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

        // 显示建筑标注
        context.coordinator.updateBuildingAnnotations(mapView)

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
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapContainer
        var hasSetInitialRegion: Bool = false
        private var polygonOverlay: MKPolygon?

        init(_ parent: TerritoryMapContainer) {
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

        // MARK: - Update Building Annotations

        func updateBuildingAnnotations(_ mapView: MKMapView) {
            // 移除旧的建筑标注
            let oldAnnotations = mapView.annotations.filter { $0 is BuildingAnnotation }
            mapView.removeAnnotations(oldAnnotations)

            // 添加新的建筑标注
            for building in parent.buildings {
                guard let lat = building.locationLat,
                      let lon = building.locationLon else { continue }

                // ⚠️ 建筑坐标存储为WGS-84，显示时需要转换为GCJ-02
                let wgs84Coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let gcj02Coord = CoordinateConverter.wgs84ToGcj02(wgs84Coord)
                let annotation = BuildingAnnotation(building: building, coordinate: gcj02Coord)
                mapView.addAnnotation(annotation)
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
            // 用户位置
            if annotation is MKUserLocation {
                return nil
            }

            // 建筑标注
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
                    view.glyphImage = UIImage(systemName: "building.2.fill")
                }

                return view
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // 处理建筑标注点击
            if let buildingAnnotation = view.annotation as? BuildingAnnotation {
                parent.onBuildingTap?(buildingAnnotation.building)
            }
        }
    }
}

#Preview {
    TerritoryMapView(
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
        buildings: [],
        onBuildingTap: nil
    )
}
