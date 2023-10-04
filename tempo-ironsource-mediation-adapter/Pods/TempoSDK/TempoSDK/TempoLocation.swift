import Foundation
import CoreLocation

class TempoLocation: NSObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    var location: CLLocation?

    override init() {
        super.init()
        if #available(iOS 14.0, *) {
            locationManager.delegate = self
            //requestLocationConsent()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    /// Public function for prompting consent (used for testing)
    public func requestLocationConsent() {
        locationManager.requestWhenInUseAuthorization()
        // locationManager.startUpdatingLocation() TODO: ??
    }

    /// Get CLAuthorizationStatus location consent value
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
    
    /// Main public function for running a consent check - escaping completion function for running loadAds when value found
    public func checkLocationServicesConsent(
        completion: @escaping (Constants.LocationConsent, Bool, Float?, String?) -> Void,
        isInterstitial: Bool,
        cpmFloor: Float?,
        placementId: String?) {
            
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
}
