import Foundation
import TempoSDK
import IronSource

@objc(ISTempoCustomRewardedVideo)
public class ISTempoCustomRewardedVideo: ISBaseRewardedVideo, TempoAdListener {

    
    var rewarded: TempoAdController? = nil
    var isAdReady: Bool = false
    var delegate: ISRewardedVideoAdDelegate? = nil
    
    /// Callback from ironSource API when IronSource.loadRewardedAds() called
    public override func loadAd(with adData: ISAdData, delegate: ISRewardedVideoAdDelegate) {

        // Implement callback delegate
        self.delegate = delegate
        
        do {
            // Confirm valid App ID
            let appId = try ISTempoUtils.getAppId(adData: adData)
            TempoUtils.say(msg: "\(try ISTempoUtils.adUnitDataStringer(adData: adData))");
            
            // Check for valid CPM Floor
            let cpmFloor = ISTempoUtils.getCpmFloor(adData: adData)
            let cpmFloorFloat: Float = Float(cpmFloor) ?? 0.0
            if cpmFloorFloat != 0.0 {
                TempoUtils.say(msg: "The CPM is a valid Float: \(cpmFloorFloat)")
            } else {
                TempoUtils.warn(msg: "The CPM is not a valid Float or is zero")
            }
            
            // Create ad instance and load new ad
            DispatchQueue.main.async {
                
                if self.rewarded == nil {
                    self.rewarded = TempoAdController(tempoAdListener: self, appId: appId)
                    
                    // Abort if nil
                    guard self.rewarded != nil else {
                        self.onTempoAdFetchFailed(isInterstitial: false, reason: "Ad controller is null")
                        return
                    }
                }
                
                // Load ad, provided the ad controller is not null
                self.rewarded?.loadAd(isInterstitial: false, cpmFloor: cpmFloorFloat, placementId: nil)
            }
        } catch {
            TempoUtils.warn(msg: "Invalid ad data: unable to get App ID")
            self.onTempoAdFetchFailed(isInterstitial: false, reason: "Invalid ad data")
        }
    }
    
    /// Callback from ironSource API which checks the availbility as determined by the 'isAdReady' property
    public override func isAdAvailable(with adData: ISAdData) -> Bool {
        do {
            TempoUtils.say(msg: "[\(isAdReady ? "Ad Ready": "Ad NOT Ready"), \(try ISTempoUtils.adUnitDataStringer(adData: adData))]");
        } catch {
            TempoUtils.warn(msg: "Error checking ad availability - invalid ad details, cannot continue")
            isAdReady = false
        }
        return isAdReady
    }
    
    /// Callback from ironSource API when IronSource.showRewardedAds() called
    public override func showAd(with viewController: UIViewController, adData: ISAdData, delegate: ISRewardedVideoAdDelegate) {
        //TempoUtils.say(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        
        // Implement callback delegate
        self.delegate = delegate
                
        // Nil error handling
        guard isAdReady else {
            delegate.adDidFailToShowWithErrorCode(ISAdapterErrors.internal.rawValue, errorMessage: "Ad is not ready to show for the current instance data")
            return
        }
        
        guard let interstitial = self.rewarded else {
            delegate.adDidFailToShowWithErrorCode(ISAdapterErrors.internal.rawValue, errorMessage: "Ad controller has not been created yet. Cannot display ad")
            return
        }
        
        self.rewarded!.showAd(parentViewController: viewController)
    }
    
    /// Tempo listener - to be called when ad has successfully loaded
    public func onTempoAdFetchSucceeded(isInterstitial: Bool) {
        TempoUtils.say(msg: "onAdFetchSucceeded \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidLoad()
        isAdReady = true
    }
    
    /// Tempo listener - to be called when ad failed to load
    public func onTempoAdFetchFailed(isInterstitial: Bool, reason: String?) {
        TempoUtils.say(msg: "onAdFetchFailed \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidFailToLoadWith(ISAdapterErrorType.internal, errorCode: 0, errorMessage: "Ad fetch failed for some reason")
    }
    
    /// Tempo listener - to be called when ad is closed
    public func onTempoAdClosed(isInterstitial: Bool) {
        TempoUtils.say(msg: "onAdClosed \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidClose()
        isAdReady = false
    }
    
    /// Tempo listener - to be called when ad is displayed
    public func onTempoAdDisplayed(isInterstitial: Bool) {
        TempoUtils.say(msg: "onAdDisplayed \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidOpen()
        self.delegate?.adRewarded()
    }
    
    public func onTempoAdShowFailed(isInterstitial: Bool, reason: String?) {
        TempoUtils.say(msg: "onAdShowFailed \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial)): \(reason ?? "Unknown")");
        
        self.delegate?.adDidFailToShowWithErrorCode(0, errorMessage: reason ?? "Unknown")
    }
    
    /// Tempo listener - to be called when ad is clicked
    public func onTempoAdClicked(isInterstitial: Bool) {
        TempoUtils.say(msg: "onAdClicked \(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidClick()
    }
    
    /// Tempo listener - to be called when version references are updated
    public func getTempoAdapterVersion() -> String? {
        TempoUtils.say(msg: "getTempoAdapterVersion \(ISTempoUtils.sayAdType(isInterstitial: false))");
        return ISTempoCustomAdapter.TEMPO_ADAPTER_VERSION
    }
    
    /// Tempo listener - to be called when adapter type is requested
    public func getTempoAdapterType() -> String? {
        TempoUtils.say(msg: "getTempoAdapterType \(ISTempoUtils.sayAdType(isInterstitial: false))");
        return ISTempoCustomAdapter.ADAPTER_TYPE
    }
    
    public func hasUserConsent() -> Bool? {
        TempoUtils.say(msg: "hasUserConsent \(ISTempoUtils.sayAdType(isInterstitial: false))");
        return nil;
    }
}
