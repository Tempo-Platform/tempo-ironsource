import Foundation
import UIKit
import WebKit
import AdSupport

public class TempoAdView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler  {
    var listener: TempoAdListener!
    var parentVC: UIViewController?
    var webViewWithBackground: FullScreenUIView!
    var webView: FullScreenWKWebView!
    
    // Ad state - followed for catching WebView crashes
    enum AdState { case dormant, loading, showing }
    var adState: AdState! = AdState.dormant
    
    // Session instance properties
    var appId: String!
    var uuid: String?
    var adId: String?
    var campaignId: String?
    var placementId: String?
    var isInterstitial: Bool = true // eventually need to make this a enum for undefined
    var sdkVersion: String!
    var adapterVersion: String!
    var cpmFloor: Float?
    var adapterType: String?
    var consent: Bool?
    var currentConsentType: String?
    internal var countryCode: String? = CountryCode.getIsoCountryCode2Digit()
    var locationData: LocationData?
    var metricList: [Metric] = []
    var lastestURL: String? = nil
    
    public init(listener: TempoAdListener, appId: String) {
        super.init(nibName: nil, bundle: nil)
        
        self.listener = listener
        self.appId = appId
        
        sdkVersion = Constants.SDK_VERSIONS
        adapterVersion = self.listener.getTempoAdapterVersion()
        adapterType = self.listener.getTempoAdapterType()
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
        
        // Update state to LOADING
        adState = AdState.loading
        
        // Create WKWebView instance
        if(!self.setupWKWebview()) {
            DispatchQueue.main.async {
                self.sendAdFetchFailed(reason: "Could not create WKWebView")
            }
            return
        }
        
        // Update session values from paramters
        self.isInterstitial = isInterstitial
        self.placementId = placementId
        self.cpmFloor = cpmFloor ?? 0.0
        
        // Update session values from global checks
        uuid = UUID().uuidString
        //geo = CountryCode.getIsoCountryCode2Digit()  // TODO: This will eventually need to be taken from mediation parameters
        
        // Create ad load metrics with updated ad data
        self.addMetric(metricType: Constants.MetricType.LOAD_REQUEST)
        
        // Create and send ad request with latest data
        sendAdRequest()
    }
    
    /// Plays currently loaded ad for current session (interstitial/reward)
    public func showAd(parentVC: UIViewController?) {
        
        checkWebsiteConnectivity(urlString: lastestURL ?? "", parentViewController: parentVC, completion: handleWebsiteCheck)
    }
    
    
    
    func checkWebsiteConnectivity(urlString: String, parentViewController: UIViewController?, completion: @escaping (Bool, UIViewController?, Int?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false, parentViewController, nil)
            TempoUtils.Shout(msg: "🔵🔵🔵🔵🔵🔵🔵 checkWebsiteConnectivity: URL string guard error")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            guard error == nil else {
                TempoUtils.Shout(msg: "🔵🔵🔵🔵🔵🔵🔵 checkWebsiteConnectivity: URL Reponse guard error")
                completion(false, parentViewController, nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                TempoUtils.Shout(msg: "🔫🔫🔫🔫🔫🔫🔫 checkWebsiteConnectivity: URL request SUCCSSS")
                completion(true, parentViewController, httpResponse.statusCode)
            } else {
                TempoUtils.Shout(msg: "🔵🔵🔵🔵🔵🔵🔵 checkWebsiteConnectivity: URL request ERROR")
                completion(false, parentViewController, nil)
            }
        }
        
        task.resume()
    }
    
    
    func handleWebsiteCheck(success: Bool, parentVC: UIViewController?, responseCode: Int? ) {
        if(success) {
        
            switch(responseCode){
            case 200: 
                DispatchQueue.main.async {self.showOnceConnectionConfirmed(parentVC: parentVC) }
            default:
                listener.onTempoAdShowFailed(isInterstitial: isInterstitial, reason: "\(responseCode ?? -1)")
            }
        } else {
            listener.onTempoAdShowFailed(isInterstitial: isInterstitial, reason: "\(responseCode ?? -1)")
        }
    }
    
    private func showOnceConnectionConfirmed(parentVC: UIViewController?) {
        
        // Update parent VC with received value
        self.parentVC = parentVC
        
        // Make sure parentVC/webview are not nil
        if(self.parentVC == nil || self.webView == nil || self.webViewWithBackground == nil) {
            self.sendAdShowFailed(reason: "unexpected null object")
            self.closeAd()
            return
        }
        
        // Update adState
        adState = AdState.showing
        
        // Add content view
        self.parentVC!.view.addSubview(self.webViewWithBackground)
        
        // Send SHOW metric and call activate DISPLAYED listener
        addMetric(metricType: Constants.MetricType.SHOW)
        listener.onTempoAdDisplayed(isInterstitial: self.isInterstitial)
        
        // Create JS statement to find video element and play.
        let script = Constants.JS.JS_FORCE_PLAY
        
        // Note: Method return type not recognised by WKWebKit so we add null return.
        self.webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                TempoUtils.Warn(msg: "Error playing video: \(error)")
            }
        }
        
    }
    
    /// Closes current WkWebView
    public func closeAd() {
        adState = AdState.dormant
        webViewWithBackground?.removeFromSuperview()
        webView?.removeFromSuperview()
        webView = nil
        webViewWithBackground = nil
        
        // Send metrics regadless - check if needs to be retroactively updated to reflect new location data
        if(TempoProfile.locationState == .UNCHECKED || TempoProfile.locationState == .CHECKING) {
            pushHeldMetricsWithUpdatedLocationData()
            TempoProfile.locationState = .FAILED
        } else {
            Metrics.pushMetrics(currentMetrics: &metricList, backupUrl: nil)
        }
        
        // Invoke close callback
        listener?.onTempoAdClosed(isInterstitial: self.isInterstitial)
    }
    
    // Cnecks is consented Ad ID exists and returns (nullable) value
    func getAdId() -> String! {
        
        // Get Advertising ID (IDFA) // TODO: add proper IDFA alternative here if we don't have Ad ID
        let advertisingIdentifier: UUID = ASIdentifierManager().advertisingIdentifier
        return advertisingIdentifier.uuidString != Constants.ZERO_AD_ID ? advertisingIdentifier.uuidString : nil
    }
    
    /// Generate REST-ADS-API web request with current session data
    func sendAdRequest() {
        
        // Update locData with backup if nil
        if(TempoProfile.locData == nil) {
            TempoUtils.Say(msg: "🌏 Updating with backup")
            TempoProfile.locData = TempoDataBackup.getMostRecentLocationData()
        } else {
            TempoUtils.Say(msg: "🌏 LocData is not null, no backup needed")
        }
        
        // Create request
        let components = createUrlComponents()
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue(Constants.Web.APPLICATION_JSON, forHTTPHeaderField: Constants.Web.HEADER_CONTENT_TYPE)
        
        // Reformat the url string for easier readibility
        var urlStringOutput = components.url?.absoluteString ?? "❌ INVALID URL STRING?!"
        urlStringOutput = urlStringOutput.replacingOccurrences(of: "com/ad", with: "com/ad\n")
        TempoUtils.Say(msg: "🌏 REST-ADS-API: " + urlStringOutput)
        
        // Create request task and send
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            
            // Faluire reason to be updated if any errors encountered
            var errorMsg = "Unknown"
            
            // Fail if errors or not data
            if error != nil {
                errorMsg = "Invalid data error: \(error!.localizedDescription)"
            }
            else if data == nil {
                errorMsg = "Invalid data sent"
            }
            // Has data and no errors - can continue
            else {
                // Fail on invalid HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        self.sendAdFetchFailed(reason: "Invalid HTTP response")
                        self.adState = AdState.dormant
                    }
                    return
                }
                TempoUtils.Say(msg: "🤖🤖🤖 Response: \((response as! HTTPURLResponse).statusCode)")
                
                switch(httpResponse.statusCode) {
                case 200:
                    do {
                        let responseSuccess = try JSONDecoder().decode(ResponseSuccess.self, from: data!)
                        responseSuccess.outputValues()
                        
                        // Handle status type
                        switch(responseSuccess.status) {
                        case Constants.NO_FILL:
                            errorMsg = "200 - Failed loading ad: \(Constants.NO_FILL)"
                            self.addMetric(metricType: Constants.NO_FILL)
                        case Constants.OK:
                            // Loads ad from URL with id reference
                            DispatchQueue.main.async {
                                guard let campaignId = responseSuccess.id, !campaignId.isEmpty else {
                                    // Send failure trigger and reset state
                                    errorMsg = "200 - CampaignId was nil"
                                    self.adState = AdState.dormant
                                    self.sendAdFetchFailed(reason: errorMsg)
                                    return
                                }
                                
                                let url = URL(string: TempoUtils.getFullWebUrl(isInterstitial: self.isInterstitial, campaignId: campaignId, urlSuffix: responseSuccess.location_url_suffix))!
                                self.lastestURL = url.absoluteString
                                self.campaignId = TempoUtils.checkForTestCampaign(campaignId: campaignId)
                                self.webView.load(URLRequest(url: url))
                                self.adState = AdState.dormant
                            }
                            return
                        default:
                            errorMsg = "200 - Unexpected data returned"
                        }
                    } catch let decodingError {
                        errorMsg = "200 - Unexpected data returned, error decoding JSON: \(decodingError)"
                    }
                    break
                case 400:
                    do {
                        let responseBadRequest = try JSONDecoder().decode(ResponseBadRequest.self, from: data!)
                        responseBadRequest.outputValues()
                        errorMsg = "400 - Bad Request"
                    } catch let decodingError {
                        errorMsg = "400 - Bad Request, error decoding JSON: \(decodingError)"
                    }
                    break
                case 422:
                    do {
                        let responseUnprocessable = try JSONDecoder().decode(ResponseUnprocessable.self, from: data!)
                        responseUnprocessable.outputValues()
                        errorMsg = "422 - Unprocessable Request"
                    } catch let decodingError {
                        errorMsg = "422 - Unprocessable Request, error decoding JSON: \(decodingError)"
                    }
                    break
                default:
                    errorMsg = "Status code not relevant (\(httpResponse.statusCode) - ignoring"
                }
            }
            
            // Send failure trigger and reset state
            DispatchQueue.main.async {
                self.adState = AdState.dormant
                self.sendAdFetchFailed(reason: errorMsg)
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
            URLQueryItem(name: Constants.URL.LOCATION, value: countryCode),
            URLQueryItem(name: Constants.URL.IS_INTERSTITIAL, value: String(isInterstitial)),
            URLQueryItem(name: Constants.URL.SDK_VERSION, value: String(sdkVersion ?? "")),
            URLQueryItem(name: Constants.URL.ADAPTER_VERSION, value: String(adapterVersion ?? "")),
        ]
        
        // Only ad these value if they exists or cause invalid response
        if adapterType != nil {
            components.queryItems?.append(URLQueryItem(name: Constants.URL.ADAPTER_TYPE, value: adapterType))
        }
        if(TempoProfile.locData != nil && TempoProfile.locData?.consent != Constants.LocationConsent.NONE.rawValue) {
            if(TempoProfile.locData?.country_code != nil) {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_COUNTRY_CODE, value: TempoProfile.locData?.country_code))
            }
            if(TempoProfile.locData?.postal_code != nil) {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_POSTAL_CODE, value: TempoProfile.locData?.postal_code))
            }
            if(TempoProfile.locData?.admin_area != nil) {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_ADMIN_AREA, value: TempoProfile.locData?.admin_area))
            }
            if(TempoProfile.locData?.sub_admin_area != nil) {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_SUB_ADMIN_AREA, value: TempoProfile.locData?.sub_admin_area))
            }
            if(TempoProfile.locData?.locality != nil) {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_LOCALITY, value: TempoProfile.locData?.locality))
            }
            if(TempoProfile.locData?.sub_locality != nil) {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_SUB_LOCALITY, value: TempoProfile.locData?.sub_locality))
            }
        } else {
            TempoUtils.Warn(msg: "No LocationData was sent with Ads call")
        }
        
        // Clean any '+' references with safe '%2B'
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        
        return components
    }
    
    // Combines fetch fail callback and metric send
    func sendAdFetchFailed(reason: String?) {
        let endTag = reason?.isEmpty == true ? "" : ": \(reason!)"
        TempoUtils.Warn(msg: "AdFetchFailed:\(endTag)")
        self.addMetric(metricType: Constants.MetricType.LOAD_FAILED)
        self.listener.onTempoAdFetchFailed(isInterstitial: self.isInterstitial, reason: reason)
    }
    
    // Combines show fail callback and metric send
    func sendAdShowFailed(reason: String?) {
        let endTag = reason?.isEmpty == true ? "" : ": \(reason!)"
        TempoUtils.Warn(msg: "AdShowFailed:\(endTag)")
        self.addMetric(metricType: Constants.MetricType.SHOW_FAIL)
        self.listener.onTempoAdShowFailed(isInterstitial: self.isInterstitial, reason: reason)
    }
    
    /// Creates the custom WKWebView including safe areas, background color and pulls custom configurations
    private func setupWKWebview() -> Bool {
        
        // Create webview frame parameters
        var safeAreaTop: CGFloat = 0.0
        var safeAreaBottom: CGFloat = 0.0
        if #available(iOS 13.0, *) {
            safeAreaTop = getSafeAreaTop()
            safeAreaBottom = getSafeAreaBottom()
        }
        let webViewFrame = CGRect(
            x: 0,
            y: safeAreaTop,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height - safeAreaTop - safeAreaBottom
        )
        
        // Create webview config
        let configuration = getWKWebViewConfiguration()
        
        // Create WKWebView object
        webView = FullScreenWKWebView(frame: webViewFrame, configuration: configuration)
        if(webView == nil) {
            return false
        }
        webView.navigationDelegate = self
        
        // Add black base background
        webViewWithBackground = FullScreenUIView(frame: UIScreen.main.bounds)
        if(webViewWithBackground == nil) {
            return false
        }
        
        // Add main view to black background
        webViewWithBackground.backgroundColor = UIColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 1)
        webViewWithBackground.addSubview(webView)
        
        return true
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
                TempoUtils.Say(msg: "WEB: \(webMsg)", absoluteDisplay: true)
            }
            
            // Show success when content load
            if(webMsg == Constants.MetricType.IMAGES_LOADED) {
                listener.onTempoAdFetchSucceeded(isInterstitial: self.isInterstitial)
                self.addMetric(metricType: Constants.MetricType.LOAD_SUCCESS)
            }
        }
    }
    
    /// Creates and returns new LocationData from current static singleton that doesn't retain its memory references (clears all if NONE consent)
    public func getClonedAndCleanedLocation() -> LocationData {
        
        var newLocData = LocationData()
        let newConsent = TempoProfile.locData?.consent ?? Constants.LocationConsent.NONE.rawValue
        
        newLocData.consent = newConsent
        if(newConsent != Constants.LocationConsent.NONE.rawValue) {
            
            let state = TempoProfile.locData?.state
            let postcode = TempoProfile.locData?.postcode
            let countryCode = TempoProfile.locData?.country_code
            let postalCode = TempoProfile.locData?.postal_code
            let adminArea = TempoProfile.locData?.admin_area
            let subAdminArea = TempoProfile.locData?.sub_admin_area
            let locality = TempoProfile.locData?.locality
            let subLocality = TempoProfile.locData?.sub_locality
            
            newLocData.state = state
            newLocData.postcode = postcode
            newLocData.country_code = countryCode
            newLocData.postal_code = postalCode
            newLocData.admin_area = adminArea
            newLocData.sub_admin_area = subAdminArea
            newLocData.locality = locality
            newLocData.sub_locality = subLocality
        }
        
        return newLocData
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
                            location: self.countryCode ?? "",
                            country_code: self.countryCode ?? "",
                            placement_id: self.placementId ?? "",
                            os: "iOS \(UIDevice.current.systemVersion)",
                            sdk_version: self.sdkVersion ?? "",
                            adapter_version: self.adapterVersion ?? "",
                            cpm: self.cpmFloor ?? 0.0,
                            adapter_type: self.adapterType,
                            consent: self.consent,
                            consent_type: nil,
                            location_data: getClonedAndCleanedLocation()
        )
        
        self.metricList.append(metric)
        
        // State invalid if UNCHECKED/CHECKING (Waiting for results before we decide to send or not)
        let validState = TempoProfile.locationState != .UNCHECKED && TempoProfile.locationState != .CHECKING
        
        // Hold if still waiting for profile LocationData (or if consent != NONE)
        if(!validState && metric.location_data?.consent != Constants.LocationConsent.NONE.rawValue) {
            TempoUtils.Warn(msg: "[\(metricType)::\(TempoProfile.locationState ?? LocationState.UNCHECKED)] " +
                            "Not sending metrics just yet: [admin=\(metric.location_data?.admin_area ?? "nil") | locality=\(metric.location_data?.locality ?? "nil")]")
            return
        } else {
            TempoUtils.Say(msg: "[\(metricType)::\(TempoProfile.locationState ?? LocationState.UNCHECKED)] " +
                           "Sending metrics! [admin=\(metric.location_data?.admin_area ?? "nil") | locality=\(metric.location_data?.locality ?? "nil")]")
        }
        
        if (Constants.MetricType.METRIC_SEND_NOW.contains(metricType)) {
            Metrics.pushMetrics(currentMetrics: &metricList, backupUrl: nil)
        }
    }
    
    /// Cycles through all unpushed metrics and updates all LocationData values based on consent value at time of creation
    func pushHeldMetricsWithUpdatedLocationData() {
        
        if(!metricList.isEmpty) {
            for (index, _) in metricList.enumerated() {
                
                let preAdmin = metricList[index].location_data?.admin_area
                let preLocality = metricList[index].location_data?.locality
                
                if(metricList[index].location_data?.consent == Constants.LocationConsent.NONE.rawValue) {
                    
                    // Delete any data related to personal location
                    metricList[index].location_data?.postcode = nil
                    metricList[index].location_data?.state = nil
                    metricList[index].location_data?.postal_code = nil
                    metricList[index].location_data?.country_code = nil
                    metricList[index].location_data?.admin_area = nil
                    metricList[index].location_data?.sub_admin_area = nil
                    metricList[index].location_data?.locality = nil
                    metricList[index].location_data?.sub_locality = nil
                    
                    TempoUtils.Say(msg: "🧹 NONE => \(metricList[index].metric_type ?? "TYPE?"): admin=[\(preAdmin ?? "nil"):nil)], locality=[\(preLocality ?? "nil"):nil]")
                } else {
                    // Confirm postcode has a value
                    if let currentPostcode = TempoProfile.locData?.postcode, !currentPostcode.isEmpty {
                        metricList[index].location_data?.postcode = currentPostcode
                    } else {
                        metricList[index].location_data?.postcode = nil
                    }
                    
                    // Confirm state has a value
                    if let currentState = TempoProfile.locData?.state, !currentState.isEmpty {
                        metricList[index].location_data?.state = currentState
                    } else {
                        metricList[index].location_data?.state = nil
                    }
                    
                    // Confirm postal code has a value
                    if let currentPostalCode = TempoProfile.locData?.postal_code, !currentPostalCode.isEmpty {
                        metricList[index].location_data?.postal_code = currentPostalCode
                    } else {
                        metricList[index].location_data?.postal_code = nil
                    }
                    
                    // Confirm country code has a value
                    if let currentCountryCode = TempoProfile.locData?.country_code, !currentCountryCode.isEmpty {
                        metricList[index].location_data?.country_code = currentCountryCode
                        metricList[index].country_code = currentCountryCode
                        metricList[index].location = currentCountryCode
                    } else {
                        metricList[index].location_data?.country_code = nil
                    }
                    
                    // Confirm admin area has a value
                    if let currentAdminArea = TempoProfile.locData?.admin_area, !currentAdminArea.isEmpty {
                        metricList[index].location_data?.admin_area = currentAdminArea
                    } else {
                        metricList[index].location_data?.admin_area = nil
                    }
                    
                    // Confirm sub-admin area has a value
                    if let currentSubAdminArea = TempoProfile.locData?.sub_admin_area, !currentSubAdminArea.isEmpty {
                        metricList[index].location_data?.sub_admin_area = currentSubAdminArea
                    } else {
                        metricList[index].location_data?.sub_admin_area = nil
                    }
                    
                    // Confirm locality has a value
                    if let currentLocality = TempoProfile.locData?.locality, !currentLocality.isEmpty {
                        metricList[index].location_data?.locality = currentLocality
                    } else {
                        metricList[index].location_data?.locality = nil
                    }
                    
                    // Confirm locality has a value
                    if let currentSubLocality = TempoProfile.locData?.sub_locality, !currentSubLocality.isEmpty {
                        metricList[index].location_data?.sub_locality = currentSubLocality
                    } else {
                        metricList[index].location_data?.sub_locality = nil
                    }
                    
                    TempoUtils.Say(msg: "🧹\(metricList[index].location_data?.consent ?? "NOT_NONE") => \(metricList[index].metric_type ?? "TYPE?"): admin=[\(preAdmin ?? "nil"):\(metricList[index].location_data?.postcode ?? "nil")], locality=[\(preLocality ?? "nil"):\(metricList[index].location_data?.state ?? "nil")]")
                }
            }
            
            Metrics.pushMetrics(currentMetrics: &metricList, backupUrl: nil)
        } else {
            TempoUtils.Say(msg:"🧹 No metrics to push (EMPTY)")
        }
    }
    
    /// Calculate gap at top needed based on device ttype
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
    
    /// Calculate gap at bottom needed based on device ttype
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
    
    /// Shuts down Tempo ads as a type of nuclear option
    func abortTempo() {
        TempoUtils.Warn(msg: "Abrupt Tempo shutdown (state=\(adState!))")
        
        // Invoke failure callbacks
        if(adState == AdState.loading)
        {
            self.sendAdFetchFailed(reason: "WKWebView navigation failure")
        }
        else if(adState == AdState.showing)
        {
            self.sendAdShowFailed(reason: "WKWebView navigation failure")

            // Close the iOS WebView - this should return to original view this was called against
            closeAd()
        }
    }
    
    /// WebView fail delegate (ProvisionalNavigation)
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        //TempoUtils.Shout(msg: "❌ didFailProvisionalNavigation FAILURE")
        abortTempo()
    }
    
    /// WebView fail delegate (General fail)
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        //TempoUtils.Shout(msg: "❌ didFail FAILURE")
        abortTempo()
    }
    
    /// WebView success delegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //TempoUtils.Say(msg: "✅ didFinish SUCCESS")
    }
    
    
    /// Test function used to test specific campaign ID using dummy values fo other metrics
    public func loadSpecificCampaignAd(isInterstitial: Bool, campaignId:String) {
        adState = AdState.loading
        TempoUtils.Say(msg: "load specific url \(isInterstitial ? "INTERSTITIAL": "REWARDED")")
        if(!self.setupWKWebview()) {
            sendAdFetchFailed(reason: "Could not create WKWebView")
        }
        uuid = "TEST"
        adId = "TEST"
        appId = "TEST"
        self.isInterstitial = isInterstitial
        //let urlComponent = isInterstitial ? TempoConstants.URL_INT : TempoConstants.URL_REW
        self.addMetric(metricType: "CUSTOM_AD_LOAD_REQUEST")
        //let url = URL(string: "https://ads.tempoplatform.com/\(urlComponent)/\(campaignId)/ios")!
        let url = URL(string: TempoUtils.getFullWebUrl(isInterstitial: isInterstitial, campaignId: campaignId, urlSuffix: nil))!
        //self.campaignId = campaignId
        self.campaignId = TempoUtils.checkForTestCampaign(campaignId: campaignId)
        self.webView.load(URLRequest(url: url))
    }
}


class FullScreenWKWebView: WKWebView {
    
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0)
    }
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        self.allowsBackForwardNavigationGestures = true
        self.scrollView.isScrollEnabled = false
        self.scrollView.bounces = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FullScreenUIView: UIView {
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
