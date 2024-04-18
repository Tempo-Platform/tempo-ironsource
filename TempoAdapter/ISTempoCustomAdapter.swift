import Foundation
import IronSource
import TempoSDK

@objc(ISTempoCustomAdapter)
public class ISTempoCustomAdapter: ISBaseNetworkAdapter {
 
    public static let ADAPTER_TYPE = "IRONSOURCE"
    public static let TEMPO_ADAPTER_VERSION = "1.5.2-rc.6"
    
    /// SDK initialisation handler
    public override func `init` (_ adData: ISAdData, delegate: ISNetworkInitializationDelegate) {
        
        // Currently no 'fail' scenarios
//       if (false) {
//          delegate.onInitDidFailWithErrorCode(ISAdapterErrors.missingParams.rawValue, errorMessage: "Fail to init SDK")
//          return
//       }
        
       // init success
       delegate.onInitDidSucceed()
       return
    }
    
    /// Returns latest Tempo SDK version
    public override func networkSDKVersion() -> String {
        return Constants.SDK_VERSIONS
    }
    
    /// Returns latest ironSource/Tempo custom adapter version
    public override func adapterVersion() -> String {
        return ISTempoCustomAdapter.TEMPO_ADAPTER_VERSION
    }
}
