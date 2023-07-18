
import Foundation

/**
 * Global tools to use within the Tempo SDK module
 */
public class TempoUtils {
    
    /// Log for URGENT output with 💥 marker - not to be used in production
    public static func Shout(msg: String) {
        if(Constants.IS_TESTING) {
            print("💥 TempoSDK: \(msg)");
        }
    }

    /// Log for URGENT output with 💥 marker, even when TESTING is on - not to be used in production
    public static func Shout(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("💥 TempoSDK: \(msg)");
        } else if (Constants.IS_TESTING) {
            // Nothing - muted
        }
    }

    /// Log for general test  output -, never shows in production
    public static func Say(msg: String) {
        if(Constants.IS_TESTING) {
            print("TempoSDK: \(msg)");
        }
    }

    /// Log for general output with - option of toggling production output or off completely
    public static func Say(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("TempoSDK: \(msg)");
        } else if (Constants.IS_TESTING) {
            // Nothing - muted
        }
    }
    
    /// Log for WARNING output with 💥 marker - not to be used in production
    public static func Warn(msg: String) {
        if(Constants.IS_TESTING) {
            print("⚠️ TempoSDK: \(msg)");
        }
    }

    /// Log for WARNING output with 💥 marker, option of toggling production output or off completely
    public static func Warn(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("⚠️ TempoSDK: \(msg)");
        } else if (Constants.IS_TESTING) {
            // Nothing - muted
        }
    }
    
    /// Returns HTML-ADS url based on current environment and adType/campaignID parameters
    public static func getAdsWebUrl(isInterstitial: Bool, campaignId: String) -> String! {
        let urlDomain = Constants.IS_PROD ? Constants.Web.ADS_DOM_URL_PROD : Constants.Web.ADS_DOM_URL_DEV
        let adsWebUrl = "\(urlDomain)/\(isInterstitial ? Constants.Web.URL_INT : Constants.Web.URL_REW)/\(campaignId)/ios";
        Say(msg: "🌏 WEB URL: \(adsWebUrl)")
        return adsWebUrl
    }
    
    /// Returns REST-ADS-API url based on current environment
    public static func getAdsApiUrl() -> String {
        return Constants.IS_PROD ? Constants.Web.ADS_API_URL_PROD : Constants.Web.ADS_API_URL_DEV;
    }
    
    /// Returns METRICS url based on current environment
    public static func getMetricsUrl() -> String {
        return Constants.IS_PROD ? Constants.Web.METRICS_URL_PROD : Constants.Web.METRICS_URL_DEV;
    }
    
    /// Retuns string of 'INTERSTITIAL' or 'REWARDED' for debugging purposes
    public static func getAdTypeString(isInterstitial: Bool) -> String {
        return isInterstitial ? "INTERSTITIAL": "REWARDED"
    }
}
