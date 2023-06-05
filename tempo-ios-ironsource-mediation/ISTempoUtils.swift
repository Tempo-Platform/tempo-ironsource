//
//  ISTempoUtils.swift
//  tempo-ironsource-mediation
//
//  Created by Stephen Baker on 1/6/2023.
//

import Foundation
import IronSource

public class ISTempoUtils {
    
    private static let testState = false
    
    public static func getAppId(adData: ISAdData) -> String {
        let adDataAppId = adData.getString("appId")
        return adDataAppId ?? "NO_APP_ID"
    }
    
    public static func getAddTag(adData: ISAdData) -> String {
        let adDataAdTag = adData.getString("adTag")
        return adDataAdTag ?? "NO_AD_TAG"
    }
    
    public static func getCpmFloor(adData: ISAdData) -> String {
        let adDataCpmFloor = adData.getString("cpmFloor")
        return adDataCpmFloor ?? "NO_CPM_FLOOR"
    }
    
    public static func shout(msg: String = "", showInProd: Bool = false, functStrion: String = #function) {
        if !testState {
            return
        }
        
        let outMsg = msg.isEmpty ? "" : "| \(msg)"
        print("💥 \(functStrion) \(outMsg)")
    }
    
    public static func adUnitStringer(adInfo: ISAdInfo!) -> String {
        return "\(adInfo.ad_unit), \(adInfo.ad_network), Instance: [\(adInfo.instance_name), \(adInfo.instance_id)]"
    }
    
    public static func adUnitDataStringer(adData: ISAdData!) -> String {
        return "\(getAppId(adData: adData)) | \(getAddTag(adData: adData))"
    }
    
    public static func sayAdType(isInterstitial: Bool) -> String {
        return isInterstitial ? "INTERSTIIAL" : "REWARDED"
    }
}
