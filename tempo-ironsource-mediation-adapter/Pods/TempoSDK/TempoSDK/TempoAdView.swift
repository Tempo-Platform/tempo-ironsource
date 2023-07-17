import Foundation
import UIKit
import WebKit
import AdSupport


public class TempoAdView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler  {
    
    var listener: TempoAdListener! // given value during init()
    var adapterVersion: String!
    var parentVC: UIViewController?
    var appId: String!
    
    var solidColorView: FullScreenUIView!
    var webView: FullScreenWKWebView!
    var metricList: [Metric] = []
    
    var observation: NSKeyValueObservation?
    var previousParentBGColor: UIColor?
    
    // Session instance properties
    var uuid: String?
    var adId: String?
    var campaignId: String?
    var placementId: String?
    var isInterstitial: Bool?
    var sdkVersion: String!
    var cpmFloor: Float?
    var adapterType: String?
    var consent: Bool?
    var currentConsentType: String?
    var geo: String?

    public init(listener: TempoAdListener, appId: String) {
        super.init(nibName: nil, bundle: nil)
        
        self.listener = listener
        self.appId = appId
        
        sdkVersion = Constants.SDK_VERSIONS
        adapterVersion = self.listener.getAdapterVersion()
        adapterType = self.listener.getAdapterType()
        consent = self.listener.hasUserConsent()
        adId = getAdId()
    }
    
    // Ingore requirement to implement required initializer ‘init(coder:) in it.
    @available(*, unavailable, message: "Nibs are unsupported")
    public required init?(coder aDecoder: NSCoder) {
        fatalError("Nibs are unsupported")
    }
    
    /// Prepares ad for current session (interstitial/reward)
    public func loadAd(isInterstitial: Bool, cpmFloor: Float?, placementId: String?) {
        TempoUtils.Say(msg: "loadAd() \(TempoUtils.getAdTypeString(isInterstitial: isInterstitial))", absoluteDisplay: true)
        
        // Create WKWebView instance
        self.setupWKWebview()
        
        // Update session values from paramters
        self.isInterstitial = isInterstitial
        self.placementId = placementId
        self.cpmFloor = cpmFloor ?? 0.0
        
        // Update session values from global checks
        uuid = UUID().uuidString
        geo = Constants.TEMP_GEO_US  // TODO: This will eventually need to be taken from mediation parameters
        
        // Create ad load metrics with updated ad data
        self.addMetric(metricType: Constants.MetricType.LOAD_REQUEST)
        
        // Create and send ad request with latest data
        sendAdRequest()
    }
    
    /// Plays currently loaded ad for current session (interstitial/reward)
    public func showAd(parentVC: UIViewController?) {
        
        // Update parent VC
        self.parentVC = parentVC
        self.parentVC!.view.addSubview(solidColorView)
        
        // Send SHOW metric and call activate DISPLAYED listener
        addMetric(metricType: Constants.MetricType.SHOW)
        listener.onAdDisplayed(isInterstitial: self.isInterstitial ?? true)
        
        // Create JS statement to find video element and play.
        let script = Constants.JS.JS_FORCE_PLAY
        
        // Note: Method return type not recognised by WWebKit so we add null return.
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error playing video: \(error)")
            }
        }
    }
    
    /// Closes current WkWebView
    public func closeAd() {
        solidColorView.removeFromSuperview()
        webView.removeFromSuperview()
        webView = nil
        solidColorView = nil
        Metrics.pushMetrics(currentMetrics: &metricList, backupUrl: nil)
        listener.onAdClosed(isInterstitial: self.isInterstitial ?? true)
    }
    
    /// Test function used to test specific campaign ID using dummy values fo other metrics
    public func loadSpecificCampaignAd(isInterstitial: Bool, campaignId:String) {
        print("load specific url \(isInterstitial ? "INTERSTITIAL": "REWARDED")")
        self.setupWKWebview()
        uuid = "TEST"
        adId = "TEST"
        appId = "TEST"
        self.isInterstitial = isInterstitial
        //let urlComponent = isInterstitial ? TempoConstants.URL_INT : TempoConstants.URL_REW
        self.addMetric(metricType: "CUSTOM_AD_LOAD_REQUEST")
        //let url = URL(string: "https://ads.tempoplatform.com/\(urlComponent)/\(campaignId)/ios")!
        let url = URL(string: TempoUtils.getAdsWebUrl(isInterstitial: isInterstitial, campaignId: campaignId))!
        self.campaignId = campaignId
        self.webView.load(URLRequest(url: url))
    }
    
    // Cnecks is consented Ad ID exists and returns (nullable) value
    func getAdId() -> String! {
        // Get Advertising ID (IDFA) // TODO: add proper IDFA alternative here if we don't have Ad ID
        let advertisingIdentifier: UUID = ASIdentifierManager().advertisingIdentifier
        return advertisingIdentifier.uuidString != Constants.ZERO_AD_ID ? advertisingIdentifier.uuidString : nil
    }
    
    /// Generate REST-ADS-API web request with current session data
    func sendAdRequest() {
    
        // Create request string
        let components = createUrlComponents()
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        TempoUtils.Say(msg: "🌏 REST-ADS-API: " + (components.url?.absoluteString ?? "❌ URL STRING ?!"))
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            if error != nil {
                DispatchQueue.main.async {
                    self.sendAdFetchFailed(reason: "Invalid data error: \(error!.localizedDescription)")
                }
            }
            else if data == nil {
                DispatchQueue.main.async {
                    self.sendAdFetchFailed(reason: "Invalid data sent")
                }
            } else {
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    DispatchQueue.main.async {
                        self.sendAdFetchFailed(reason: "Invalid HTTP response")
                    }
                    return
                }
                do {
                    var validResponse = false
                    let json = try JSONSerialization.jsonObject(with: data!)
                    DispatchQueue.main.async {
                        if let jsonDict = json as? Dictionary<String, Any> {
                            if let status = jsonDict["status"] {
                                if let statusString = status as? String {
                                    if statusString == Constants.NO_FILL {
                                        self.listener.onAdFetchFailed(isInterstitial: self.isInterstitial ?? true)
                                        print("Tempo SDK: Failed loading the Ad. Received NO_FILL response from API.")
                                        self.addMetric(metricType: Constants.NO_FILL)
                                        validResponse = true
                                    } else if (statusString == Constants.OK) {
                                        
                                        // Loads ad from URL with id reference
                                        if let id = jsonDict["id"] {
                                            if let idString = id as? String {
                                                TempoUtils.Say(msg: "Ad Received \(jsonDict).")
                                                let url = URL(string: TempoUtils.getAdsWebUrl(isInterstitial: self.isInterstitial!, campaignId: idString))!
                                                self.campaignId = idString
                                                self.webView.load(URLRequest(url: url))
                                                validResponse = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if (!validResponse) {
                            self.sendAdFetchFailed(reason: "Invalid response from ad server")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.sendAdFetchFailed(reason: "Reason unknown")
                    }
                }
            }
        })
        task.resume()
    }
    
    /// Create URL components with current ad data for REST-ADS-API web request
    func createUrlComponents() -> URLComponents {
        
        // Get URL domain/path
        var components = URLComponents(string: TempoUtils.getAdsApiUrl())!
        
        // Add URL parameters
        components.queryItems = [
            URLQueryItem(name: Constants.URL.UUID, value: uuid),  // this UUID is unique per ad load
            URLQueryItem(name: Constants.URL.AD_ID, value: adId),
            URLQueryItem(name: Constants.URL.APP_ID, value: appId),
            URLQueryItem(name: Constants.URL.CPM_FLOOR, value: String(cpmFloor ?? 0.0)),
            URLQueryItem(name: Constants.URL.LOCATION, value: geo),
            URLQueryItem(name: Constants.URL.IS_INTERSTITIAL, value: String(isInterstitial!)),
            URLQueryItem(name: Constants.URL.SDK_VERSION, value: String(sdkVersion ?? "")),
            URLQueryItem(name: Constants.URL.ADAPTER_VERSION, value: String(adapterVersion ?? "")),
        ]
        
        // Only ad adapter_type if value exists or cause invalid response
        if adapterType != nil {
            components.queryItems?.append(URLQueryItem(name: Constants.URL.ADAPTER_TYPE, value: adapterType))
        }
        
        // Clean any '+' references with safe '%2B'
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        
        return components
    }
    
    func sendAdFetchFailed(reason: String) {
        print("Tempo SDK: Failed loading the Ad. \(reason).")
        self.listener.onAdFetchFailed(isInterstitial: self.isInterstitial ?? true)
        self.addMetric(metricType: Constants.MetricType.LOAD_FAILED)
    }
    
    /// Creates the custom WKWebView including safe areas, background color and pulls custom configurations
    private func setupWKWebview() {
        
        var safeAreaTop: CGFloat
        var safeAreaBottom: CGFloat
        if #available(iOS 13.0, *) {
            safeAreaTop = getSafeAreaTop()
            safeAreaBottom = getSafeAreaBottom()
        } else {
            safeAreaTop = 0.0
            safeAreaBottom = 0.0
        }
        webView = FullScreenWKWebView(frame: CGRect(
            x: 0,
            y: safeAreaTop,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height - safeAreaTop - safeAreaBottom
        ), configuration: self.getWKWebViewConfiguration())
        webView.scrollView.bounces = false
        
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        solidColorView = FullScreenUIView(frame: CGRect( x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        
        // ".black/#000" treated as transparent in Unity so making it a 'pseudo-black'
        solidColorView.backgroundColor = UIColor(red: 0.01, green: 0.01, blue:0.01, alpha: 1)
        solidColorView.addSubview(webView)
    }
    
    /// Creates and returns a custom configuration for the WkWebView object
    private func getWKWebViewConfiguration() -> WKWebViewConfiguration {
        
        // Create script that locks scalability and add to WK content controller
        let lockScaleScript: WKUserScript = WKUserScript(
            source: Constants.JS.LOCK_SCALE_SOURCE,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true)
        
        let userController = WKUserContentController()
        userController.add(self, name: "observer")
        userController.addUserScript(lockScaleScript)
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userController
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        }
        
        return configuration
    }
    
    /// Create controller that provides a way for JavaScript to post messages to a web view.
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        // Make sure body is at least a String
        if(message.body as? String != nil) {
            
            let webMsg = message.body as! String;
            
            // Send metric for web message
            self.addMetric(metricType: webMsg)
           
            // Can close ad
            if(webMsg == Constants.MetricType.CLOSE_AD){
                self.closeAd()
            }
            
            // Output metric message
            if(Constants.MetricType.METRIC_OUTPUT_TYPES.contains(webMsg))
            {
                print(webMsg)
            }
            
            // Show success when content load
            if(webMsg == Constants.MetricType.IMAGES_LOADED) {
                listener.onAdFetchSucceeded(isInterstitial: self.isInterstitial ?? true)
                self.addMetric(metricType: Constants.MetricType.LOAD_SUCCESS)
            }
        }
    }
    
    /// Create a new Metric instance based on current ad's class properties, and adds to Metrics array
    private func addMetric(metricType: String) {
        let metric = Metric(metric_type: metricType,
                            ad_id: self.adId,
                            app_id: self.appId,
                            timestamp: Int(Date().timeIntervalSince1970 * 1000),
                            is_interstitial: self.isInterstitial,
                            bundle_id: Bundle.main.bundleIdentifier!,
                            campaign_id: self.campaignId ?? "",
                            session_id: self.uuid!,
                            location: self.geo ?? "US",
                            placement_id: self.placementId ?? "",
                            os: "iOS \(UIDevice.current.systemVersion)",
                            sdk_version: self.sdkVersion ?? "",
                            adapter_version: self.adapterVersion ?? "",
                            cpm: self.cpmFloor ?? 0.0,
                            adapter_type: self.adapterType,
                            consent: self.consent,
                            consent_type: nil
//                            ad_id: adId,
//                            app_id: appId,
//                            is_interstitial: isInterstitial,
//                            campaign_id: campaignId ?? "",
//                            session_id: uuid!,
//                            location: geo ?? "US",
//                            placement_id: placementId ?? "",
//                            sdk_version: sdkVersion ?? "",
//                            adapter_version: adapterVersion ?? "",
//                            cpm: cpmFloor ?? 0.0,
//                            adapter_type: adapterType,
//                            consent: consent,
//                            consent_type: nil
        )
        
        self.metricList.append(metric)
        
        if (Constants.MetricType.METRIC_SEND_NOW.contains(metricType)) {
            Metrics.pushMetrics(currentMetrics: &metricList, backupUrl: nil)
        }
    }
    
//    /// Sends latest version of Metrics array to Tempo backend and then clears
//    internal func pushMetrics(backupUrl: URL?) {
//
//        // Create the url with NSURL
//        let url = URL(string: TempoUtils.getMetricsUrl())!
//
//        // Create the session object
//        let session = URLSession.shared
//
//        // Now create the Request object using the url object
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST" //set http method as POST
//
//        // Declare local metric/data varaibles
//        let metricData: Data?
//        var metricListCopy = [Metric]()
//
//        // Assigned values depend on whether it's backup-resend or standard push
//        if(backupUrl != nil)
//        {
//            let backupMetricList = TempoDataBackup.fileMetric[backupUrl!]
//            metricData = try? JSONEncoder().encode(backupMetricList)
//        }
//        else {
//            metricListCopy = metricList;
//            metricData = try? JSONEncoder().encode(metricList)
//            metricList.removeAll()
//        }
//        request.httpBody = metricData // pass dictionary to data object and set it as request body
//
//        // Prints out metrics types being sent in this push
//        if(Constants.IS_TESTING)
//        {
//            let outMetricList = backupUrl != nil ? TempoDataBackup.fileMetric[backupUrl!]: metricListCopy
//            if(outMetricList != nil)
//            {
//                var metricOutput = "Metrics: "
//                for metric in outMetricList!{
//                    metricOutput += "\n  - \(metric.metric_type ?? "<TYPE_UNKNOWN>") | \(metric.sdk_version)/\(metric.adapter_version)"
//                }
//                print("📊 \(metricOutput)")
//                print("📊 Payload: " + String(data: metricData ?? Data(), encoding: .utf8)!)
//            }
//        }
//
//        // HTTP Headers
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.addValue("application/json", forHTTPHeaderField: "Accept")
//        request.addValue(String(Int(Date().timeIntervalSince1970)), forHTTPHeaderField: Constants.Web.METRIC_TIME_HEADER)
//
//        // Create dataTask using the session object to send data to the server
//        let task = session.dataTask(with: request, completionHandler: { data, response, error in
//            guard error == nil else {
//                if(backupUrl == nil) {
//                    print("Data did not send, creating backup")
//                    TempoDataBackup.sendData(metricsArray: metricListCopy)
//                }
//                else{
//                    print("Data did not send, keeping backup: \(backupUrl!)")
//                }
//                return
//            }
//
//            // Output details of response
//            if(Constants.IS_TESTING)
//            {
//                do{
//                    let dataDictionary = try JSONSerialization.jsonObject(with: data!, options: [])
//                    print("Response dictionary is: \(dataDictionary)")
//
//                } catch let error as NSError {
//                    if(Constants.IS_TESTING) {
//                        print("Error: \(error.localizedDescription)")
//                    }
//                }
//            }
//
//            // If metrics were backeups - and were successfully resent - delete the file fro mdevice storage
//            if(backupUrl != nil)
//            {
//                if(Constants.IS_TESTING)
//                {
//                    print("Removing backup: \(backupUrl!) (x\(TempoDataBackup.fileMetric[backupUrl!]!.count))")
//                }
//
//                // Remove metricList from device storage
//                TempoDataBackup.removeSpecificMetricList(backupUrl: backupUrl!)
//            }
//            else
//            {
//                if(Constants.IS_TESTING) {
//                    print("Standard Metric sent (x\(metricListCopy.count))")
//                }
//
//                if let httpResponse = response as? HTTPURLResponse {
//                    //print("Tempo status code: \(httpResponse.statusCode)")
//                    
//                    switch(httpResponse.statusCode)
//                    {
//                    case 200:
//                        if(Constants.IS_TESTING)  {
//                            print("📊 Passed metrics - do not backup: \(httpResponse.statusCode)")
//                        }
//                        break
//                    case 400:
//                        fallthrough
//                    case 422:
//                        if(Constants.IS_TESTING)  {
//                            print("📊 Passed/Bad metrics - do not backup: \(httpResponse.statusCode)")
//                        }
//                        break
//                    default:
//                        if(Constants.IS_TESTING)  {
//                            print("📊 Non-tempo related error - backup: \(httpResponse.statusCode)")
//                        }
//                        TempoDataBackup.sendData(metricsArray: metricListCopy)
//                    }
//                }
//            }
//        })
//
//        task.resume()
//    }
//
//    /// Checks once if there are any backed up metrics and runs if found // TODO : MOVE TO BACKYPS?
//    ///
//    public func checkHeldMetrics() {
//        // See if check has already been called
//        if(TempoDataBackup.readyForCheck) {
//            // Request creation of backup metrics dictionary
//            TempoDataBackup.initCheck()
//            //print("Resending: \(TempoDataBackup.fileMetric.count)")
//
//            // Cycles through each stored arrays and resends
//            for url in TempoDataBackup.fileMetric.keys
//            {
//                pushMetrics(backupUrl: url)
//            }
//
//            // Prevents from being checked again this session. If network is failing, no point retrying during this session
//            TempoDataBackup.readyForCheck = false
//        }
//    }
    
    @available(iOS 13.0, *)
    func getSafeAreaTop() -> CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        return keyWindow?.safeAreaInsets.top ?? 0
    }
    
    @available(iOS 13.0, *)
    func getSafeAreaBottom() -> CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        return keyWindow?.safeAreaInsets.bottom ?? 0
    }
}


class FullScreenWKWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0)
    }
}

class FullScreenUIView: UIView {
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}




//public struct Metric : Codable {
//    var metric_type: String?
//    var ad_id: String?
//    var app_id: String?
//    var timestamp: Int?
//    var is_interstitial: Bool?
//    var bundle_id: String = "unknown"
//    var campaign_id: String = "unknown"
//    var session_id: String = "unknown"
//    var location: String = "unknown"
//    var gender: String = "?"
//    var age_range: String = "unknown"
//    var income_range: String = "unknown"
//    var placement_id: String = "unknown"
//    var country_code: String? = TempoUserInfo.getIsoCountryCode2Digit()
//    var os: String = "unknown"
//    var sdk_version: String
//    var adapter_version: String
//    var cpm: Float
//    var adapter_type: String?
//    var consent: Bool?
//    var consent_type: String?
//}
