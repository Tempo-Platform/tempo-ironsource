public protocol TempoAdListener {
    // Called when the interstitial content is finished loading.
    func onAdFetchSucceeded(isInterstitial: Bool)
    
    // Called when an error occurs loading the interstitial content.
    func onAdFetchFailed(isInterstitial: Bool)
    
    // Called when the interstitial has closed and disposed of its views.
    func onAdClosed(isInterstitial: Bool)
    
    // Called when an ad goes full screen.
    func onAdDisplayed(isInterstitial: Bool)
    
    // Called when an ad is clicked.
    func onAdClicked(isInterstitial: Bool)  // TODO: actually monitor clicks and call this callback
    
    // Called when swapping version information
    func onVersionExchange(sdkVersion: String) -> String?
    
    // Called when requesting adapter type
    func onGetAdapterType() -> String?
    
    // Called when requesting user consent state
    func hasUserConsent() -> Bool?
}
