import Foundation
import UIKit
import WebKit
import AdSupport

public class TempoAdView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler  {
    var listener: TempoAdListener!
    var parentVC: UIViewController?
    var webViewBackground: FullScreenBackgroundWebView!
    var webViewAd: FullScreenAdWebView!
    
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
    internal var countryCode: String?
    var locationData: LocationData?
    var metricList: [Metric] = []
    var lastestURL: String? = nil
    
    public init(listener: TempoAdListener, appId: String) {
        super.init(nibName: nil, bundle: nil)
        
        self.listener = listener
        self.appId = appId
        
        // Confirm a valid country code - catch result is a nil countryCode, which should be ok // TODO: Check this
        do {
            countryCode = try CountryCode.getIsoCountryCode2Digit()
            TempoUtils.Say(msg: "ISO Country Code: \(countryCode!)")
        } catch {
            TempoUtils.Warn(msg: "Setting countryCode as hard nil")
            countryCode = nil
        }
        
        sdkVersion = Constants.SDK_VERSIONS
        adapterVersion = self.listener.getTempoAdapterVersion()
        adapterType = self.listener.getTempoAdapterType()
        consent = self.listener.hasUserConsent()
        
        // Check if Ad ID is activated and available
        do {
            try updateAdId()
        } catch {
            adId = Constants.ZERO_AD_ID
            TempoUtils.Warn(msg: "Ad ID could not be retireved: \(error.localizedDescription)")
        }
        TempoUtils.Say(msg: "Ad ID: \(adId!)")
    }
    
    /// Ignore requirement to implement required initializer ‘init(coder:) in it.
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
        do {
            try setupWKWebview()
        } catch let error {
            // Fails if cannot get WkWebView
            self.adState = AdState.dormant
            DispatchQueue.main.async {
                self.processAdFetchFailed(reason: "Could not create WKWebView: \(error.localizedDescription)")
            }
            return
        }
        
        // Update session values from paramters
        self.isInterstitial = isInterstitial
        self.placementId = placementId
        self.cpmFloor = cpmFloor ?? 0.0
        
        // Update session values from global checks
        uuid = UUID().uuidString
        
        // Create ad load metrics with updated ad data
        self.addMetric(metricType: Constants.MetricType.LOAD_REQUEST)
        
        // Create and send ad request with latest data
        do {
            try sendAdRequest()
        }
        catch {
            // Send failure trigger and reset state
            self.adState = AdState.dormant
            DispatchQueue.main.async {
                self.processAdFetchFailed(reason: "Failed sending ad fetch request")
            }
        }
    }
    
    /// Plays currently loaded ad for current session (interstitial/reward)
    public func showAd(parentVC: UIViewController?) {
        
        // Checks connection first, then runs handleWebsiteCheck()/showOnceConnectionConfirmed() upon successful completion
        checkWebsiteConnectivity(urlString: lastestURL ?? "", parentViewController: parentVC, completion: handleWebsiteCheck)
    }
    
    /// Checks target content URL prior to displaying, aborting if fails
    func checkWebsiteConnectivity(urlString: String, parentViewController: UIViewController?, completion: @escaping (Bool, UIViewController?, String?) -> Void) {
        
        // Validate URL string
        guard let url = URL(string: urlString) else {
            completion(false, parentViewController, "Invalid URL string")
            return
        }
        
        // Validate parent ViewController
        guard let parentViewController = parentViewController else {
            completion(false, nil, "Invalid parent ViewController")
            return
        }
        
        // Created HEAD method request with timeout
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        // Check response and pass on parent ViewController
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            
            // Ensure completion handler is called on the main thread
            DispatchQueue.main.async {
            
                // Handle any request errors
                if let error = error as NSError? {
                    if error.code == NSURLErrorTimedOut {
                        completion(false, parentViewController, "Request timed out")
                    } else {
                        completion(false, parentViewController, "URL response error: \(error.localizedDescription)")
                    }
                    return
                }
                
                // Handle request response
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, parentViewController, "URL request success")
                    } else {
                        completion(false, parentViewController, "HTTP error with status code \(httpResponse.statusCode)")
                    }
                }
            }
        }
        
        // Tasks begin in a suspended state, need to 'resume' to start the task.
        task.resume()
    }
    
    /// Checks result of connection check request, displays ad if confirmed and handles any other failures
    func handleWebsiteCheck(success: Bool, parentVC: UIViewController?, failReason: String? ) {
        if(success) {
            // Validate parent ViewController
            guard let parentVC = parentVC else {
                processAdShowFailed(reason: "Invalid parent ViewController")
                return
            }
            
            // Display confirmed active URL
            self.showOnceConnectionConfirmed(parentVC: parentVC)
        } else {
            let reason = failReason?.isEmpty ?? true ? "UNKNOWN" : failReason!
            processAdShowFailed(reason: reason)
        }
    }
    
    /// Adds conetnt webview to parent ViewController and displays ad
    private func showOnceConnectionConfirmed(parentVC: UIViewController?) {
        
        // Update parent VC with received value
        self.parentVC = parentVC
        
        // Make sure parentVC/webview are not nil
        guard self.parentVC != nil, self.webViewAd != nil, self.webViewBackground != nil else {
            self.processAdShowFailed(reason: "Unexpected null object")
            self.closeAd()
            return
        }
        
        // Update adState
        adState = AdState.showing
        
        // Add content view
        self.parentVC!.view.addSubview(self.webViewBackground)
        
        // Send SHOW metric and call activate DISPLAYED listener
        addMetric(metricType: Constants.MetricType.SHOW)
        listener.onTempoAdDisplayed(isInterstitial: self.isInterstitial)
        
        // Create JS statement to find video element and play.
        let script = Constants.JS.JS_FORCE_PLAY
        self.webViewAd.evaluateJavaScript(script) { (result, error) in
            
            if let error = error {
                TempoUtils.Say(msg: "Error playing video: \(error)")
                // TODO: METRIC if this occurs? Close?
            }
            
            // Note: Method return type not recognised by WKWebKit so we add null return.
            if let result = result {
                TempoUtils.Say(msg: "Playing video result: \(result)")
                // Placer if required, should be nil
            }
        }
    }
    
    /// Closes current WkWebView
    public func closeAd() {
        
        // Reset values
        cleanUpWebViews();
        
        // Send metrics regardless - check if needs to be retroactively updated to reflect new location data
        if(TempoProfile.locationState == .UNCHECKED || TempoProfile.locationState == .CHECKING) {
            pushHeldMetricsWithUpdatedLocationData()
            TempoProfile.locationState = .FAILED
        } else {
            // Push metrics with error handling
            do {
                try Metrics.pushMetrics(currentMetrics: &metricList, backupUrl: nil)
                TempoUtils.Say(msg: "Metrics pushed successfully.")
            } catch {
                TempoUtils.Warn(msg: "Error pushing metrics on close: \(error)")
            }
        }
        
        // Invoke close callback
        listener?.onTempoAdClosed(isInterstitial: self.isInterstitial)
    }
    
    /// Resets any potential hanging values when ad is closed
    func cleanUpWebViews() {
        // Safely update adState
        self.adState = AdState.dormant
        
        // Ensure this code runs on the main thread
        DispatchQueue.main.async {
            
            // Safely remove web views from their superviews
            self.webViewBackground?.removeFromSuperview()
            self.webViewAd?.removeFromSuperview()
            
            // Set web views to nil to release memory
            self.webViewAd = nil
            self.webViewBackground = nil
        }
    }
    
    /// Checks is consented Ad ID exists and returns (nullable) value
    func updateAdId() throws {
        
        // Check if advertising tracking is enabled
        guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
            TempoUtils.Warn(msg: "Error: IDFA not available. Ensure that advertising tracking is enabled.")
            throw ProfileError.idfaNotAvailable
        }
        
        // Get Advertising ID (IDFA) // TODO: add proper IDFA alternative here if we don't have Ad ID
        let advertisingIdentifier: UUID = ASIdentifierManager().advertisingIdentifier
        adId = advertisingIdentifier.uuidString
        
        // Validate the IDFA
        if adId == nil || adId!.isEmpty {
            TempoUtils.Warn(msg: "Invalid Ad ID received.")
            throw ProfileError.invalidAdId
        }
    }
    
    /// Generate REST-ADS-API web request with current session data
    func sendAdRequest() throws {
        
        // Update locData with backup if nil
        if(TempoProfile.locData == nil) {
            TempoUtils.Say(msg: "🌏 Updating with backup")
            do{
                TempoProfile.locData = try TempoDataBackup.getMostRecentLocationData()
            } catch {
                TempoUtils.Warn(msg: "LocData error during ad request")
                TempoProfile.locData = LocationData()
            }
        } else {
            TempoUtils.Say(msg: "🌏 LocData is not null, no backup needed")
        }
        
        // Create request
        let components: URLComponents
        do{
            components = try createUrlComponents()
        } catch {
            throw AdRequestError.urlCreationFailed
        }
        
        guard let url = components.url else {
            TempoUtils.Warn(msg: "URL component's URL property invalid")
            throw AdRequestError.urlCreationFailed
        }
        
        // Request with validated URL
        var request = URLRequest(url: url)
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
            if let error = error {
                errorMsg = "Invalid data error: \(error.localizedDescription)"
            }
            else if data == nil {
                errorMsg = "Invalid data sent"
            }
            // Has data and no errors - can continue
            else {
                // Fail on invalid HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.adState = AdState.dormant
                    DispatchQueue.main.async { self.processAdFetchFailed(reason: "Invalid HTTP response") }
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
                            guard let campaignId = responseSuccess.id, !campaignId.isEmpty else {
                                // Send failure trigger and reset state
                                errorMsg = "Campaign ID invalid"
                                self.adState = AdState.dormant
                                self.processAdFetchFailed(reason: errorMsg)
                                return
                            }
                            do {
                                let url = URL(string: try TempoUtils.getFullWebUrl(isInterstitial: self.isInterstitial, campaignId: campaignId, urlSuffix: responseSuccess.location_url_suffix))!
                                
                                self.lastestURL = url.absoluteString
                                self.campaignId = try TempoUtils.checkForTestCampaign(campaignId: campaignId)
                                self.adState = AdState.dormant
                                TempoUtils.Say(msg: "🧨 URL: \(self.lastestURL!)")
                                DispatchQueue.main.async {
                                    self.webViewAd.load(URLRequest(url: url))
                                }
                                
                                return
                            }
                            catch WebURLError.invalidCampaignId {
                                errorMsg = "200 - Custom campaign ID invalid"
                            }
                            catch WebURLError.invalidCustomCampaignID {
                                errorMsg = "200 - Campaign ID invalid"
                            }
                            catch {
                                errorMsg = "200 - Unknown error while loading ad"
                            }
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
            self.adState = AdState.dormant
            DispatchQueue.main.async {
                self.processAdFetchFailed(reason: errorMsg)
            }
        })
        
        task.resume()
    }
    
    /// Create URL components with current ad data for REST-ADS-API web request
    func createUrlComponents() throws -> URLComponents {
        
        // Get URL domain/path
        guard let url = URL(string: TempoUtils.getAdsApiUrl()) else {
            TempoUtils.Warn(msg: "Failed to create URL component")
            throw AdProcessError.invalidUrl
        }
        
        // Parse URL as-is
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
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
        
        // Add adapterType if it exists
        if let adapterType = adapterType {
            components.queryItems?.append(URLQueryItem(name: Constants.URL.ADAPTER_TYPE, value: adapterType))
        }

        // Add locData parameters if locData exists and consent is not NONE
        if let locData = TempoProfile.locData, locData.consent != Constants.LocationConsent.NONE.rawValue {
            if let countryCode = locData.country_code {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_COUNTRY_CODE, value: countryCode))
            }
            if let postalCode = locData.postal_code {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_POSTAL_CODE, value: postalCode))
            }
            if let adminArea = locData.admin_area {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_ADMIN_AREA, value: adminArea))
            }
            if let subAdminArea = locData.sub_admin_area {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_SUB_ADMIN_AREA, value: subAdminArea))
            }
            if let locality = locData.locality {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_LOCALITY, value: locality))
            }
            if let subLocality = locData.sub_locality {
                components.queryItems?.append(URLQueryItem(name: Constants.URL.LOC_SUB_LOCALITY, value: subLocality))
            }
        } else {
            TempoUtils.Warn(msg: "No LocationData was sent with Ads call")
        }
        
        // Clean any '+' references with safe '%2B'
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        
        return components
    }
    
    // Combines fetch fail callback and metric send
    func processAdFetchFailed(reason: String?) {
        TempoUtils.Warn(msg: "AdFetchFailed: \(reason ?? "UNKNOWN")")
        self.addMetric(metricType: Constants.MetricType.LOAD_FAILED)
        self.listener.onTempoAdFetchFailed(isInterstitial: self.isInterstitial, reason: reason)
    }
    
    // Combines show fail callback and metric send
    func processAdShowFailed(reason: String?) {
        TempoUtils.Warn(msg: "AdFetchFailed: \(reason ?? "UNKNOWN")")
        self.addMetric(metricType: Constants.MetricType.SHOW_FAIL)
        self.listener.onTempoAdShowFailed(isInterstitial: self.isInterstitial, reason: reason)
    }
    
    /// Creates the custom WKWebView including safe areas, background color and pulls custom configurations
    private func setupWKWebview() throws {
        
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
        webViewAd = FullScreenAdWebView(frame: webViewFrame, configuration: configuration)
        if(webViewAd == nil){ throw WebViewError.webViewCreationFailed }
        webViewAd.navigationDelegate = self
        
        // Add black base background, and add main view to background
        webViewBackground = FullScreenBackgroundWebView(frame: UIScreen.main.bounds)
        if(webViewBackground == nil) { throw WebViewError.backgroundViewCreationFailed }
        webViewBackground.backgroundColor = UIColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 1)
        webViewBackground.addSubview(webViewAd)
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
        
        // List of single-word keys as function references
        let actionList: [String] = [ Constants.MetricType.CLOSE_AD, Constants.MetricType.IMAGES_LOADED ]
        
        // Ensure message body is a string
        guard let bodyString = message.body as? String else {
            TempoUtils.Warn(msg: "Invalid message format received: \(message.body)")
            return
        }
        TempoUtils.Say(msg: "WEB_MSG: \(bodyString)", absoluteDisplay: true)
        
        // Check if known one-word reference
        if actionList.contains(bodyString) {
            // Send metric for web message
            self.addMetric(metricType: bodyString)
            
            // Handle actionable commands
            var jsMsg = "👀: "
            switch bodyString {
            case Constants.MetricType.CLOSE_AD:
                jsMsg.append("CLOSE_AD")
                self.closeAd()
            case Constants.MetricType.IMAGES_LOADED:
                jsMsg.append("IMAGES_LOADED")
                listener.onTempoAdFetchSucceeded(isInterstitial: self.isInterstitial)
                self.addMetric(metricType: Constants.MetricType.LOAD_SUCCESS)
            default:
                jsMsg.append("⚠️ \(bodyString) (unexpected)")
            }
            TempoUtils.Say(msg: jsMsg)
        }
        // Check if JSON format first
        else if (TempoUtils.isPossiblyJSONObject(msg: bodyString)) {
            if let jsonData = bodyString.data(using: .utf8) {
                do {
                    // Parse expected JSON data
                    let redirect = try JSONDecoder().decode(Constants.Function_RedirectToUrl.self, from: jsonData)
//                    TempoUtils.Say(msg: "Message Type: \(redirect.msgType)")
//                    TempoUtils.Say(msg: "URL: \(redirect.url)")
                    
                    if redirect.msgType == Constants.MetricType.OPEN_URL_IN_EXTERNAL_BROWSER {
                        TempoUtils.openUrlInBrowser(url: redirect.url)
                    }
                } catch {
                    TempoUtils.Warn(msg: "❌ Failed to decode JSON: \(error)")
                }
            } else {
                TempoUtils.Warn(msg: "❌ Failed to create JSON data from string: \(bodyString)")
            }
        }
        else {
            TempoUtils.Say(msg: "🆗 \(bodyString)")
        }
    }
    
    /// Creates and returns new LocationData from current static singleton that doesn't retain its memory references (clears all if NONE consent)
    public func getClonedAndCleanedLocation() -> LocationData {
        
        var newLocData = LocationData()
        let newConsent = TempoProfile.locData?.consent ?? Constants.LocationConsent.NONE.rawValue
        
        newLocData.consent = newConsent
        if(newConsent != Constants.LocationConsent.NONE.rawValue) {
            if let state = TempoProfile.locData?.state { newLocData.state = state }
            if let postcode = TempoProfile.locData?.postcode { newLocData.postcode = postcode }
            if let countryCode = TempoProfile.locData?.country_code { newLocData.country_code = countryCode }
            if let postalCode = TempoProfile.locData?.postal_code { newLocData.postal_code = postalCode }
            if let adminArea = TempoProfile.locData?.admin_area { newLocData.admin_area = adminArea }
            if let subAdminArea = TempoProfile.locData?.sub_admin_area { newLocData.sub_admin_area = subAdminArea }
            if let locality = TempoProfile.locData?.locality { newLocData.locality = locality }
            if let subLocality = TempoProfile.locData?.sub_locality { newLocData.sub_locality = subLocality }
        }
        
        return newLocData
    }
    
    /// Create a new Metric instance based on current ad's class properties, and adds to Metrics array
    private func addMetric(metricType: String) {
        
        do {
            let metric = try createMetric(metricType: metricType)
            metricList.append(metric)
            
            // State invalid if UNCHECKED/CHECKING (Waiting for results before we decide to send or not)
            let validState = TempoProfile.locationState != .UNCHECKED && TempoProfile.locationState != .CHECKING
            
            // Hold if still waiting for profile LocationData (or if consent != NONE)
            guard validState || metric.location_data?.consent == Constants.LocationConsent.NONE.rawValue else {
                TempoUtils.Warn(msg: "[\(metricType)::\(TempoProfile.locationState ?? LocationState.UNCHECKED)] " +
                                "Not sending metrics just yet: [state/admin=\(metric.location_data?.admin_area ?? "nil")]")
                return
            }
            
            TempoUtils.Say(msg: "[\(metricType)::\(TempoProfile.locationState ?? LocationState.UNCHECKED)] " +
                           "Sending metrics! [state/admin=\(metric.location_data?.admin_area ?? "nil")]")
            
            if Constants.MetricType.METRIC_SEND_NOW.contains(metricType) {
                try pushMetrics()
            }
        } catch {
            handleMetricError(error)
        }
    }
    
    /// Push metrics with error handling
    private func pushMetrics() throws {
        try Metrics.pushMetrics(currentMetrics: &metricList, backupUrl: nil)
        TempoUtils.Say(msg: "Metrics pushed successfully.")
    }
    
    /// Handle metric-related errors
    private func handleMetricError(_ error: Error) {
        switch error {
        case MetricsError.invalidURL:
            TempoUtils.Warn(msg: "Error: Invalid URL for metrics")
        case MetricsError.jsonEncodingFailed:
            TempoUtils.Warn(msg: "Error: Failed to encode metrics data")
        case MetricsError.emptyMetrics:
            TempoUtils.Warn(msg: "Error: No metrics to push")
        case MetricsError.missingJsonString:
            TempoUtils.Warn(msg: "Error: Missing JSON string")
        case MetricsError.invalidHeaderValue:
            TempoUtils.Warn(msg: "Error: Invalid header value")
        default:
            TempoUtils.Warn(msg: "An unknown error occurred: \(error)")
        }
    }
    
    /// Create a Metric instance based on current ad's class properties
    private func createMetric(metricType: String) throws -> Metric {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            throw MetricsError.invalidHeaderValue
        }
        
        return Metric(
            metric_type: metricType,
            ad_id: adId,
            app_id: appId,
            timestamp: Int(Date().timeIntervalSince1970 * 1000),
            is_interstitial: isInterstitial,
            bundle_id: bundleId,
            campaign_id: campaignId ?? "",
            session_id: uuid ?? "",
            location: countryCode ?? "",
            country_code: countryCode ?? "",
            placement_id: placementId ?? "",
            os: "iOS \(UIDevice.current.systemVersion)",
            sdk_version: sdkVersion ?? "",
            adapter_version: adapterVersion ?? "",
            cpm: cpmFloor ?? 0.0,
            adapter_type: adapterType,
            consent: consent,
            consent_type: nil,
            location_data: getClonedAndCleanedLocation()
        )
    }
    
    /// Cycles through all unpushed metrics and updates all LocationData values based on consent value at time of creation
    func pushHeldMetricsWithUpdatedLocationData() {
        
        guard !metricList.isEmpty else {
            TempoUtils.Say(msg:"🧹 No metrics to push (EMPTY)")
            return
        }
        
        // Update location/consent details for eacb Metric if needed
        for (index, var metric) in metricList.enumerated() {
            let preAdmin = metric.location_data?.admin_area
            let preLocality = metric.location_data?.locality
            
            if metric.location_data?.consent == Constants.LocationConsent.NONE.rawValue {
                clearSensitiveLocationData(&metric, preAdmin: preAdmin, preLocality: preLocality)
            } else {
                updateLocationDataFromTempoProfile(&metric)
            }
            
            TempoUtils.Say(msg: "🧹\(metric.location_data?.consent ?? "NOT_NONE") => \(metric.metric_type ?? "TYPE?"): admin=[\(preAdmin ?? "nil"):\(metric.location_data?.postcode ?? "nil")], locality=[\(preLocality ?? "nil"):\(metric.location_data?.state ?? "nil")]")
            
            metricList[index] = metric
        }
        
        do {
            try pushMetrics()
        } catch {
            handleMetricError(error)
        }
    }
    
    /// Clears sensitive location data if consent is NONE
    private func clearSensitiveLocationData(_ metric: inout Metric, preAdmin: String?, preLocality: String?) {
        // Delete any data related to personal location
        metric.location_data?.postcode = nil
        metric.location_data?.state = nil
        metric.location_data?.postal_code = nil
        metric.location_data?.country_code = nil
        metric.location_data?.admin_area = nil
        metric.location_data?.sub_admin_area = nil
        metric.location_data?.locality = nil
        metric.location_data?.sub_locality = nil
        
        TempoUtils.Say(msg: "🧹 NONE => \(metric.metric_type ?? "TYPE?"): admin=[\(preAdmin ?? "nil"):nil)], locality=[\(preLocality ?? "nil"):nil]")
    }

    /// Updates location data from TempoProfile
    private func updateLocationDataFromTempoProfile(_ metric: inout Metric) {
        metric.location_data?.postcode = TempoProfile.locData?.postcode ?? nil
        metric.location_data?.state = TempoProfile.locData?.state ?? nil
        metric.location_data?.postal_code = TempoProfile.locData?.postal_code ?? nil
        metric.location_data?.country_code = TempoProfile.locData?.country_code ?? nil
        metric.location_data?.admin_area = TempoProfile.locData?.admin_area ?? nil
        metric.location_data?.sub_admin_area = TempoProfile.locData?.sub_admin_area ?? nil
        metric.location_data?.locality = TempoProfile.locData?.locality ?? nil
        metric.location_data?.sub_locality = TempoProfile.locData?.sub_locality ?? nil
        
//        // Original implementation example...
//        // Confirm postcode has a value
//        if let currentPostcode = TempoProfile.locData?.postcode, !currentPostcode.isEmpty {
//            metricList[index].location_data?.postcode = currentPostcode
//        } else {
//            metricList[index].location_data?.postcode = nil
//        }
    }
    
    /// Calculate gap at top needed based on device ttype
    @available(iOS 13.0, *)
    func getSafeAreaTop() -> CGFloat {
        guard let keyWindow = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .map({ $0 as? UIWindowScene })
            .compactMap({ $0 })
            .first?.windows
            .first(where: { $0.isKeyWindow })
        else {
            return 0
        }
        
        return keyWindow.safeAreaInsets.top
    }
    
    /// Calculate gap at bottom needed based on device ttype
    @available(iOS 13.0, *)
    func getSafeAreaBottom() -> CGFloat {
        guard let keyWindow = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .map({ $0 as? UIWindowScene })
            .compactMap({ $0 })
            .first?.windows
            .first(where: { $0.isKeyWindow })
        else {
            return 0
        }
        
        return keyWindow.safeAreaInsets.bottom
    }
    
    /// Shuts down Tempo ads as a type of nuclear option
    func abortTempo() {
        // If no ad state, abort now
        guard let adState = adState else {
            TempoUtils.Warn(msg: "Abrupt Tempo shutdown: adState is nil")
            self.processAdFetchFailed(reason: "WKWebView navigation failure (adState=nil)")
            return
        }
        
        // Invoke failure callbacks
        switch adState {
        case AdState.loading:
            processAdFetchFailed(reason: "WKWebView navigation failure during loading")
        case AdState.showing:
            processAdShowFailed(reason: "WKWebView navigation failure during showing")
            // Close the iOS WebView - this should return to original view this was called against
            closeAd()
        default:
            TempoUtils.Warn(msg: "Unhandled adState: \(adState)")
        }
    }
    
    /// WebView fail delegate (ProvisionalNavigation)
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        //TempoUtils.Warn(msg: "❌ didFailProvisionalNavigation FAILURE: \(error.localizedDescription)")
        abortTempo()
    }
    
    /// WebView fail delegate (General fail)
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        //TempoUtils.Shout(msg: "❌ didFail FAILURE: \(error.localizedDescription)")
        abortTempo()
    }
    
    /// WebView success delegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //TempoUtils.Say(msg: "✅ didFinish SUCCESS")
    }
    
    /// Test function used to test specific campaign ID using dummy values fo other metrics
    public func loadSpecificCampaignAd(isInterstitial: Bool, campaignId:String) {
        TempoUtils.Say(msg: "load specific url \(isInterstitial ? "INTERSTITIAL": "REWARDED")")
        
        // Update state to LOADING
        adState = AdState.loading
        
        // Create WKWebView instance
        do {
            try setupWKWebview()
        } catch let error {
            // Fails if cannot get WkWebView
            self.adState = AdState.dormant
            DispatchQueue.main.async {
                self.processAdFetchFailed(reason: "Could not create WKWebView for specific campaign: \(error.localizedDescription)")
            }
            return
        }
        
        uuid = "TEST"
        adId = "TEST"
        appId = "TEST"
        self.isInterstitial = isInterstitial
        
        // Add metric for ad load request
        self.addMetric(metricType: "CUSTOM_AD_LOAD_REQUEST")
        
        var errorMsg: String = "Unknown"
        do {
            // Generate URL based on interstitial type and campaign ID
            guard let url = URL(string: try TempoUtils.getFullWebUrl(isInterstitial: isInterstitial, campaignId: campaignId, urlSuffix: nil)) else {
                
                TempoUtils.Shout(msg: "---- 0 (fail) ----")
                adState = .dormant
                DispatchQueue.main.async {
                    self.processAdFetchFailed(reason: "Invalid URL for campaign \(campaignId)")
                }
                return
            }
            
            // Check for test campaign and set campaign ID accordingly
            self.campaignId = try TempoUtils.checkForTestCampaign(campaignId: campaignId)
            
            // Load the ad in the web view
            webViewAd.load(URLRequest(url: url))
            
            TempoUtils.Shout(msg: "---- 1 (suc) ----")
            return
            
        } catch WebURLError.invalidCampaignId {  errorMsg = "200 - Custom campaign ID invalid"
        } catch WebURLError.invalidCustomCampaignID {   errorMsg = "200 - Campaign ID invalid"
        } catch { errorMsg = "200 - Unknown error while loading ad"
        }
        
        TempoUtils.Shout(msg: "---- 2 (err) ----")
        
        // If ends here, we have failed so exit
        adState = .dormant
        DispatchQueue.main.async {
            self.processAdFetchFailed(reason: errorMsg)
        }
    }
}


class FullScreenAdWebView: WKWebView {
    
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0)
    }
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)

        // Additional configurations
        self.allowsBackForwardNavigationGestures = true
        self.scrollView.isScrollEnabled = false
        self.scrollView.bounces = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FullScreenBackgroundWebView: UIView {
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
