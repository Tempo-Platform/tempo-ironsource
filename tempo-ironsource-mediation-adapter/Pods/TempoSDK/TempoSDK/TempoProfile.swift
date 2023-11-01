import Foundation
import CoreLocation

public class TempoProfile: NSObject, CLLocationManagerDelegate { //TODO: Make class internal/private/default(none)?
    
    // This instance's location manager delegate
    let locManager = CLLocationManager()
    let requestOnLoad_testing = false
    let adView: TempoAdView
    
    // The static that can be retrieved at any time during the SDK's usage
    static var outputtingLocationInfo = false
    static var locationState: LocationState?
    static var locData: LocationData?
    
    init(adView: TempoAdView) {
        self.adView = adView
        super.init()
        
        // Update locData with backup if nil
        if(TempoProfile.locData == nil) {
            TempoProfile.locData = TempoDataBackup.getMostRecentLocationData()
        } else {
            TempoUtils.Say(msg: "🌏 LocData is null, no backup needed")
        }
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
    
    private func requestLocationWithChecks() {
        if(TempoProfile.locationState != .CHECKING) {
            TempoProfile.updateLocState(newState: .CHECKING)
            locManager.requestLocation()
        }
        else {
            TempoUtils.Say(msg: "Ignoring request location as LocationState == CHECKING")
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
                    let addendum = completion == nil ? "No completion task given" : ""
                    TempoUtils.Say(msg: "✅ Access - always or authorizedWhenInUse [UPDATE] \(addendum)")
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
                    TempoUtils.Warn(msg: "⛔️ No access - restricted or denied [UPDATE]")
                    // Need to update latest valid consent as confirmed NONE
                    TempoProfile.locData = self.adView.getClonedAndCleanedLocation()
                    TempoProfile.updateLocState(newState: LocationState.UNAVAILABLE)
                    self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
                    self.saveLatestValidLocData()
                    completion?()
                    return
                case .notDetermined:
                    TempoUtils.Warn(msg: "⛔️ No access - notDetermined [UPDATE]")
                    // Need to update latest valid consent as confirmed NONE
                    TempoProfile.locData = self.adView.getClonedAndCleanedLocation()
                    TempoProfile.updateLocState(newState: LocationState.UNAVAILABLE)
                    self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
                    self.saveLatestValidLocData()
                    completion?()
                    return
                @unknown default:
                    TempoUtils.Warn(msg: "⛔️ Unknown authorization status [UPDATE]")
                }
            } else {
                TempoUtils.Warn(msg: "⛔️ Location services not enabled [UPDATE]")
            }
            
            TempoProfile.updateLocState(newState: LocationState.UNAVAILABLE)
            self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
            completion?()
            
        }
    }
    
    // Updates consent value to both the static object and the adView instance string reference
    private func updateLocConsentValues(consentType: Constants.LocationConsent) {
        TempoProfile.locData?.consent = consentType.rawValue
        if(TempoProfile.outputtingLocationInfo) {
            TempoUtils.Say(msg: " Updated location consent to: \(consentType.rawValue)")
        }
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
    
    /// Shortcut output for location property types while returning string refererence for metrics
    func getLocationPropertyValue(labelName: String, property: String?) -> String? {
        // TODO: Work out the tabs by string length..?
        if let checkedValue = property {
            if(TempoProfile.outputtingLocationInfo) {
                TempoUtils.Say(msg: "📍👍 \(labelName): \(checkedValue)")
            }
            return checkedValue
        }
        else {
            if(TempoProfile.outputtingLocationInfo) {
                TempoUtils.Say(msg: "📍👎 \(labelName): [UNAVAILABLE]")
            }
            return nil
        }
    }
    
    /// Shortcut output for location property types while returning string refererence for metrics
    func getLocationPropertyValue(labelName: String, property: [String]?) -> [String]? {
        // TODO: Work out the tabs by string length..?
        if let checkedValue = property {
            for prop in property! {
                if(TempoProfile.outputtingLocationInfo) {
                    TempoUtils.Say(msg: "📍👍 \(labelName): \(prop)")
                }
            }
            return checkedValue
        }
        else {
            if(TempoProfile.outputtingLocationInfo) {
                TempoUtils.Say(msg: "📍👎 \(labelName): [UNAVAILABLE]")
            }
            return nil
        }
    }
   
    /// Updates the fetchingf state of location data
    public static func updateLocState(newState: LocationState) {
        TempoProfile.locationState = newState
        
        if(TempoProfile.outputtingLocationInfo) {
            TempoUtils.Say(msg: "🗣️ Updated location state to: \(newState.rawValue)")
        }
        
    }
    
    /* ---------- Location Manager Callback ---------- */
    /// Location Manager callback: didChangeAuthorization
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        var updating = "NOT UPDATING"
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if(TempoProfile.locationState != .CHECKING) {
                updating = "UPDATING"
                doTaskAfterLocAuthUpdate(completion: nil)
            } else {
                updating = "NOT UPDATING WHILE CHECKING"
            }
            
            requestLocationWithChecks()
        }
        else {
            // The latest change (or first check) showed no valid authorisation: NONE updated
            TempoProfile.updateLocState(newState: LocationState.UNAVAILABLE)
            self.updateLocConsentValues(consentType: Constants.LocationConsent.NONE)
        }
        
        TempoUtils.Say(msg: "☎️ didChangeAuthorization => \((status as CLAuthorizationStatus).rawValue): \(updating)")
    }
    
    /// Location Manager callback: didUpdateLocations
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        var errorMsg: String?
        //TempoUtils.Say(msg: "☎️ didUpdateLocations: \(locations.count)")
        
        // Last location is most recent (i.e. most accurate)
        if let location = locations.last {
            
            // Reverse geocoding to get the location properties
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            
                if let error = error {
                    errorMsg = "Reverse geocoding failed with error: \(error.localizedDescription) | Values remain unchanged"
                    TempoProfile.updateLocState(newState: LocationState.FAILED)
                    self.adView.pushHeldMetricsWithUpdatedLocationData()
                }
                else {
                    if let placemark = placemarks?.first {
                        
                        TempoProfile.locData?.state = self.getLocationPropertyValue(labelName: "State", property: placemark.administrativeArea)
                        TempoProfile.locData?.postcode = self.getLocationPropertyValue(labelName: "Postcode", property: placemark.postalCode)
                        TempoProfile.locData?.postal_code = self.getLocationPropertyValue(labelName: "Postal Code", property: placemark.postalCode)
                        TempoProfile.locData?.country_code = self.getLocationPropertyValue(labelName: "Country Code", property: placemark.isoCountryCode)
                        TempoProfile.locData?.admin_area = self.getLocationPropertyValue(labelName: "Admin Area", property: placemark.administrativeArea)
                        TempoProfile.locData?.sub_admin_area = self.getLocationPropertyValue(labelName: "Sub Admin Area", property: placemark.subAdministrativeArea)
                        TempoProfile.locData?.locality = self.getLocationPropertyValue(labelName: "Locality", property: placemark.locality)
                        TempoProfile.locData?.sub_locality = self.getLocationPropertyValue(labelName: "Sub Locality", property: placemark.subLocality)
                        
                        let testingOutput = false
                        if(testingOutput) {
//                        print("🌐 => \(location.coordinate.latitude)/\(location.coordinate.longitude)" )
//                        self.getLocationPropertyValue(labelName: "name", property: placemark.name) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "thoroughfare", property: placemark.thoroughfare) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "subThoroughfare", property: placemark.subThoroughfare) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "locality", property: placemark.locality) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "subLocality", property: placemark.subLocality) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "administrativeArea", property: placemark.administrativeArea) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "subAdministrativeArea", property: placemark.subAdministrativeArea) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "postalCode", property: placemark.postalCode) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "isoCountryCode", property: placemark.isoCountryCode) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "country", property: placemark.country) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "inlandWater", property: placemark.inlandWater) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "ocean", property: placemark.ocean) ?? "n/a"
//                        self.getLocationPropertyValue(labelName: "areasOfInterest", property: placemark.areasOfInterest) ?? []
                        }
                        
                        // Update current sessions top-level country code paramter is there is a value
                        if let cc = TempoProfile.locData?.country_code, !cc.isEmpty {
                            self.adView.countryCode = cc
                        }
                        
                        TempoUtils.Say(msg: "☎️ didUpdateLocations: [admin=\(TempoProfile.locData?.admin_area ?? "nil") | locality=\(TempoProfile.locData?.locality ?? "nil")] | Values have been updated")
                        
                        // Save data instance as most recently validated data
                        self.saveLatestValidLocData()
                        
                        TempoProfile.updateLocState(newState: LocationState.CHECKED)
                        self.adView.pushHeldMetricsWithUpdatedLocationData()
                        return
                    }
                }
                
                TempoUtils.Warn(msg: "☎️ didUpdateLocations: [errorMsg: \(errorMsg ?? "UNKNOWN")]] | Values remain unchanged have been updated")
                
            }
        } else {
            TempoUtils.Warn(msg: "☎️ didUpdateLocations: [errorMsg: \(errorMsg ?? "UNKNOWN")]] | Values remain unchanged have been updated")
            TempoProfile.updateLocState(newState: LocationState.FAILED)
            self.adView.pushHeldMetricsWithUpdatedLocationData()
            return
        }
    }
    
    
    private func saveLatestValidLocData() {
        
        // Save the instance to UserDefaults
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(TempoProfile.locData) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: Constants.Backup.LOC_BACKUP_REF)
            TempoUtils.Say(msg: "Backup location data saved")
        }
        else {
            TempoUtils.Warn(msg: "Backup location data saved")
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
    
    var postal_code: String?
    var country_code: String?
    var admin_area: String?
    var sub_admin_area: String?
    var locality: String?
    var sub_locality: String?
}

public enum LocationState: String {
    case UNCHECKED
    case CHECKING
    case CHECKED
    case FAILED
    case UNAVAILABLE
}
