//
//  ViewController.swift
//  tempo-ironsource-mediation-adapter
//
//  Created by Stephen Baker on 30/5/2023.
//

import UIKit
import IronSource
import TempoSDK
import tempo_ios_ironsource_mediation
import CoreLocation


let prodKey = "1ade2c39d"
let devKey = "1a470a75d"

let kAPPKEY = Constants.isProd ? prodKey : devKey

class ViewController: UIViewController, LevelPlayInterstitialDelegate, LevelPlayRewardedVideoManualDelegate, ISInitializationDelegate, ISImpressionDataDelegate {
    
    var locationManager: CLLocationManager?
    // Button outlet/actions
    @IBOutlet weak var rewardedLoadBtn: UIButton!
    @IBOutlet weak var rewardedShowBtn: UIButton!
    @IBOutlet weak var interstitialLoadBtn: UIButton!
    @IBOutlet weak var interstitialShowBtn: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    @IBAction func rewardedLoadBtnAction(_ sender: Any) {
        IronSource.loadRewardedVideo()
    }
    @IBAction func rewardedShowBtnAction(_ sender: Any) {
        IronSource.showRewardedVideo(with: self)
    }
    @IBAction func interstitialLoadBtnAction(_ sender: Any) {
        IronSource.loadInterstitial()
    }
    @IBAction func interstitialPlayBtnAction(_ sender: Any) {
        IronSource.showInterstitial(with: self)
    }
    
    @IBAction func LocationConsent(_ sender: Any) {
        //TempoUtils.requestLocation()
        print("🤷‍♂️ requestWhenInUseAuthorization (button)")
        locationManager = CLLocationManager()
        locationManager!.requestWhenInUseAuthorization()
    }
    
    /// Initial actions on when view loads
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise ironSource listeners and SDK
        self.setupIronSourceSdk()
        
        // Set up UI Buttons etc
        initUIElements()
    }
    
    /// Dispose of any resources that can be recreated.
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func setupIronSourceSdk() {
        //ISIntegrationHelper.validateIntegration()
        
        // Set the REWARDED ad listeners
        IronSource.setLevelPlayRewardedVideoManualDelegate(self)
        
        // Set the INTERSTITIAL ad listeners
        IronSource.setLevelPlayInterstitialDelegate(self)
        
        // Init SDK
        IronSource.initWithAppKey(kAPPKEY, delegate: self)
    }
    
    /// Initialisation functions
    func initializationDidComplete() {
        TempoUtils.Say(msg: "initializationDidComplete")
    }
    
    /// Initialize the UI elements of the activity
    func initUIElements() {
        // Update version label
        self.versionLabel.text =  String(format: "%@%@", "IronSource SDK: ", IronSource.sdkVersion());
    }
    
    /// LevelPlayInterstitialDelegate functions
    func didShow(with adInfo: ISAdInfo!) {
        TempoUtils.Say(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didClick(with adInfo: ISAdInfo!) { // NEVER GETS CALLED BY OUR ADAPTER
        TempoUtils.Say(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    
    /// LevelPlayRewardedVideoDelegate functions
    func hasAvailableAd(with adInfo: ISAdInfo!) {
        TempoUtils.Say(msg: "****** Has Video: \(IronSource.hasRewardedVideo()) | \(ISTempoUtils.adUnitStringer(adInfo: adInfo))")
    }
    func hasNoAvailableAd() {
    }
    func didReceiveReward(forPlacement placementInfo: ISPlacementInfo!, with adInfo: ISAdInfo!) { // NEVER GETS CALLED BY OUR ADAPTER
        TempoUtils.Say(msg: "\(placementInfo.placementName ?? "NO_PLACEMENT") | \(ISTempoUtils.adUnitStringer(adInfo: adInfo))")
    }
    func didClick(_ placementInfo: ISPlacementInfo!, with adInfo: ISAdInfo!) { // NEVER GETS CALLED BY OUR ADAPTER
        TempoUtils.Say(msg: "\(placementInfo.placementName ?? "NO_PLACEMENT") | \(ISTempoUtils.adUnitStringer(adInfo: adInfo))");
    }
    
    /// BOTH Reward/Interstitalfunctions
    func didLoad(with adInfo: ISAdInfo!) {
        TempoUtils.Say(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didFailToLoadWithError(_ error: Error!) {
        TempoUtils.Say(msg: String(describing: error.self));
    }
    func didOpen(with adInfo: ISAdInfo!) {
        TempoUtils.Say(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didFailToShowWithError(_ error: Error!, andAdInfo adInfo: ISAdInfo!) { // NEVER GETS CALLED BY OUR ADAPTER
        TempoUtils.Say(msg: "\(String(describing: error.self)) |  \(ISTempoUtils.adUnitStringer(adInfo: adInfo))");
    }
    func didClose(with adInfo: ISAdInfo!) {
        TempoUtils.Say(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    
    // Impressions functions
    func impressionDataDidSucceed(_ impressionData: ISImpressionData!) {
        TempoUtils.Say(msg: impressionData.all_data?.debugDescription ?? "NO_ALL_DATA");
    }


}

