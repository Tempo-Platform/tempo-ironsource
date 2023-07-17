import Foundation
import UIKit

/**
 *  Initialises when app loads. This is the object that mediation adapters call to load/show ads
 */
public class TempoAdController: NSObject {
    
    static var isInitialised: Bool = false
    var adView: TempoAdView?
    
    public init(tempoAdListener: TempoAdListener, appId: String!) {
        super.init()
        
        // On first instantiation by either ad type do some initial global checks
        if(!TempoAdController.isInitialised) {
            
            // Check for backups
            TempoDataBackup.checkHeldMetrics(completion: Metrics.pushMetrics)
            
//            // Initial output for monitoring purposes TODO: This part should be done by the adapter module
//            let adapterVersion = tempoAdListener.onVersionExchange(sdkVersion: Constants.SDK_VERSIONS)
//            print("TempoSDK: [SDK]\(Constants.SDK_VERSIONS)/[ADAP]\(adapterVersion ?? Constants.UNDEF) | \(appId ?? Constants.UNDEF)")
            
            // Show as initialised moving forward and ignore this section
            TempoAdController.isInitialised = true;
        }
        
        // Create AdView object
        adView = TempoAdView(listener: tempoAdListener, appId: appId)
    }
    
    /// Public LOAD function for mediation adapters to call
    public func loadAd(isInterstitial: Bool, cpmFloor: Float?, placementId: String?) {
        adView!.loadAd (
            isInterstitial: isInterstitial,
            cpmFloor: cpmFloor,
            placementId: placementId)
    }
    
    /// Public SHOW function for mediation adapters to call
    public func showAd(parentViewController: UIViewController?) {
        adView!.showAd(parentVC: parentViewController)
    }
    
    /// Public LOAD function for internal testing with specific campaign ID
    public func loadSpecificAd(isInterstitial: Bool, campaignId:String){
        adView!.loadSpecificCampaignAd(
            isInterstitial: isInterstitial,
            campaignId: campaignId)
    }
}
