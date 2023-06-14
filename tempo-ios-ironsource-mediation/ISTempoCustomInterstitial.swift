import Foundation
import TempoSDK
import IronSource

@objc(ISTempoCustomInterstitial)
public class ISTempoCustomInterstitial: ISBaseInterstitial, TempoInterstitialListener {
    
    var interstitial:TempoInterstitial? = nil
    var isAdReady: Bool = false
    var delegate:ISInterstitialAdDelegate? = nil
    
    /// Callback from ironSource API when IronSource.loadInterstitialAds() called
    public override func loadAd(with adData: ISAdData, delegate: ISInterstitialAdDelegate) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        
        // Implement callback delegate
        self.delegate = delegate
        
        // Get App ID from Ad Data
        let appId = ISTempoUtils.getAppId(adData: adData)
        let cpmFloor = ISTempoUtils.getCpmFloor(adData: adData)
        var cpmFloorFloat: Float = 0
        if let floatValue = Float(cpmFloor) {
            print("The CPM is a valid Double: \(floatValue)")
            cpmFloorFloat = floatValue
        } else {
            print("The CPM is not a valid Double")
        }
        
        // Create ad instance and load new ad
        self.interstitial = TempoInterstitial(parentViewController: nil, delegate: self, appId: appId)
        DispatchQueue.main.async {
            self.interstitial!.loadAd(isInterstitial: true, cpmFloor: cpmFloorFloat, placementId: nil)
          }
    }
    
    /// Callback from ironSource API which checks the availbility as determined by the 'isAdReady' property
    public override func isAdAvailable(with adData: ISAdData) -> Bool {
        ISTempoUtils.shout(msg: "[\(isAdReady ? "Ad Ready": "Ad NOT Ready"), \(ISTempoUtils.adUnitDataStringer(adData: adData))]");
        return isAdReady
    }
    
    /// Callback from ironSource API when IronSource.showRewardedAds() called
    public override func showAd(with viewController: UIViewController, adData: ISAdData, delegate: ISInterstitialAdDelegate) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        self.delegate = delegate
        if (!isAdReady) {
           delegate.adDidFailToShowWithErrorCode(ISAdapterErrors.internal.rawValue, errorMessage: "ad is not ready to show for the current instanceData")
           return
        }
        self.interstitial!.updateViewController(parentViewController: viewController)
        self.interstitial!.showAd()
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
        ISTempoUtils.shout(msg: "[\(ISTempoUtils.sayAdType(isInterstitial: true))] SDK Version: \(sdkVersion), Adapter Version: \(ISTempoCustomAdapter.customAdapterVersion)");
        ISTempoCustomAdapter.dynSdkVersion = sdkVersion
        return ISTempoCustomAdapter.customAdapterVersion
    }
    
    /// Tempo listener - to be called when adapter type is requested
    public func onGetAdapterType() -> String? {
        ISTempoUtils.shout(msg: "[\(ISTempoUtils.sayAdType(isInterstitial: true))] Adapter type: \(ISTempoCustomAdapter.ADAPTER_TYPE)");
        return ISTempoCustomAdapter.ADAPTER_TYPE
    }
    
 
}
