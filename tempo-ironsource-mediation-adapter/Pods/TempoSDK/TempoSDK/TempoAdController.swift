import Foundation
import UIKit

/**
 *  Initialises when app loads. This is the object that mediation adapters call to load/show ads
 */
public class TempoAdController: NSObject {
    
    static var isInitialised: Bool = false
    public var adView: TempoAdView?
    public var locationData: LocationData? = nil
    //var tempoProfile: TempoProfile? = nil
   
    
    public init(tempoAdListener: TempoAdListener, appId: String!) {
        super.init()
        
        // On first instantiation by either ad type do some initial global checks
        if(!TempoAdController.isInitialised) {
            
            // Check for backups
            do{
                try TempoDataBackup.checkHeldMetrics { metricsArray, url in
                    try Metrics.pushMetrics(currentMetrics: &metricsArray, backupUrl: url)
                }
            } catch let error {
                // Handle specific errors or log them
                if let metricsError = error as? MetricsError {
                    switch metricsError {
                        case .missingJsonString: TempoUtils.warn(msg: "Missing JSON string error: \(metricsError)")
                        case .decodingFailed(let decodingError): TempoUtils.warn(msg: "Decoding failed: \(decodingError)")
                        default: TempoUtils.warn(msg: "Failed to push backup metrics")
                    }
                } else {
                    // Handle other generic errors
                    TempoUtils.warn(msg: "Error while handling backup metrics: \(error)")
                }
            }
            
            // Show as initialised moving forward and ignore this section
            TempoAdController.isInitialised = true;
        }
        
        // Create AdView object
        adView = TempoAdView(listener: tempoAdListener, appId: appId)
    }
    
    /// Public LOAD function for mediation adapters to call
    public func loadAd(isInterstitial: Bool, cpmFloor: Float?, placementId: String?) {
        DispatchQueue.main.async {
            self.adView!.loadAd (
                isInterstitial: isInterstitial,
                cpmFloor: cpmFloor,
                placementId: placementId)
        }
    }
        
    /// Public SHOW function for mediation adapters to call
    public func showAd(parentViewController: UIViewController?) {
        DispatchQueue.main.async {
            self.adView!.modalPresentationStyle = .fullScreen
            self.adView!.showAd(parentVC: parentViewController)
        }
    }
        
    /// Public LOAD function for internal testing with specific campaign ID {ONLY USED IN TESTING)
    public func loadSpecificAd(isInterstitial: Bool, campaignId:String) {
        adView!.loadSpecificCampaignAd(
            isInterstitial: isInterstitial,
            campaignId: campaignId)
    }
}
