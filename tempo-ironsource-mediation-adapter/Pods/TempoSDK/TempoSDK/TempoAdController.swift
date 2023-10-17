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
    
    /// Public LOAD function for internal testing with specific campaign ID
    public func loadSpecificAd(isInterstitial: Bool, campaignId:String){
        adView!.loadSpecificCampaignAd(
            isInterstitial: isInterstitial,
            campaignId: campaignId)
    }
}
