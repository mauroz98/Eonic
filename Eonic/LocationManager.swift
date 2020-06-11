//
//  LocationManager.swift
//  Eonic
//
//  Created by Yuri Spaziani on 04/03/2020.
//  Copyright © 2020 Antonio Ferraioli. All rights reserved.
//

import Foundation
import CoreLocation

let locationManager = LocationManager.getLocationManager()

class LocationManager: NSObject, CLLocationManagerDelegate{
    
    let locationManager = CLLocationManager()
    static let singleton = LocationManager()
    static func getLocationManager() -> LocationManager{
        return .singleton
    }
    
    private override init(){
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        DispatchQueue.main.async {
            self.locationManager.startUpdatingLocation()
        }
    }
}
