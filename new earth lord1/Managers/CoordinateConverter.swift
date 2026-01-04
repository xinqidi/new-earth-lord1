//
//  CoordinateConverter.swift
//  new earth lord1
//
//  GPS 坐标转换工具
//  解决中国地区 GPS 偏移问题，将 WGS-84 坐标转换为 GCJ-02 坐标
//

import Foundation
import CoreLocation

/// 坐标转换工具类
/// 用于解决中国地区的 GPS 坐标偏移问题
class CoordinateConverter {

    // MARK: - Constants

    /// 长半轴
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi: Double = 3.1415926535897932384626

    // MARK: - Public Methods

    /// WGS-84 坐标转换为 GCJ-02 坐标（火星坐标系）
    /// - Parameter coordinate: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图使用的坐标）
    static func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境内
        if !isInChina(coordinate) {
            return coordinate
        }

        var dLat = transformLat(coordinate.longitude - 105.0, coordinate.latitude - 35.0)
        var dLon = transformLon(coordinate.longitude - 105.0, coordinate.latitude - 35.0)

        let radLat = coordinate.latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let mgLat = coordinate.latitude + dLat
        let mgLon = coordinate.longitude + dLon

        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }

    /// GCJ-02 坐标转换为 WGS-84 坐标（逆转换）
    /// - Parameter coordinate: GCJ-02 坐标
    /// - Returns: WGS-84 坐标
    static func gcj02ToWgs84(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if !isInChina(coordinate) {
            return coordinate
        }

        var dLat = transformLat(coordinate.longitude - 105.0, coordinate.latitude - 35.0)
        var dLon = transformLon(coordinate.longitude - 105.0, coordinate.latitude - 35.0)

        let radLat = coordinate.latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let latitude = coordinate.latitude - dLat
        let longitude = coordinate.longitude - dLon

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: - Private Methods

    /// 判断坐标是否在中国境内
    /// - Parameter coordinate: 坐标
    /// - Returns: 是否在中国境内
    private static func isInChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 中国大陆范围：纬度 0.8293 ~ 55.8271，经度 72.004 ~ 137.8347
        return coordinate.latitude >= 0.8293 &&
               coordinate.latitude <= 55.8271 &&
               coordinate.longitude >= 72.004 &&
               coordinate.longitude <= 137.8347
    }

    /// 纬度转换
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
