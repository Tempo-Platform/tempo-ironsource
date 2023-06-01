import Foundation
import TempoSDK
import IronSource

@objc(ISTempoCustomInterstitial)
public class ISTempoCustomInterstitial: ISBaseInterstitial, TempoInterstitialListener {
    
    var interstitial:TempoInterstitial? = nil
    var isAdReady: Bool = false
    var delegate:ISInterstitialAdDelegate? = nil
    
    public override func loadAd(with adData: ISAdData, delegate: ISInterstitialAdDelegate) {
        ISTempoUtils.shout(msg: "\(ISTempoUtils.adUnitDataStringer(adData: adData))");
        
        // Implement callback delegate
        self.delegate = delegate
        
        // Get App ID from Ad Data
        let appId = ISTempoUtils.getAppId(adData: adData)
        
        // Create ad instance and load new ad
        DispatchQueue.main.async {
            self.interstitial = TempoInterstitial(parentViewController: nil, delegate: self, appId: appId)
            self.interstitial!.loadAd(isInterstitial: true, cpmFloor: 0, placementId: nil)
          }
    }
    
    public override func isAdAvailable(with adData: ISAdData) -> Bool {
        ISTempoUtils.shout(msg: "[\(isAdReady), \(ISTempoUtils.adUnitDataStringer(adData: adData))]");
        return isAdReady
    }
    
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
        ISTempoUtils.shout(msg: "[\(ISTempoUtils.getTypeWord(isInterstitial: true))] SDK Version: \(sdkVersion), Adapter Version: \(ISTempoCustomAdapter.customAdapterVersion)");
        ISTempoCustomAdapter.dynSdkVersion = sdkVersion
        return ISTempoCustomAdapter.customAdapterVersion
    }
    
    public func onGetAdapterType() -> String? {
        ISTempoUtils.shout(msg: "[\(ISTempoUtils.getTypeWord(isInterstitial: true))] Adapter type: \(ISTempoCustomAdapter.ADAPTER_TYPE)");
        return ISTempoCustomAdapter.ADAPTER_TYPE
    }
    
 
}
