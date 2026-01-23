import MapKit

/// 建筑标注
class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        return building.buildingName
    }

    var subtitle: String? {
        return building.status.displayName
    }

    init(building: PlayerBuilding, coordinate: CLLocationCoordinate2D) {
        self.building = building
        self.coordinate = coordinate
        super.init()
    }
}
