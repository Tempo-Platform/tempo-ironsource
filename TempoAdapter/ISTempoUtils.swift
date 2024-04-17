import Foundation
import IronSource

public class ISTempoUtils {
    
    private static let testState = false
    
    public static func getAppId(adData: ISAdData) -> String {
        let adDataAppId = adData.getString("appId")
        return adDataAppId ?? "NO_APP_ID"
    }
    
    public static func getCpmFloor(adData: ISAdData) -> String {
        let adDataCpmFloor = adData.getString("cpmFloor")
        return adDataCpmFloor ?? "NO_CPM_FLOOR"
    }
    
    public static func adUnitStringer(adInfo: ISAdInfo!) -> String {
        return "\(adInfo.ad_unit), \(adInfo.ad_network), Instance: [\(adInfo.instance_name), \(adInfo.instance_id)]"
    }
    
    public static func adUnitDataStringer(adData: ISAdData!) -> String {
        return "\(getAppId(adData: adData)) | \(getCpmFloor(adData: adData))"
    }
    
    public static func sayAdType(isInterstitial: Bool) -> String {
        return isInterstitial ? "INTERSTITIAL" : "REWARDED"
    }
}
