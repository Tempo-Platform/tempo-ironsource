import Foundation
import TempoSDK
import IronSource

@objc(ISTempoCustomInterstitial)
public class ISTempoCustomInterstitial: ISBaseInterstitial, TempoAdListener {


    var interstitial: TempoAdController?
    var isAdReady: Bool = false
    var delegate:ISInterstitialAdDelegate? = nil
    
    /// Callback from ironSource API when IronSource.loadInterstitialAds() called
    public override func loadAd(with adData: ISAdData, delegate: ISInterstitialAdDelegate) {
        
        // Implement callback delegate
        self.delegate = delegate
        
        do {
            // Confirm valid App ID
            let appId = try ISTempoUtils.getAppId(adData: adData)
            TempoUtils.Say(msg: "\(try ISTempoUtils.adUnitDataStringer(adData: adData))");
            
            // Check for valid CPM Floor
            let cpmFloor = ISTempoUtils.getCpmFloor(adData: adData)
            let cpmFloorFloat: Float = Float(cpmFloor) ?? 0.0
            if cpmFloorFloat != 0.0 {
                TempoUtils.Say(msg: "The CPM is a valid Float: \(cpmFloorFloat)")
            } else {
                TempoUtils.Warn(msg: "The CPM is not a valid Float or is zero")
            }
            
            // Create ad instance and load new ad
            DispatchQueue.main.async {
                
                // Update controller reference is not assigned
                if self.interstitial == nil {
                    self.interstitial = TempoAdController(tempoAdListener: self, appId: appId)
                    
                    // Abort if nil
                    guard self.interstitial != nil else {
                        self.onTempoAdFetchFailed(isInterstitial: true, reason: "Ad controller is null")
                        return
                    }
                }
                
                // Load ad, provided the ad controller is not null
                self.interstitial?.loadAd(isInterstitial: true, cpmFloor: cpmFloorFloat, placementId: nil)
            }
        } catch {
            TempoUtils.Warn(msg: "Invalid ad data: unable to get App ID")
            self.onTempoAdFetchFailed(isInterstitial: true, reason: "Invalid ad data")
        }
        
    }
    
    /// Callback from ironSource API which checks the availbility as determined by the 'isAdReady' property
    public override func isAdAvailable(with adData: ISAdData) -> Bool {
        do {
            TempoUtils.Say(msg: "[\(isAdReady ? "Ad Ready": "Ad NOT Ready"), \(try ISTempoUtils.adUnitDataStringer(adData: adData))]");
        } catch {
            TempoUtils.Warn(msg: "Error while checking availability, inb")
            isAdReady = false
        }
        return isAdReady
    }
    
    /// Callback from ironSource API when IronSource.showRewardedAds() called
    public override func showAd(with viewController: UIViewController, adData: ISAdData, delegate: ISInterstitialAdDelegate) {
        //TempoUtils.Say(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        
        // Implement callback delegate
        self.delegate = delegate
        
        // Nil error handling
        guard isAdReady else {
            delegate.adDidFailToShowWithErrorCode(ISAdapterErrors.internal.rawValue, errorMessage: "Ad is not ready to show for the current instance data")
            return
        }
        
        guard let interstitial = self.interstitial else {
            delegate.adDidFailToShowWithErrorCode(ISAdapterErrors.internal.rawValue, errorMessage: "Ad controller has not been created yet. Cannot display ad")
            return
        }
        
        self.interstitial!.showAd(parentViewController: viewController)
    }
    
    /// Tempo listener - to be called when ad has successfully loaded
    public func onTempoAdFetchSucceeded(isInterstitial: Bool) {
        TempoUtils.Say(msg: "onAdFetchSucceeded \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidLoad()
        isAdReady = true
    }
    
    /// Tempo listener - to be called when ad failed to load
    public func onTempoAdFetchFailed(isInterstitial: Bool, reason: String?) {
        TempoUtils.Say(msg: "onAdFetchFailed \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidFailToLoadWith(ISAdapterErrorType.internal, errorCode: 0, errorMessage: reason ?? "Ad fetch failed")
    }
    
    /// Tempo listener - to be called when ad is closed
    public func onTempoAdClosed(isInterstitial: Bool) {
        TempoUtils.Say(msg: "onAdClosed \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidClose()
        self.delegate?.adDidShowSucceed()
        isAdReady = false
    }
    
    /// Tempo listener - to be called when ad is displayed
    public func onTempoAdDisplayed(isInterstitial: Bool) {
        TempoUtils.Say(msg: "onAdDisplayed \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidOpen()
    }
    
    public func onTempoAdShowFailed(isInterstitial: Bool, reason: String?) {
        TempoUtils.Say(msg: "onAdShowFailed \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial)): \(reason ?? "Unknown")");
        self.delegate?.adDidFailToShowWithErrorCode(0, errorMessage: reason ?? "Unknown")
    }
    
    /// Tempo listener - to be called when ad is clicked
    public func onTempoAdClicked(isInterstitial: Bool) {
        TempoUtils.Say(msg: "onAdClicked \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidClick()
    }
    
    /// Tempo listener - to be called when version references are updated
    public func getTempoAdapterVersion() -> String? {
        TempoUtils.Say(msg: "getTempoAdapterVersion \(ISTempoUtils.sayAdType(isInterstitial: true))");
        return ISTempoCustomAdapter.TEMPO_ADAPTER_VERSION
    }
    
    /// Tempo listener - to be called when adapter type is requested
    public func getTempoAdapterType() -> String? {
        TempoUtils.Say(msg: "getTempoAdapterType \(ISTempoUtils.sayAdType(isInterstitial: true))");
        return ISTempoCustomAdapter.ADAPTER_TYPE
    }
    
    public func hasUserConsent() -> Bool? {
        TempoUtils.Say(msg: "hasUserConsent \(ISTempoUtils.sayAdType(isInterstitial: true))");
        return nil;
    }
}
