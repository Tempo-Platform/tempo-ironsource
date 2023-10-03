//
//  TempoLocation.swift
//  TempoSDK
//
//  Created by Stephen Baker on 3/10/2023.
//

import Foundation


import CoreLocation

class TempoLocation: NSObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    var location: CLLocation?

    override init() {
        super.init()
        if #available(iOS 14.0, *) {
            locationManager.delegate = self
            //        locationManager.requestWhenInUseAuthorization()
            //        locationManager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    public func requestLocationConsent() {
        locationManager.requestWhenInUseAuthorization()
        // locationManager.startUpdatingLocation() TODO: what dis do?
    }

    private func getLocationAuthorisationStatus() -> CLAuthorizationStatus {
        var locationAuthorizationStatus : CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            locationAuthorizationStatus =  locationManager.authorizationStatus
        } else {
            // Fallback for earlier versions
            locationAuthorizationStatus = CLLocationManager.authorizationStatus()
        }
        return locationAuthorizationStatus
    }
    
    public func checkLocationServicesConsent(
        completion: @escaping (Constants.LocationConsent, Bool, Float?, String?) -> Void,
        isInterstitial: Bool,
        cpmFloor: Float?,
        placementId: String?) {
            
            print("💥💥💥💥💥💥 555")
            
        // CLLocationManager.authorizationStatus can cause UI unresponsiveness if invoked on the main thread.
        DispatchQueue.global().async {
            
            // Make sure location servics are available
            if CLLocationManager.locationServicesEnabled() {
                
                // get authorisation status
                let authStatus = self.getLocationAuthorisationStatus()
                
                switch (authStatus) {
                case .authorizedAlways, .authorizedWhenInUse:
                    print("Access - always or authorizedWhenInUse")
                    if #available(iOS 14.0, *) {
                        // iOS 14 intro precise/general options
                        if self.locationManager.accuracyAuthorization == .reducedAccuracy {
                            completion(Constants.LocationConsent.GENERAL, isInterstitial, cpmFloor, placementId)
                            return
                        } else {
                            completion(Constants.LocationConsent.PRECISE, isInterstitial, cpmFloor, placementId)
                            return
                        }
                    } else {
                        // Pre-iOS 14 considered precise
                        completion(Constants.LocationConsent.PRECISE, isInterstitial, cpmFloor, placementId)
                        return
                    }
                case .restricted, .denied:
                    print("No access - restricted or denied")
                case .notDetermined:
                    print("No access - notDetermined")
                @unknown default:
                    print("Unknown authorization status")
                }
            } else {
                print("Location services not enabled")
            }
            
            // If we reach here = Constants.LocationConsent.None
            completion(Constants.LocationConsent.NONE, isInterstitial, cpmFloor, placementId)
        }
    }

    



    
    
    
//    public func hasLocationServicesConsent() -> Constants.LocationConsent {
//        
//        var hasConsent: Bool
//        
//        if CLLocationManager.locationServicesEnabled() {
//            switch CLLocationManager.authorizationStatus() {
//            case .authorizedAlways:
//                print("Access - always ")
//                hasConsent = true
//                break
//            case  .authorizedWhenInUse:
//                print("Access - authorizedWhenInUse ")
//                hasConsent = true
//                break
//            case .restricted:
//                hasConsent = false
//                print("No access - restricted")
//                break
//            case .denied:
//                hasConsent = false
//                print("No access - denied")
//                break
//            case .notDetermined:
//                fallthrough
//            default:
//                hasConsent = false
//                print("No access - notDetermined")
//                break
//            }
//            
//            if(hasConsent) {
//                // Determine precise/general
//                var lm: CLLocationManager?
//                if #available(iOS 14.0, *) {
//                    if let accuracyStatus = lm?.accuracyAuthorization {
//                        if(accuracyStatus == .reducedAccuracy){
//                            return Constants.LocationConsent.HasGeneral
//                        }
//                        else{
//                            
//                            return Constants.LocationConsent.HasGeneral
//                        }
//                    }
//                } else {
//                    return Constants.LocationConsent.HasPrecise //TODO: Is pre-14 precise/general?
//                }
//                
//            }
//        } else {
//           print("Location services not enabled")
//        }
//        
//        return Constants.LocationConsent.None
//    }
}
