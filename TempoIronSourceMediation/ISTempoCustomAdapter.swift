import Foundation
import IronSource
import TempoSDK

@objc(ISTempoCustomAdapter)
public class ISTempoCustomAdapter: ISBaseNetworkAdapter {
 
    public static let  ADAPTER_TYPE = "IRONSOURCE"
    public static let customAdapterVersion = "1.2.3"
    public static var dynSdkVersion = "1.4.5"
    
    
    public override func `init` (_ adData: ISAdData, delegate: ISNetworkInitializationDelegate) {
       print("💥 ISTempoCustomAdapter.init() \(getDataStuff(adData: adData))")
       // handle errors TODO: How to detect errors
       if (false) {
          delegate.onInitDidFailWithErrorCode(ISAdapterErrors.missingParams.rawValue, errorMessage: "Fail to init SDK")
          return
       }
       // init success
       delegate.onInitDidSucceed()
       return
    }
    
    
    public override func networkSDKVersion() -> String {
        return ISTempoCustomAdapter.dynSdkVersion
    }
    
    public override func adapterVersion() -> String {
        return ISTempoCustomAdapter.customAdapterVersion
    }
    
    private func getDataStuff(adData: ISAdData) -> String {
        let adDataAdTag = adData.getString("adUnit")
        // print("💥 adDataAdTag: \(adDataAdTag ?? "NO_AD_TAG")")
        return adDataAdTag ?? "NO_AD_TAG"
    }
}
