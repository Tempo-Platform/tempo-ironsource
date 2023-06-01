import Foundation
import TempoSDK
import IronSource

@objc(ISTempoCustomRewardedVideo)
public class ISTempoCustomRewardedVideo: ISBaseRewardedVideo, TempoInterstitialListener {
    
    var rewarded :TempoInterstitial? = nil
    var isAdReady: Bool = false
    var delegate:ISRewardedVideoAdDelegate? = nil
    
    public override func loadAd(with adData: ISAdData, delegate: ISRewardedVideoAdDelegate) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        
        // Implement callback delegate
        self.delegate = delegate
        
        // Get App ID from Ad Data
        let appId = ISTempoUtils.getAppId(adData: adData)
        
        // Create ad instance and load new ad
        DispatchQueue.main.async {
            self.rewarded = TempoInterstitial(parentViewController: nil, delegate: self, appId: appId)
            self.rewarded!.loadAd(isInterstitial: false, cpmFloor: 0, placementId: nil)
          }
    }
    
    public override func isAdAvailable(with adData: ISAdData) -> Bool {
        ISTempoUtils.shout(msg: "[\(isAdReady), \(ISTempoUtils.adUnitDataStringer(adData: adData))]");
        return isAdReady
    }
    
    public override func showAd(with viewController: UIViewController, adData: ISAdData, delegate: ISRewardedVideoAdDelegate) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        self.delegate = delegate
        if (!isAdReady) {
           delegate.adDidFailToShowWithErrorCode(ISAdapterErrors.internal.rawValue, errorMessage: "ad is not ready to show for the current instanceData")
           return
        }
        self.rewarded!.updateViewController(parentViewController: viewController)
        self.rewarded!.showAd()
    }
    
    // Listeners
    public func onAdFetchSucceeded(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.getTypeWord(isInterstitial: isInterstitial))");
        self.delegate?.adDidLoad()
        isAdReady = true
    }
    
    public func onAdFetchFailed(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.getTypeWord(isInterstitial: isInterstitial))");
        self.delegate?.adDidFailToLoadWith(ISAdapterErrorType.noFill, errorCode: 0, errorMessage: "Ad fetch failed for some reason")
    }
    
    public func onAdClosed(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.getTypeWord(isInterstitial: isInterstitial))");
        self.delegate?.adDidClose()
        self.delegate?.adDidShowSucceed()
        isAdReady = false
    }
    
    public func onAdDisplayed(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.getTypeWord(isInterstitial: isInterstitial))");
        self.delegate?.adDidOpen()
    }
    
    public func onAdClicked(isInterstitial: Bool) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.getTypeWord(isInterstitial: isInterstitial))");
    }
    
    public func onVersionExchange(sdkVersion: String) -> String? {
        ISTempoUtils.shout(msg: "[\(ISTempoUtils.getTypeWord(isInterstitial: false))] SDK Version: \(sdkVersion), Adapter Version: \(ISTempoCustomAdapter.customAdapterVersion)");
        ISTempoCustomAdapter.dynSdkVersion = sdkVersion
        return ISTempoCustomAdapter.customAdapterVersion
    }
    
    public func onGetAdapterType() -> String? {
        ISTempoUtils.shout(msg: "[\(ISTempoUtils.getTypeWord(isInterstitial: false))] Adapter type: \(ISTempoCustomAdapter.ADAPTER_TYPE)");
        return ISTempoCustomAdapter.ADAPTER_TYPE
    }
    
}
