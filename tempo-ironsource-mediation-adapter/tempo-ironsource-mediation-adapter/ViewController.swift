//
//  ViewController.swift
//  tempo-ironsource-mediation-adapter
//
//  Created by Stephen Baker on 30/5/2023.
//

import UIKit
import IronSource
import TempoSDK
import tempo_ironsource_mediation

let kAPPKEY = "1a366cbe5"

class ViewController: UIViewController, LevelPlayInterstitialDelegate, LevelPlayRewardedVideoDelegate, ISInitializationDelegate, ISImpressionDataDelegate {
    

    // Button outlet/actions
    @IBOutlet weak var rewardedLoadBtn: UIButton!
    @IBOutlet weak var rewardedShowBtn: UIButton!
    @IBOutlet weak var interstitialLoadBtn: UIButton!
    @IBOutlet weak var interstitialShowBtn: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    @IBAction func rewardedLoadBtnAction(_ sender: Any) {
        ISTempoUtils.shout()
        IronSource.loadRewardedVideo()
    }
    @IBAction func rewardedShowBtnAction(_ sender: Any) {
        ISTempoUtils.shout()
        IronSource.showRewardedVideo(with: self, placement: "tempoR1")
    }
    @IBAction func interstitialLoadBtnAction(_ sender: Any) {
        ISTempoUtils.shout()
        IronSource.loadInterstitial()
    }
    @IBAction func interstitialPlayBtnAction(_ sender: Any) {
        ISTempoUtils.shout()
        IronSource.showInterstitial(with: self)
    }
    
    /// Initial actions on when view loads
    override func viewDidLoad() {
        ISTempoUtils.shout();
        super.viewDidLoad()
        
        // Initialise ironSource listeners and SDK
        self.setupIronSourceSdk()
        
        // Set up UI Buttons etc
        initUIElements()
    }
    
    /// Dispose of any resources that can be recreated.
    override func didReceiveMemoryWarning() {
        ISTempoUtils.shout();
        super.didReceiveMemoryWarning()
    }
    
    func setupIronSourceSdk() {
        ISTempoUtils.shout();
        //ISIntegrationHelper.validateIntegration()
        
        // Set the REWARDED ad listeners
        IronSource.setLevelPlayRewardedVideoDelegate(self)
        
        // Set the INTERSTITIAL ad listeners
        IronSource.setLevelPlayInterstitialDelegate(self)
        
        // Init SDK
        IronSource.initWithAppKey(kAPPKEY, delegate: self)
    }
    
    /// Initialisation functions
    func initializationDidComplete() {
        ISTempoUtils.shout()
    }
    
    /// Initialize the UI elements of the activity
    func initUIElements() {
        // Update version label
        self.versionLabel.text =  String(format: "%@%@", "IronSource SDK: ", IronSource.sdkVersion());
        ISTempoUtils.shout();
    }
    
    /// LevelPlayInterstitialDelegate functions
    func didShow(with adInfo: ISAdInfo!) {
        ISTempoUtils.shout(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didClick(with adInfo: ISAdInfo!) { // NEVER GETS CALLED BY OUR ADAPTER
        ISTempoUtils.shout(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    
    /// LevelPlayRewardedVideoDelegate functions
    func hasAvailableAd(with adInfo: ISAdInfo!) {
        ISTempoUtils.shout(msg: "****** Has Video: \(IronSource.hasRewardedVideo()) | \(ISTempoUtils.adUnitStringer(adInfo: adInfo))")
    }
    func hasNoAvailableAd() {
        ISTempoUtils.shout()
    }
    func didReceiveReward(forPlacement placementInfo: ISPlacementInfo!, with adInfo: ISAdInfo!) { // NEVER GETS CALLED BY OUR ADAPTER
        ISTempoUtils.shout(msg: "\(placementInfo.placementName ?? "NO_PLACEMENT") | \(ISTempoUtils.adUnitStringer(adInfo: adInfo))")
    }
    func didClick(_ placementInfo: ISPlacementInfo!, with adInfo: ISAdInfo!) { // NEVER GETS CALLED BY OUR ADAPTER
        ISTempoUtils.shout(msg: "\(placementInfo.placementName ?? "NO_PLACEMENT") | \(ISTempoUtils.adUnitStringer(adInfo: adInfo))");
    }
    
    /// BOTH Reward/Interstitalfunctions
    func didLoad(with adInfo: ISAdInfo!) {
        ISTempoUtils.shout(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didFailToLoadWithError(_ error: Error!) {
        ISTempoUtils.shout(msg: String(describing: error.self));
    }
    func didOpen(with adInfo: ISAdInfo!) {
        ISTempoUtils.shout(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didFailToShowWithError(_ error: Error!, andAdInfo adInfo: ISAdInfo!) { // NEVER GETS CALLED BY OUR ADAPTER
        ISTempoUtils.shout(msg: "\(String(describing: error.self)) |  \(ISTempoUtils.adUnitStringer(adInfo: adInfo))");
    }
    func didClose(with adInfo: ISAdInfo!) {
        ISTempoUtils.shout(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    
    // Impressions functions
    func impressionDataDidSucceed(_ impressionData: ISImpressionData!) {
        ISTempoUtils.shout(msg: impressionData.all_data?.debugDescription ?? "NO_ALL_DATA");
    }


}

