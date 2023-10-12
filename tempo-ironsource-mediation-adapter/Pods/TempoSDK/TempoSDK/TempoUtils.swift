
import Foundation
import CoreLocation

/**
 * Global tools to use within the Tempo SDK module
 */
public class TempoUtils {
    
    /// Log for URGENT output with 💥 marker - not to be used in production
    public static func Shout(msg: String) {
        if(Constants.isTesting) {
            print("💥 TempoSDK: \(msg)");
        }
    }

    /// Log for URGENT output with 💥 marker, even when TESTING is on - not to be used in production
    public static func Shout(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("💥 TempoSDK: \(msg)");
        } else if (Constants.isTesting) {
            // Nothing - muted
        }
    }

    /// Log for general test  output -, never shows in production
    public static func Say(msg: String) {
        if(Constants.isTesting) {
            print("🟣 TempoSDK: \(msg)");
        }
    }

    /// Log for general output with - option of toggling production output or off completely
    public static func Say(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("TempoSDK: \(msg)");
        } else if (Constants.isTesting) {
            // Nothing - muted
        }
    }
    
    /// Log for WARNING output with 💥 marker - not to be used in production
    public static func Warn(msg: String) {
        if(Constants.isTesting) {
            print("⚠️ TempoSDK: \(msg)");
        }
    }

    /// Log for WARNING output with 💥 marker, option of toggling production output or off completely
    public static func Warn(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("⚠️ TempoSDK: \(msg)");
        } else if (Constants.isTesting) {
            // Nothing - muted
        }
    }
    
    /// Returns HTML-ADS url based on current environment and adType/campaignID parameters
    public static func getAdsWebUrl(isInterstitial: Bool, campaignId: String) -> String! {
        let urlDomain = Constants.isProd ? Constants.Web.ADS_DOM_URL_PROD : Constants.Web.ADS_DOM_URL_DEV
        let adsWebUrl = "\(urlDomain)/\(isInterstitial ? Constants.Web.URL_INT : Constants.Web.URL_REW)/\(campaignId)/ios";
        Say(msg: "🌏 WEB URL: \(adsWebUrl)")
        return adsWebUrl
    }
    
    
    
    public static func getFullWebUrl(isInterstitial: Bool, campaignId: String) -> String {
        var webAdUrl: String
        
        let checkedCampaignId = checkForTestCampaign(campaignId: campaignId)
        
        if(isInterstitial) {
            webAdUrl = "\(getInterstitialUrl())/\(checkedCampaignId!)"
        }
        else {
            webAdUrl = "\(getRewardedUrl())/\(checkedCampaignId!)"
        }
        
        TempoUtils.Shout(msg: "🌏 Web URL: \(webAdUrl)")
        
        return webAdUrl
    }
    
    internal static func checkForTestCampaign(campaignId: String!) -> String! {
        
        let customCampaignTrimmed: String? = TempoTesting.instance?.customCampaignId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidString = customCampaignTrimmed?.isEmpty ?? true
        //print("💥 customCampaignTrimmed: \(customCampaignTrimmed ?? "NOTHING") | invalidString: \(invalidString)")
     
        if (!invalidString && (TempoTesting.instance?.isTestingCustomCampaigns ?? false)) {
            return TempoTesting.instance?.customCampaignId
        }
        
        return campaignId
    }
    
    public static func getRewardedUrl() -> String {
        if((TempoTesting.instance?.isTestingDeployVersion ?? false) && TempoTesting.instance?.currentDeployVersion != nil) {
            let deployPreviewUrl = Constants.Web.ADS_DOM_PREFIX_URL_PREVIEW +
            (TempoTesting.instance?.currentDeployVersion)! +
            Constants.Web.ADS_DOM_APPENDIX_URL_PREVIEW +
            Constants.Web.URL_REW
            
            TempoUtils.Say(msg: "DeployPreview (R) URL = \(deployPreviewUrl)")
            
            return deployPreviewUrl
        }
        
        if Constants.isProd {
            return "\(Constants.Web.ADS_DOM_URL_PROD)/\(Constants.Web.URL_REW)"
        }
        else {
            return "\(Constants.Web.ADS_DOM_URL_DEV)/\(Constants.Web.URL_REW)"
        }
    }
    
    public static func getInterstitialUrl() -> String {
        if((TempoTesting.instance?.isTestingDeployVersion ?? false) && TempoTesting.instance?.currentDeployVersion != nil) {
            let deployPreviewUrl = Constants.Web.ADS_DOM_PREFIX_URL_PREVIEW +
            (TempoTesting.instance?.currentDeployVersion)! +
            Constants.Web.ADS_DOM_APPENDIX_URL_PREVIEW +
            Constants.Web.URL_INT
            
            TempoUtils.Say(msg: "DeployPreview (R) URL = \(deployPreviewUrl)")
            
            return deployPreviewUrl
        }
        
        if Constants.isProd {
            return "\(Constants.Web.ADS_DOM_URL_PROD)/\(Constants.Web.URL_INT)"
        }
        else {
            return "\(Constants.Web.ADS_DOM_URL_DEV)/\(Constants.Web.URL_INT)"
        }
    }
    
    /// Returns REST-ADS-API url based on current environment
    public static func getAdsApiUrl() -> String {
        return Constants.isProd ? Constants.Web.ADS_API_URL_PROD : Constants.Web.ADS_API_URL_DEV;
    }
    
    /// Returns METRICS url based on current environment
    public static func getMetricsUrl() -> String {
        return Constants.isProd ? Constants.Web.METRICS_URL_PROD : Constants.Web.METRICS_URL_DEV;
    }
    
    /// Retuns string of 'INTERSTITIAL' or 'REWARDED' for debugging purposes
    public static func getAdTypeString(isInterstitial: Bool) -> String {
        return isInterstitial ? "INTERSTITIAL": "REWARDED"
    }
    
    public static func requestLocationDirectly(listener: TempoAdListener) {
        let tempView =  TempoAdView(listener: listener, appId: "")
        let tempoProfile = TempoProfile(adView:  tempView )
        tempoProfile.requestLocationConsentNowAsTesting()
    }
    
//    public static func hasLocationServicesConsent() {
//        let tempoLoc = TempoLocation()
//        tempoLoc.checkLocationServicesConsent(completion: handleLocationConsent)
//    }
    
    public static func handleLocationConsent(consentType: Constants.LocationConsent) {
        print("💥💥💥💥💥 \(consentType)")
    }
}
