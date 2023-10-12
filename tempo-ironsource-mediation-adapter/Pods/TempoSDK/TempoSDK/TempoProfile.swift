import Foundation
import CoreLocation

public class TempoProfile: NSObject, CLLocationManagerDelegate { //TODO: Make class internal/private/default(none)?
    
    // This instance's location manager delegate
    let locManager = CLLocationManager()
    let requestOnLoad_testing = false
    let adView: TempoAdView
    
    // The static that can be retrieved at any time during the SDK's usage
    static var locationState: LocationState?
    static var locData: LocationData?
    
    init(adView: TempoAdView) {
        self.adView = adView
        super.init()
        if #available(iOS 14.0, *) {
            
            // Create a new locData object for the static reference if first initialisation
            TempoProfile.locData = TempoProfile.locData ?? LocationData()
            TempoProfile.locationState = TempoProfile.locationState ?? LocationState.UNCHECKED
            
            // Assign manager delegate
            locManager.delegate = self
            
            // For testing, loads when initialised
            if(requestOnLoad_testing) {
                locManager.requestWhenInUseAuthorization()
                locManager.startUpdatingLocation()
                requestLocationWithChecks()
            }
        }
    }
    
    private func requestLocationWithChecks() {
        if(TempoProfile.locationState != LocationState.CHECKING) {
            TempoProfile.locationState = LocationState.CHECKING
            locManager.requestLocation()
        }
        else {
            print("🤔 Ignoring request location as LocationState == CHECKING")
        }
    }
        
    /// Runs async thread process that gets authorization type/accuray and updates LocationData when received
    public func doTaskAfterLocAuthUpdate(completion: (() -> Void)?) {
        
        // CLLocationManager.authorizationStatus can cause UI unresponsiveness if invoked on the main thread.
        DispatchQueue.global().async {
            
            // Make sure location servics are available
            if CLLocationManager.locationServicesEnabled() {
                
                // get authorisation status
                let authStatus = self.getLocAuthStatus()
                
                switch (authStatus) {
                case .authorizedAlways, .authorizedWhenInUse:
                    print("Access - always or authorizedWhenInUse [UPDATE]")
                    if #available(iOS 14.0, *) {
                        
                        // iOS 14 intro precise/general options
                        if self.locManager.accuracyAuthorization == .reducedAccuracy {
                            // Update LocationData singleton as GENERAL
                            self.updateLocConsentValues(consentType: Constants.LocationConsent.GENERAL)
                            completion?()
                            return
                        } else {
                            // Update LocationData singleton as PRECISE
                            self.updateLocConsentValues(consentType: Constants.LocationConsent.PRECISE)
                            completion?()
                            return
                        }
                    } else {
                        // Update LocationData singleton as PRECISE (pre-iOS 14 considered precise)
                        self.updateLocConsentValues(consentType: Constants.LocationConsent.PRECISE)
                        completion?()
                        return
                    }
                case .restricted, .denied:
                    print("No access - restricted or denied [UPDATE]")
                case .notDetermined:
                    print("No access - notDetermined [UPDATE]")
                @unknown default:
                    print("Unknown authorization status [UPDATE]")
                }
            } else {
                print("Location services not enabled [UPDATE]")
            }
            
            print("💥💥💥 !!! FALLBACK Location services not enabled [UPDATE]")
            self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
            completion?()
            
        }
    }
    
    // Updates consent value to both the static object and the adView instance string reference
    private func updateLocConsentValues(consentType: Constants.LocationConsent) {
        TempoProfile.locData?.lc = consentType.rawValue
        self.adView.locationConsent = consentType.rawValue
        print("💥 Updated consent to: \(consentType.rawValue)")
    }
    
    /// Get CLAuthorizationStatus location consent value
    private func getLocAuthStatus() -> CLAuthorizationStatus {
        var locationAuthorizationStatus : CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            locationAuthorizationStatus =  locManager.authorizationStatus
        } else {
            // Fallback for earlier versions
            locationAuthorizationStatus = CLLocationManager.authorizationStatus()
        }
        return locationAuthorizationStatus
    }
    
    /// Shortcut output for locaation property types while returning string refererence for metrics
    func getLocationPropertyValue(labelName: String, property: String?) -> String? {
        // TODO: Work out the tabs by string length..?
        if let checkedValue = property {
            print("📍🌎👉 \(labelName): \(checkedValue)")
            return checkedValue
        }
        else {
            print("📍🌎🤷‍♂️ \(labelName): [UNAVAILABLE]")
            return nil
        }
    }
    
    
    /* ---------- Location Manager Callback ---------- */
    /// Location Manager callback: didChangeAuthorization
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        TempoUtils.Say(msg: "👉👉👉 didChangeAuthorization: \((status as CLAuthorizationStatus).rawValue)")
        
        if status == .authorizedWhenInUse {
            //TempoUtils.Say(msg: "🤷‍♂️🤷‍♂️🤷‍♂️ status == .authorizedWhenInUse (do something?)")
            
            if(TempoProfile.locationState != LocationState.CHECKING) {
                print("🤔🤔🤔 updating loc auth: \(TempoProfile.locationState ?? LocationState.UNCHECKED)")
                doTaskAfterLocAuthUpdate(completion: nil)
            } else {
                print("🤔🤔🤔 not updating loc auth: CHECKING")
            }
            
            locManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // TODO: Reinstate this !!!!!!!!!!!!
            //locManager.startUpdatingLocation()
            
            requestLocationWithChecks()
//            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) { // TODO: Could these help?
//                if CLLocationManager.isRangingAvailable() {
//                    // do stuff
//                    TempoUtils.Say(msg: "🤷‍♂️🤷‍♂️🤷‍♂️ status Part II")
//                    locManager.startUpdatingLocation()
//                }
//            }
        }
        else {
            // The latest change (or first check) showed no valid authorisation: NONE updated
            //[]TempoProfile.locationState = LocationState.CHECKED
            self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
        }
    }
    /// Location Manager callback: didUpdateLocations
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        TempoUtils.Say(msg: "👉👉👉 didUpdateLocations: \(locations.count)")
        
        //        if locations.first != nil {
        //            locManager.stopUpdatingLocation() // TODO: Needed if I'm doing spot checks?
        //        }
        
        // Last location is most recent (i.e. most accurate)
        if let location = locations.last {
            
            // Reverse geocoding to get the location properties
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                
                if let error = error {
                    print("🚩🚩🚩 onUpdate.error -> Reverse geocoding failed with error: \(error.localizedDescription) | Values remain unchanged")
                    TempoProfile.locationState = LocationState.FAILED
                    self.adView.pushHeldMetricsWithUpdatedLocationData()
                    return
                }
                
                if let placemark = placemarks?.first {
                    
                    TempoProfile.locData?.state = self.getLocationPropertyValue(labelName: "State", property: placemark.administrativeArea)
                    TempoProfile.locData?.postcode = self.getLocationPropertyValue(labelName: "Postcode", property: placemark.postalCode)
                    
                    print("🚩🚩🚩 onUpdate.success -> [postcode=\(TempoProfile.locData?.postcode ?? "NIL") | state=\(TempoProfile.locData?.state ?? "NIL")] | Values have been updated")
                    TempoProfile.locationState = LocationState.CHECKED
                    self.adView.pushHeldMetricsWithUpdatedLocationData()
                    return
                }
            }
        } else {
            print("🚩🚩🚩 onUpdate.noLoc -> [postcode=\(TempoProfile.locData?.postcode ?? "NIL") | state=\(TempoProfile.locData?.state ?? "NIL")] | Values remain unchanged")
            TempoProfile.locationState = LocationState.FAILED
            self.adView.pushHeldMetricsWithUpdatedLocationData()
            return
        }
    }
    /// Location Manager callback: didFailWithError
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        TempoUtils.Say(msg: "👉👉👉 didFailWithError: \(error)")
        //locManager.stopUpdatingLocation()
        
        if let clErr = error as? CLError {
            switch clErr.code {
            case .locationUnknown, .denied, .network:
                print("Location request failed with error: \(clErr.localizedDescription)")
            case .headingFailure:
                print("Heading request failed with error: \(clErr.localizedDescription)")
            case .rangingUnavailable, .rangingFailure:
                print("Ranging request failed with error: \(clErr.localizedDescription)")
            case .regionMonitoringDenied, .regionMonitoringFailure, .regionMonitoringSetupDelayed, .regionMonitoringResponseDelayed:
                print("Region monitoring request failed with error: \(clErr.localizedDescription)")
            default:
                print("Unknown location manager error: \(clErr.localizedDescription)")
            }
        } else {
            print("Unknown error occurred while handling location manager error: \(error.localizedDescription)")
        }
        
        // Need to start pushing these for this round
        TempoProfile.locationState = LocationState.FAILED
        self.adView.pushHeldMetricsWithUpdatedLocationData()
        
    }

    
    /* ---------- TESTING---------- */
    /// Public function for prompting consent (used for testing)
    public func requestLocationConsentNowAsTesting() {
        TempoUtils.Say(msg: "🪲🪲🪲 requestLocationConsent")
        locManager.requestWhenInUseAuthorization()
        
        
        requestLocationWithChecks()
    }
    
    
    /* --------------- DELETE? --------------- */
    //
    //    /// Main public function for running a consent check - escaping completion function for running loadAds when value found
    //    public func checkLocConsent ( completion: @escaping (Bool, Float?, String?) -> Void, isInterstitial: Bool, cpmFloor: Float?,   placementId: String?) {
    //
    //        // CLLocationManager.authorizationStatus can cause UI unresponsiveness if invoked on the main thread.
    //        DispatchQueue.global().async {
    //
    //            // Make sure location servics are available
    //            if CLLocationManager.locationServicesEnabled() {
    //
    //                // get authorisation status
    //                let authStatus = self.getLocAuthStatus()
    //
    //                switch (authStatus) {
    //                case .authorizedAlways, .authorizedWhenInUse:
    //                    print("Access - always or authorizedWhenInUse")
    //                    if #available(iOS 14.0, *) {
    //
    //                        // iOS 14 intro precise/general options
    //                        if self.locManager.accuracyAuthorization == .reducedAccuracy {
    //                            // Update LocationData singleton as GENERAL
    //                            self.updateLocConsentValues(consentType: Constants.LocationConsent.GENERAL)
    //                            completion(isInterstitial, cpmFloor, placementId)
    //                            return
    //                        } else {
    //                            // Update LocationData singleton as PRECISE
    //                            self.updateLocConsentValues(consentType: Constants.LocationConsent.PRECISE)
    //                            completion(isInterstitial, cpmFloor, placementId)
    //                            return
    //                        }
    //                    } else {
    //                        // Update LocationData singleton as PRECISE (pre-iOS 14 considered precise)
    //                        self.updateLocConsentValues(consentType: Constants.LocationConsent.PRECISE)
    //                        completion(isInterstitial, cpmFloor, placementId)
    //                        return
    //                    }
    //                case .restricted, .denied:
    //                    print("No access - restricted or denied")
    //                case .notDetermined:
    //                    print("No access - notDetermined")
    //                @unknown default:
    //                    print("Unknown authorization status")
    //                }
    //            } else {
    //                print("Location services not enabled")
    //            }
    //
    //            // Update LocationData singleton as GENERAL
    //            self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
    //            completion(isInterstitial, cpmFloor, placementId)
    //        }
    //    }
}


public struct LocationData : Codable {
    var lc: String?
    var postcode: String?
    var state: String?
}

public enum LocationState: String {
    case UNCHECKED
    case CHECKING
    case CHECKED
    case FAILED
}
