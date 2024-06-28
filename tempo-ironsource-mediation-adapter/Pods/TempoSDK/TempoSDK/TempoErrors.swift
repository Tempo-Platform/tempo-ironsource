//
//  TempoErrors.swift
//  TempoSDK
//
//  Created by Stephen Baker on 26/6/2024.
//

import Foundation

enum CountryCodeError: Error {
    case unknownError
    case missingCountryCode
    case missingCurrencyCode
    case missingRegionLocale
}

enum MetricsError: Error {
    case unknownError
    case invalidURL
    case jsonEncodingFailed
    case missingJsonString
    case emptyMetrics
    case networkError(Error)
    case invalidHeaderValue
    case failedToRemoveFiles(Error)
    case checkingFailed(Error)
    case metricResendFailed(URL, Error)
    
    // Backups
    case invalidDirectory
    case contentsOfDirectoryFailed(Error)
    case attributesOfItemFailed(Error)
    case dataReadingFailed(Error)
    case decodingFailed(Error)
}

enum StoreDataError: Error {
    case directoryCreationFailed
    case jsonDataEncodingFailed
    case fileWriteFailed
    case attributesFetchFailed
}

enum LocationDataError: Error {
    case missingBackupData
    case decodingFailed(Error)
    case authorizationFailed
}

enum AdProcessError: Error {
    case loadFailed(Error)
    case webViewCreationFailed
    case invalidPlacementId
    case invalidCpmFloor
    case invalidUrl
}

enum ProfileError: Error {
    case idfaNotAvailable
    case invalidAdId
}

enum AdRequestError: Error {
    case missingBackupData
    case decodingFailed(String)
    case urlCreationFailed
    case invalidHttpResponse
    case invalidDataError(String)
    case invalidStatusCode(Int)
}

enum WebViewError: Error {
    case webViewCreationFailed
    case backgroundViewCreationFailed
    case configurationFailed
}

enum WebURLError: Error {
    case invalidCampaignId
    case invalidURLSuffix
    case invalidCustomCampaignID
}
