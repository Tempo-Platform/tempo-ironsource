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
            TempoProfile.updateLocState(newState: TempoProfile.locationState ?? LocationState.UNCHECKED)
            
            // Assign manager delegate
            locManager.delegate = self
            locManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            
            // For testing, loads when initialised
            if(requestOnLoad_testing) {
                locManager.requestWhenInUseAuthorization()
                locManager.requestLocation()
                requestLocationWithChecks()
            }
        }
    }
    
    private func requestLocationWithChecks() {
        if(TempoProfile.locationState != .CHECKING) {
            TempoProfile.updateLocState(newState: .CHECKING)
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
                case .authorizedAlways, .authorizedWhenInUse: // TODO: auth always might not work
                    print("✅ Access - always or authorizedWhenInUse [UPDATE]")
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
                    print("⛔️ No access - restricted or denied [UPDATE]")
                case .notDetermined:
                    print("⛔️ No access - notDetermined [UPDATE]")
                @unknown default:
                    print("⛔️ Unknown authorization status [UPDATE]")
                }
            } else {
                print("⛔️ Location services not enabled [UPDATE]")
            }
            
            TempoProfile.updateLocState(newState: LocationState.UNAVAILABLE)
            self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
            completion?()
            
        }
    }
    
    // Updates consent value to both the static object and the adView instance string reference
    private func updateLocConsentValues(consentType: Constants.LocationConsent) {
        TempoProfile.locData?.consent = consentType.rawValue
        print("⚠️ Updated consent to: \(consentType.rawValue)")
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
            print("📍👉 \(labelName): \(checkedValue)")
            return checkedValue
        }
        else {
            print("📍🤷‍♂️ \(labelName): [UNAVAILABLE]")
            return nil
        }
    }
    
    /// Shortcut output for locaation property types while returning string refererence for metrics
    func getLocationPropertyValue(labelName: String, property: [String]?) -> [String]? {
        // TODO: Work out the tabs by string length..?
        if let checkedValue = property {
            for prop in property! {
                print("📍👉 \(labelName): \(prop)")
            }
            return checkedValue
        }
        else {
            print("📍🤷‍♂️ \(labelName): [UNAVAILABLE]")
            return nil
        }
    }
   
    
    public static func updateLocState(newState: LocationState) {
        TempoProfile.locationState = newState
        print("🗣️ Updated location state to: \(newState.rawValue)")
    }
    
    /* ---------- Location Manager Callback ---------- */
    /// Location Manager callback: didChangeAuthorization
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        TempoUtils.Say(msg: "☎️ didChangeAuthorization: \((status as CLAuthorizationStatus).rawValue)")
        
        if status == .authorizedWhenInUse {
            if(TempoProfile.locationState != .CHECKING) {
                print("🤔 updating loc auth: \(TempoProfile.locationState ?? .UNCHECKED)")
                doTaskAfterLocAuthUpdate(completion: nil)
            } else {
                print("🤔 not updating loc auth: CHECKING")
            }
            requestLocationWithChecks()
        }
        //else if(status == .notDetermined || status == .denied || status == .restricted || status == .authorizedAlways) // TODO: That last one...
        else {
            // The latest change (or first check) showed no valid authorisation: NONE updated
            TempoProfile.updateLocState(newState: LocationState.UNAVAILABLE)
            self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
        }
    }
    
    /// Location Manager callback: didUpdateLocations
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        TempoUtils.Say(msg: "☎️ didUpdateLocations: \(locations.count)")
        
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
                    TempoProfile.updateLocState(newState: LocationState.FAILED)
                    self.adView.pushHeldMetricsWithUpdatedLocationData()
                    return
                }
                
                if let placemark = placemarks?.first {
                    
                    TempoProfile.locData?.state = self.getLocationPropertyValue(labelName: "State", property: placemark.administrativeArea)
                    TempoProfile.locData?.postcode = self.getLocationPropertyValue(labelName: "Postcode", property: placemark.postalCode)
                    
                    let testingOutput = false
                    if(testingOutput) {
                        print("🌐 => \(location.coordinate.latitude)/\(location.coordinate.longitude)" )
                        self.getLocationPropertyValue(labelName: "name", property: placemark.name) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "thoroughfare", property: placemark.thoroughfare) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "subThoroughfare", property: placemark.subThoroughfare) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "locality", property: placemark.locality) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "subLocality", property: placemark.subLocality) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "administrativeArea", property: placemark.administrativeArea) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "subAdministrativeArea", property: placemark.subAdministrativeArea) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "postalCode", property: placemark.postalCode) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "isoCountryCode", property: placemark.isoCountryCode) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "country", property: placemark.country) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "inlandWater", property: placemark.inlandWater) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "ocean", property: placemark.ocean) ?? "n/a"
                        self.getLocationPropertyValue(labelName: "areasOfInterest", property: placemark.areasOfInterest) ?? []
                    }
                    
                    print("🚩🚩🚩 onUpdate.success -> [postcode=\(TempoProfile.locData?.postcode ?? "NIL") | state=\(TempoProfile.locData?.state ?? "NIL")] | Values have been updated")
                    TempoProfile.updateLocState(newState: LocationState.CHECKED)
                    self.adView.pushHeldMetricsWithUpdatedLocationData()
                    return
                }
            }
        } else {
            print("🚩🚩🚩 onUpdate.noLoc -> [postcode=\(TempoProfile.locData?.postcode ?? "NIL") | state=\(TempoProfile.locData?.state ?? "NIL")] | Values remain unchanged")
            TempoProfile.updateLocState(newState: LocationState.FAILED)
            self.adView.pushHeldMetricsWithUpdatedLocationData()
            return
        }
    }
    
    /// Location Manager callback: didFailWithError
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        TempoUtils.Say(msg: "☎️ didFailWithError: \(error)")
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
        TempoProfile.updateLocState(newState: LocationState.FAILED)
        self.adView.pushHeldMetricsWithUpdatedLocationData()
    }
    
    /* ---------- TESTING---------- */
    /// Public function for prompting consent (used for testing)
    public func requestLocationConsentNowAsTesting() {
        TempoUtils.Say(msg: "🪲🪲🪲 requestLocationConsent")
        locManager.requestWhenInUseAuthorization()
        
        requestLocationWithChecks()
    }
}

public struct LocationData : Codable {
    var consent: String?
    var postcode: String?
    var state: String?
}

public enum LocationState: String {
    case UNCHECKED
    case CHECKING
    case CHECKED
    case FAILED
    case UNAVAILABLE
}
