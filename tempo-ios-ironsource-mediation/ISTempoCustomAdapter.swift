import Foundation
import IronSource
import TempoSDK

@objc(ISTempoCustomAdapter)
public class ISTempoCustomAdapter: ISBaseNetworkAdapter {
 
    public static let ADAPTER_TYPE = "IRONSOURCE"
    public static let customAdapterVersion = "1.0.3"
    public static var dynSdkVersion = "1.0.6"
    
    /// SDK initialisation handler
    public override func `init` (_ adData: ISAdData, delegate: ISNetworkInitializationDelegate) {
       
       if (false) {
          delegate.onInitDidFailWithErrorCode(ISAdapterErrors.missingParams.rawValue, errorMessage: "Fail to init SDK")
          return
       }
        
       // init success
       delegate.onInitDidSucceed()
       return
    }
    
    /// Returns latest Tempo SDK version
    public override func networkSDKVersion() -> String {
        return ISTempoCustomAdapter.dynSdkVersion
    }
    
    /// Returns latest ironSource/Tempo custom adapter version
    public override func adapterVersion() -> String {
        return ISTempoCustomAdapter.customAdapterVersion
    }
}
