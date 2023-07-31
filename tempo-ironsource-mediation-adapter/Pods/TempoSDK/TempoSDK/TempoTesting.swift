//
//  TempoTesting.swift
//  TempoSDK
//
//  Created by Stephen Baker on 24/7/2023.
//

import Foundation

public class TempoTesting {
    
    public static var instance: TempoTesting?
    
    public var isTestingDeployVersion: Bool = false
    public var isTestingCustomCampaigns: Bool = false
    public var currentDeployVersion: String?
    public var customCampaignId: String?
    
    public init() {
        TempoTesting.instance = self
    }
    
    public func toggleTesting() -> Void {
        Constants.isTesting = !Constants.isTesting
    }
    
    public func updateEnvironment(isProd: Bool) -> Void {
        Constants.isProd = isProd
    }
    
    public func activateUseOfDeployVersion(activate: Bool) -> Void {
        isTestingDeployVersion = activate
    }
    
    public func updateDeployVersion(newVersion: String) -> Void {
        currentDeployVersion = newVersion
    }
    
    public func activateCustomCampaigns(activate: Bool) -> Void {
        isTestingCustomCampaigns = activate
    }
    
    public func updateCustomCampaignId(campaignId: String) -> Void {
        customCampaignId = campaignId
    }
}
