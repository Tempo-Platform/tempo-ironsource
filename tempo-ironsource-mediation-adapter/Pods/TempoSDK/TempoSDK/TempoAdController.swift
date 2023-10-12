import Foundation
import UIKit

/**
 *  Initialises when app loads. This is the object that mediation adapters call to load/show ads
 */
public class TempoAdController: NSObject {
    
    static var isInitialised: Bool = false
    public var adView: TempoAdView?
    public var locationData: LocationData? = nil
    var tempoProfile: TempoProfile? = nil
    
    public init(tempoAdListener: TempoAdListener, appId: String!) {
        super.init()
        
        // On first instantiation by either ad type do some initial global checks
        if(!TempoAdController.isInitialised) {
            
            // Check for backups
            TempoDataBackup.checkHeldMetrics(completion: Metrics.pushMetrics)
            
            // Show as initialised moving forward and ignore this section
            TempoAdController.isInitialised = true;
        }
        
        // Create AdView object
        adView = TempoAdView(listener: tempoAdListener, appId: appId)
    }
    
    /// Public LOAD function for mediation adapters to call
    public func loadAd(isInterstitial: Bool, cpmFloor: Float?, placementId: String?) {
        
        // Load ad callback for when checks are satisfied
        let loadAdCallback: () -> Void = {
            DispatchQueue.main.async {
                self.adView!.loadAd (
                    isInterstitial: isInterstitial,
                    cpmFloor: cpmFloor,
                    placementId: placementId)
            }
        }
        
        // Create tempoProfile instance if does not already exist
        tempoProfile =  tempoProfile ?? TempoProfile(adView: adView!)
        
        // Check for lates location consent autorisation - after which run loadAds()
        // This does not take long, it's just run async on background thread
        tempoProfile?.doTaskAfterLocAuthUpdate(completion: loadAdCallback)
        
//        if(TempoProfile.locationState == LocationState.UNCHECKED)
//        {
//            print("⬆️ LoadAd ads after auth check: \(TempoProfile.locationState)")
//            tempoProfile?.doTaskAfterLocAuthUpdate(completion: loadAdCallback)
//        } else {
//            print("⬆️ LoadAd straight away: \(TempoProfile.locationState)")
//            loadAdCallback()
//        }
        
//        // Load ad when checks are done
//        adView!.loadAd (
//            isInterstitial: isInterstitial,
//            cpmFloor: cpmFloor,
//            placementId: placementId)
    }
    
    
    /// Public SHOW function for mediation adapters to call
    public func showAd(parentViewController: UIViewController?) {
        //adView!.showAd(parentVC: parentViewController)
        
        // Load ad callback for when checks are satisfied
        let showAdCallback: () -> Void = {
            DispatchQueue.main.async {
                self.adView!.showAd(parentVC: parentViewController)
            }
        }
        
        // Create tempoProfile instance if does not already exist
        tempoProfile =  tempoProfile ?? TempoProfile(adView: adView!)
        
        // Check for lates location consent autorisation - after which run loadAds()
        // This does not take long, it's just run async on background thread
        tempoProfile?.doTaskAfterLocAuthUpdate(completion: showAdCallback)
    }
    

    
//    /// Consent callback handler that updates global value for metrics and loads ad
//    public func handleLocationConsentAndLoadAd(isInterstitial: Bool, cpmFloor: Float?, placementId: String?) {
//        
//        // Update the local variable (classic 'current_x' type)
//        adView?.locationConsent = TempoProfile.locData?.lc ?? ""
//        
//        //adView?.locationData = locData
//        TempoUtils.Say(msg: "TempoLocationConsent: \(TempoProfile.locData?.lc ?? "???")")
//        
//        DispatchQueue.main.async {
//            self.loadAd(isInterstitial: isInterstitial, cpmFloor: cpmFloor, placementId: placementId)
//        }
//    }
    
    
    /// Public LOAD function for internal testing with specific campaign ID
    public func loadSpecificAd(isInterstitial: Bool, campaignId:String){
        adView!.loadSpecificCampaignAd(
            isInterstitial: isInterstitial,
            campaignId: campaignId)
    }
    
    
    
    /* --------------- DELETE ---------------*/
    //    /// Creates TempoLocation object and calls checker function with handler callback
    //    public func checkLocationConsentAndLoad(isInterstitial: Bool, cpmFloor: Float?, placementId: String?) {
    //        if(adView != nil) {
    //            tempoProfile = TempoProfile(adView: adView!)
    ////
    ////            let myParameterlessMethod: () -> Void = {
    ////                DispatchQueue.main.async {
    ////                    self.loadAd(isInterstitial: isInterstitial, cpmFloor: cpmFloor, placementId: placementId)
    ////                }
    ////            }
    ////
    //            //tempoProfile?.doTaskAfterLocAuthUpdate(completion: myParameterlessMethod)
    //            //tempoProfile?.checkLocConsent(completion: self.handleLocationConsentAndLoadAd, isInterstitial: isInterstitial, cpmFloor: cpmFloor, placementId: placementId)
    //        } else {
    //            TempoUtils.Shout(msg: "AdView was nil, could not continue with ad load")
    //        }
    //    }
}
