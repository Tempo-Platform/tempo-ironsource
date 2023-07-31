public protocol TempoAdListener {
    // Called when the interstitial content is finished loading.
    func onTempoAdFetchSucceeded(isInterstitial: Bool)
    
    // Called when an error occurs loading the interstitial content.
    func onTempoAdFetchFailed(isInterstitial: Bool)
    
    // Called when the interstitial has closed and disposed of its views.
    func onTempoAdClosed(isInterstitial: Bool)
    
    // Called when an ad goes full screen.
    func onTempoAdDisplayed(isInterstitial: Bool)
    
    // Called when an ad is clicked.
    func onTempoAdClicked(isInterstitial: Bool)  // TODO: actually monitor clicks and call this callback
    
    // Called when swapping version information
    func getTempoAdapterVersion() -> String?
    
    // Called when requesting adapter type
    func getTempoAdapterType() -> String?
    
    // Called when requesting user consent state
    func hasUserConsent() -> Bool?
}
