import Foundation
import TempoSDK
import IronSource

@objc(ISTempoCustomRewardedVideo)
public class ISTempoCustomRewardedVideo: ISBaseRewardedVideo, TempoInterstitialListener {
    
    var rewarded :TempoInterstitial? = nil
    var isAdReady: Bool = false
    var delegate:ISRewardedVideoAdDelegate? = nil
    
    /// Callback from ironSource API when IronSource.loadRewardedAds() called
    public override func loadAd(with adData: ISAdData, delegate: ISRewardedVideoAdDelegate) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        
        // Implement callback delegate
        self.delegate = delegate
        
        // Get App ID from Ad Data
        let appId = ISTempoUtils.getAppId(adData: adData)
        
        // Create ad instance and load new ad
        self.rewarded = TempoInterstitial(parentViewController: nil, delegate: self, appId: appId)
        DispatchQueue.main.async {
            self.rewarded!.loadAd(isInterstitial: false, cpmFloor: 0, placementId: nil)
          }
    }
    
    /// Callback from ironSource API which checks the availbility as determined by the 'isAdReady' property
    public override func isAdAvailable(with adData: ISAdData) -> Bool {
        ISTempoUtils.shout(msg: "[\(isAdReady ? "Ad Ready": "Ad NOT Ready"), \(ISTempoUtils.adUnitDataStringer(adData: adData))]");
        return isAdReady
    }
    
    /// Callback from ironSource API when IronSource.showRewardedAds() called
    public override func showAd(with viewController: UIViewController, adData: ISAdData, delegate: ISRewardedVideoAdDelegate) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        
        // Implement callback delegate
        self.delegate = delegate
                
        if (!isAdReady) {
           delegate.adDidFailToShowWithErrorCode(ISAdapterErrors.internal.rawValue, errorMessage: "ad is not ready to show for the current instanceData")
           return
        }
        self.rewarded!.updateViewController(parentViewController: viewController)
        self.rewarded!.showAd()
    }
    
    /// Tempo listener - to be called when ad has successfully loaded
    public func onAdFetchSucceeded(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidLoad()
        isAdReady = true
    }
    
    /// Tempo listener - to be called when ad failed to load
    public func onAdFetchFailed(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidFailToLoadWith(ISAdapterErrorType.noFill, errorCode: 0, errorMessage: "Ad fetch failed for some reason")
    }
    
    /// Tempo listener - to be called when ad is closed
    public func onAdClosed(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidClose()
        self.delegate?.adDidShowSucceed()
        self.delegate?.adRewarded()
        self.delegate?.adDidClick()
        isAdReady = false
    }
    
    /// Tempo listener - to be called when ad is displayed
    public func onAdDisplayed(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidOpen()
    }
    
    /// Tempo listener - to be called when ad is clicked
    public func onAdClicked(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.sayAdType(isInterstitial: isInterstitial))");
        self.delegate?.adDidClick()
    }
    
    /// Tempo listener - to be called when version references are updated
    public func onVersionExchange(sdkVersion: String) -> String? {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.sayAdType(isInterstitial: false)), SDK Version: \(sdkVersion), Adapter Version: \(ISTempoCustomAdapter.customAdapterVersion)");
        ISTempoCustomAdapter.dynSdkVersion = sdkVersion
        return ISTempoCustomAdapter.customAdapterVersion
    }
    
    /// Tempo listener - to be called when adapter type is requested
    public func onGetAdapterType() -> String? {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.sayAdType(isInterstitial: false)), Adapter type: \(ISTempoCustomAdapter.ADAPTER_TYPE)");
        return ISTempoCustomAdapter.ADAPTER_TYPE
    }
    
}
