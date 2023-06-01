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


extension ViewController: LevelPlayInterstitialDelegate {
    // LevelPlayInterstitialDelegate functions
    func didShow(with adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didClick(with adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didLoad(with adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didFailToLoadWithError(_ error: Error!) {
        ISTempoUtils.bangLog(msg: String(describing: error.self));
    }
    func didOpen(with adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    func didFailToShowWithError(_ error: Error!, andAdInfo adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: "\(String(describing: error.self)) |  \(ISTempoUtils.adUnitStringer(adInfo: adInfo))");
    }
    func didClose(with adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo));
    }
    
    
}


extension ViewController: LevelPlayRewardedVideoDelegate {
    // LevelPlayRewardedVideoManualDelegate functions
    func didReceiveReward(forPlacement placementInfo: ISPlacementInfo!, with adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: "\(placementInfo.placementName ?? "NO_PLACEMENT") | \(ISTempoUtils.adUnitStringer(adInfo: adInfo))")
    }
    func didClick(_ placementInfo: ISPlacementInfo!, with adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: "\(placementInfo.placementName ?? "NO_PLACEMENT") | \(ISTempoUtils.adUnitStringer(adInfo: adInfo))");
    }
    
}

class ViewController: UIViewController, ISInitializationDelegate, ISImpressionDataDelegate {
        
    func hasAvailableAd(with adInfo: ISAdInfo!) {
        ISTempoUtils.bangLog(msg: ISTempoUtils.adUnitStringer(adInfo: adInfo))
    }

    func hasNoAvailableAd() {
        ISTempoUtils.bangLog()
    }

    @IBOutlet weak var rewardedLoadBtn: UIButton!
    @IBOutlet weak var rewardedShowBtn: UIButton!
    @IBOutlet weak var interstitialLoadBtn: UIButton!
    @IBOutlet weak var interstitialShowBtn: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    
    @IBAction func rewardedLoadBtnAction(_ sender: Any) {
        ISTempoUtils.bangLog()
        IronSource.loadRewardedVideo()
        print("❌ loadTriggered")
    }
    @IBAction func rewardedShowBtnAction(_ sender: Any) {
        ISTempoUtils.bangLog()
        IronSource.showRewardedVideo(with: self)//, "rew-ios-000")//, placement: "tempoR1")
        //IronSource.showISDemandOnlyRewardedVideo(self, instanceId: "rew-ios-000")//, placement: "tempoR1")
        print("❌ showTriggered")
    }
    
    @IBAction func interstitialLoadBtnAction(_ sender: Any) {
        IronSource.loadInterstitial()
    }
    @IBAction func interstitialPlayBtnAction(_ sender: Any) {
        IronSource.showInterstitial(with: self)
    }
    
    override func viewDidLoad() {
        ISTempoUtils.bangLog();
        super.viewDidLoad()
        
        // Initialise ironSource listeners and SDK
        self.setupIronSourceSdk()
        
        // Set up UI Buttons etc
        initUIElements()
    }
    
    /// Dispose of any resources that can be recreated.
    override func didReceiveMemoryWarning() {
        ISTempoUtils.bangLog();
        super.didReceiveMemoryWarning()
    }
    
    func setLevelPlayTesting() {
//        IronSource.setMetaDataWithKey("is_test_suite", value: "enable")
//        IronSource.launchTestSuite(self)
        
        
    }
    
    func setupIronSourceSdk() {
        ISTempoUtils.bangLog();
        print("💥 ISIntegrationHelper.validateIntegration()");
        ISIntegrationHelper.validateIntegration()
        
        
        
        //IronSource.add(self) // ?????????????????
        
        // Set the REWARDED ad listeners
        IronSource.setLevelPlayRewardedVideoDelegate(self)
        
        // Set the INTERSTITIAL ad listeners
        IronSource.setLevelPlayInterstitialDelegate(self)
        
        // Init SDK
        IronSource.initWithAppKey(kAPPKEY, delegate: self)
    }
    
    // Initialisation functions
    func initializationDidComplete() {
        ISTempoUtils.bangLog()
        setLevelPlayTesting()
    }
    
    /// Initialize the UI elements of the activity
    func initUIElements() {
        // Update version label
        self.versionLabel.text =  String(format: "%@%@", "sdk version: ", IronSource.sdkVersion());
        ISTempoUtils.bangLog();
    }
    


    // BOTH functions
    // Impressions functions
    func impressionDataDidSucceed(_ impressionData: ISImpressionData!) {
        ISTempoUtils.bangLog(msg: impressionData.all_data?.debugDescription ?? "NO_ALL_DATA");
    }


}

