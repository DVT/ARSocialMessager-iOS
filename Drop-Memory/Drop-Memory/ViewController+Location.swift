//
//  ViewController+Location.swift
//  Drop-Memory
//
//  Created by Divine Dube on 2019/04/04.
//  Copyright © 2019 DVT. All rights reserved.
//

//
//  ViewController+Location.swift
//  Drop-Memory
//
//  Created by Divine Dube on 2019/04/04.
//  Copyright © 2019 DVT. All rights reserved.
//

import CoreLocation
import FirebaseDatabase
import Foundation

extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            // could not get the current location
            print("Error: Could not get access to your current location")
            return
        }
            //latitude
        let lat = String(location.coordinate.latitude)
        let dotIndexLat = lat.firstIndex(of: ".")!
        let latWithDecimals = lat.index(dotIndexLat, offsetBy: 2)
        let latWithDecimalsString = lat[...latWithDecimals]
        
        //longitude
        let log = String(location.coordinate.longitude)
        let dotIndexLog = log.firstIndex(of: ".")!
        let logWithDecimals = log.index(dotIndexLog, offsetBy: 2)
        let logWithDecimalsString = log[...logWithDecimals]
        
        fileName = "Test/\(latWithDecimalsString)|\(logWithDecimalsString)"

       // locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationManager.startUpdatingLocation()
    }
//
//    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
//        let angle = newHeading.trueHeading
//        print("Angle is \(angle)")
//    }
//
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        guard let location = locations.first else {
//            // could not get the current location
//            print("Error: Could not get access to your current location")
//            return
//        }
//        print("Location: \(location)")
//        if fileName.isEmpty { //<<
//            fileName = "Test/\(location.coordinate.latitude)|\(location.coordinate.longitude)" //<<
//        } //<<
//        sendLocationDataToFirebase(coordinate: location.coordinate)
//
////        locationManager.stopUpdatingLocation()
//    }
//
//    func sendLocationDataToFirebase(coordinate: CLLocationCoordinate2D) {
//        // check if a geofence exists then cr
//
//
//        var numberOfItems: UInt = 0
//        var totalNumberOfItems: UInt = 0
//        ref.childByAutoId().observe(DataEventType.value, with: {(snapshot) in
//            let coordinateString = snapshot.value as? String ?? "" // should have used a model
//            if !coordinateString.isEmpty {
//                let currentItemDistanceWithSavedLocation = coordinateString.components(separatedBy: "|")
//                let latitude = currentItemDistanceWithSavedLocation[0]
//                let logitude = currentItemDistanceWithSavedLocation[1]
//
//                let location = CLLocation(latitude: Double(latitude)! , longitude: Double(logitude)!)
//                let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
//
//                let distance = location.distance(from: currentLocation)
//
//                // if the disnce is within 10 meter check if a geofence exists
//                //
//                if distance <= 10 {
//                    self.setRegion(location: currentLocation)
//                    return
//                } else {
//                   numberOfItems += 1
//                   totalNumberOfItems = snapshot.childrenCount
//                }
//
//                // here we knom that there was no matching region and we also send the location for firebase
//                if numberOfItems == totalNumberOfItems {
//                    self.setRegion(location: currentLocation)
//                self.ref.childByAutoId().setValue("\(currentLocation.coordinate.latitude)|\(currentLocation.coordinate.longitude)")
//                }
//            }
//        })
//    }
//
//    func setRegion(location: CLLocation) {
//        let geofenceRegionCenter = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
//        /* Create a region centered on desired location,
//         choose a radius for the region (in meters)
//         choose a unique identifier for that region */
//        let geofenceRegion = CLCircularRegion(center: geofenceRegionCenter,
//                                              radius: 5,
//                                              identifier: "\(location.coordinate.latitude)|\(location.coordinate.longitude)")
//        geofenceRegion.notifyOnEntry = true
//        geofenceRegion.notifyOnExit = true
//        locationManager.startMonitoring(for: geofenceRegion)
//    }
//
//    // called when user Exits a monitored region
//    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
//        if region is CLCircularRegion {
//            // Do what you want if this information
//            self.handleEvent(forRegion: region, exit: false)
//        }
//    }
//
//    // called when user Enters a monitored region
//    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
//        if region is CLCircularRegion {
//            // Do what you want if this information
//            self.handleEvent(forRegion: region, exit: true)
//        }
//    }
//
//    // this gets called when the user enters one of the regions that we have predfinesd
//    func handleEvent(forRegion: CLRegion, exit: Bool) {
//        if exit {
//            fileName = "" //<<
//            locationManager.requestLocation() //<<
//        }
//    }
}

