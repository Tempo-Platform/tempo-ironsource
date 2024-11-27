
import Foundation
import CoreLocation


public class ResponseBadRequest: Decodable {
    var error: String?
    var status: String?
    
    public func outputValues() {
        TempoUtils.Warn(msg: "[400]: status=\(status ?? "nil"), error=\(error ?? "nil")")
    }
}

public class ResponseUnprocessable: Decodable {
    var detail: [UnprocessableDetail]?
    
    public func outputValues() {
        if(detail != nil && detail!.count > 0) {
            for detail in detail! {
                TempoUtils.Warn(msg: "[422]: msg=\(detail.msg ?? "nil"), type=\(detail.type ?? "nil"), loc=\(detail.loc ?? ["n/a"])")
            }
        }
    }
}

public class UnprocessableDetail: Decodable {
    var loc: [String]?
    var msg: String?
    var type: String?
    
    private enum CodingKeys: String, CodingKey {
            case loc
            case msg
            case type
        }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
            loc = try container.decodeIfPresent([String].self, forKey: .loc)
            msg = try container.decodeIfPresent(String.self, forKey: .msg)
            type = try container.decode(String.self, forKey: .type)
        }
    
}


public class ResponseSuccess: Decodable {
    var status: String?
    var cpm: Float?
    var id: String?
    var location_url_suffix: String?
    
    public func outputValues() {
        TempoUtils.Say(msg: "[200]: Status=\(status ?? "nil"), CampaignID=\(id ?? "nil"), CPM=\(cpm ?? 0), Suffix=\(location_url_suffix ?? "nil")", absoluteDisplay: true)
    }
}
    
    /**
     * Global tools to use within the Tempo SDK module
     */
public class TempoUtils {
    
    /// Log for URGENT output with 🔴 marker - not to be used in production
    public static func Shout(msg: String) {
        if(Constants.isVerboseDebugging) {
            print("🔴 TempoSDK: \(msg)");
        }
    }
    
    /// Log for URGENT output with 🔴 marker, even when TESTING is on - not to be used in production
    public static func Shout(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("🔴 TempoSDK: \(msg)");
        } else if (Constants.isVerboseDebugging) {
            // Nothing - muted
        }
    }
    
    /// Log for general test  output -, never shows in production
    public static func Say(msg: String) {
        if(Constants.isVerboseDebugging) {
            print("🟣 TempoSDK: \(msg)");
        }
    }
    
    /// Log for general output with - option of toggling production output or off completely
    public static func Say(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("TempoSDK: \(msg)");
        } else if (Constants.isVerboseDebugging) {
            // Nothing - muted
        }
    }
    
    /// Log for WARNING output with ⚠️ marker - not to be used in production
    public static func Warn(msg: String) {
        if(Constants.isVerboseDebugging) {
            print("⚠️ TempoSDK: \(msg)");
        }
    }
    
    /// Log for WARNING output with ⚠️ marker, option of toggling production output or off completely
    public static func Warn(msg: String, absoluteDisplay: Bool) {
        if (absoluteDisplay) {
            print("⚠️ TempoSDK: \(msg)");
        } else if (Constants.isVerboseDebugging) {
            // Nothing - muted
        }
    }
    
    /// Returns web URL of ad content with customised parameters
    public static func getFullWebUrl(isInterstitial: Bool, campaignId: String, urlSuffix: String?) throws -> String {
        var webAdUrl: String
        
        do{
            guard let checkedCampaignId = try checkForTestCampaign(campaignId: campaignId) else {
                TempoUtils.Warn(msg: "No valid campaign ID, cannot continue")
                throw WebURLError.invalidCampaignId // TODO: When is this caught, here or calling method?
            }
         
            if(isInterstitial) {
                webAdUrl = "\(getInterstitialUrl())/\(checkedCampaignId)"
            }
            else {
                webAdUrl = "\(getRewardedUrl())/\(checkedCampaignId)"
            }
            
            // If additional URL suffix valid, place at the end of the string
            if let suffix = urlSuffix, !suffix.isEmpty {
                webAdUrl.append("\(suffix)")
            }
            
            TempoUtils.Say(msg: "🌏 Web URL: \(webAdUrl)")
            
            return webAdUrl
            
        } catch WebURLError.invalidCustomCampaignID {
            throw WebURLError.invalidCustomCampaignID
        } catch {
            throw WebURLError.invalidCampaignId
        }
    }
    
    /// Checks local UI testing variables to see if there is a custom Campaign ID to overwrite the one returned from ads API
    internal static func checkForTestCampaign(campaignId: String!) throws -> String! {
        
        if(campaignId != nil && !campaignId.isEmpty) {
            
            if (TempoTesting.instance?.isTestingCustomCampaigns ?? false) {
                guard let customCampaignId = TempoTesting.instance?.customCampaignId?.trimmingCharacters(in: .whitespacesAndNewlines), !customCampaignId.isEmpty else {
                    throw WebURLError.invalidCustomCampaignID
                }
                
                return customCampaignId
            }
        }
        else{
            throw WebURLError.invalidCampaignId
        }
        
        
        return campaignId;
    }
    
    /// Returns URL for Rewarded Ads
    public static func getRewardedUrl() -> String {
        
        // For ease of reading
        let cw = Constants.Web.self
        
        // Check is TempoTesting inititalised, and is in DeployPreview mode. Then checks if DP version is valid.
        if let tester = TempoTesting.instance, tester.isTestingDeployVersion, let deployVersion = tester.currentDeployVersion {
            let deployPreviewUrl = "\(cw.ADS_DOM_PREFIX_URL_PREVIEW)\(deployVersion)\(cw.ADS_DOM_APPENDIX_URL_PREVIEW)\(cw.URL_REW)"
            TempoUtils.Say(msg: "DeployPreview (R) URL = \(deployPreviewUrl)")
            return deployPreviewUrl
        }
        
        // If non-DP, return env-based address
        switch(Constants.environment) {
        case .STG:
            return "\(cw.ADS_DOM_URL_STG)/\(cw.URL_REW)"
        case .PRD:
            return "\(cw.ADS_DOM_URL_PROD)/\(cw.URL_REW)"
        case .DEV:
            fallthrough
        default:
            return "\(cw.ADS_DOM_URL_DEV)/\(cw.URL_REW)"
        }
    }
    
    /// Returns URL for Interstitial Ads
    public static func getInterstitialUrl() -> String {
        
        // For ease of reading
        let cw = Constants.Web.self
        
        // Check is TempoTesting inititalised, and is in DeployPreview mode. Then checks if DP version is valid.
        if let tester = TempoTesting.instance, tester.isTestingDeployVersion, let deployVersion = tester.currentDeployVersion {
            let deployPreviewUrl = "\(cw.ADS_DOM_PREFIX_URL_PREVIEW)\(deployVersion)\(cw.ADS_DOM_APPENDIX_URL_PREVIEW)\(cw.URL_INT)"
            TempoUtils.Say(msg: "DeployPreview (I) URL = \(deployPreviewUrl)")
            return deployPreviewUrl
        }
        
        // If non-DP, return env-based address
        switch(Constants.environment) {
        case .STG:
            return "\(cw.ADS_DOM_URL_STG)/\(cw.URL_INT)"
        case .PRD:
            return "\(cw.ADS_DOM_URL_PROD)/\(cw.URL_INT)"
        case .DEV:
            fallthrough
        default:
            return "\(cw.ADS_DOM_URL_DEV)/\(cw.URL_INT)"
        }
    }
    
    /// Returns REST-ADS-API url based on current environment
    public static func getAdsApiUrl() -> String {
        
        // For ease of reading
        let cw = Constants.Web.self
        
        // Return env-based ads-api URL
        switch(Constants.environment){
        case .STG:
            return cw.ADS_API_URL_STG
        case .PRD:
            return cw.ADS_API_URL_PROD
        case .DEV:
            fallthrough
        default:
            return cw.ADS_API_URL_DEV
        }
    }
    
    /// Returns METRICS url based on current environment
    public static func getMetricsUrl() -> String {
        
        // For ease of reading
        let cw = Constants.Web.self
        
        // Return env-based Metric URL
        switch(Constants.environment){
        case .STG:
            return cw.METRICS_URL_STG
        case .PRD:
            return cw.METRICS_URL_PROD
        case .DEV:
            fallthrough
        default:
            return cw.METRICS_URL_DEV
        }
    }
    
    /// Retuns string of 'INTERSTITIAL' or 'REWARDED' for debugging purposes
    public static func getAdTypeString(isInterstitial: Bool) -> String {
        return isInterstitial ? "INTERSTITIAL": "REWARDED"
    }
    
    /// Opens external browser on device at given URL
    public static func openUrlInBrowser(url: String) {
        if let validatedUrl = URL(string: url) {
            TempoUtils.Say(msg: "Opening URL: \(url)")
            UIApplication.shared.open(validatedUrl, options: [:], completionHandler: nil)
        }
    }
    
    /// Checks if string begins/ends with "{" / "}"
    public static func isPossiblyJSONObject(msg: String) -> Bool {
        // Trim whitespace and newlines to avoid false negatives
        let trimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
    }
}
