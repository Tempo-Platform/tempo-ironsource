//
//  ISTempoUtils.swift
//  tempo-ironsource-mediation
//
//  Created by Stephen Baker on 1/6/2023.
//

import Foundation
import IronSource

public class ISTempoUtils {
    
    public static func getAppId(adData: ISAdData) -> String {
        let adDataAppId = adData.getString("appId")
        return adDataAppId ?? "NO_APP_ID"
    }
    
    public static func getAddTag(adData: ISAdData) -> String {
        let adDataAdTag = adData.getString("adTag")
        return adDataAdTag ?? "NO_AD_TAG"
    }
    
    public static func bangLog(msg: String = "", functStrion: String = #function) {
        let outMsg = msg.isEmpty ? "" : "| \(msg)"
        print("💥 \(functStrion) \(outMsg)")
    }
    
    public static func adUnitStringer(adInfo: ISAdInfo!) -> String {
        return "\(adInfo.ad_unit), \(adInfo.ad_network), \(adInfo.instance_name)[\(adInfo.instance_id)]"//, \(adInfo.description)"
    }
    
    public static func adUnitDataStringer(adData: ISAdData!) -> String {
        return "\(getAppId(adData: adData)) | \(getAddTag(adData: adData))"
    }
    
    public static func getTypeWord(isInterstitial: Bool) -> String {
        return isInterstitial ? "INTERSTIIAL" : "REWARDED"
    }
}
