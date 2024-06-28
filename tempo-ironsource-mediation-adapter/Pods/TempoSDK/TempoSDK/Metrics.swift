import Foundation

public class Metrics {
   
    /// Converst metrics JSON payload into readinle format with new lines for each array member and spaces after commas
    static func formatMetricsOutput(jsonString: String?) throws -> String {
        
        guard var jsonString = jsonString else {
            throw MetricsError.missingJsonString
        }
        
        jsonString = jsonString.replacingOccurrences(of: "[", with: "[\n")
        jsonString = jsonString.replacingOccurrences(of: "]", with: "\n]")
        jsonString = jsonString.replacingOccurrences(of: "},{", with: "},\n\n{")
        jsonString = jsonString.replacingOccurrences(of: ",", with: ", ")
        
        return jsonString
    }
    
    /// Sends latest version of Metrics array to Tempo backend and then clears
    public static func pushMetrics(currentMetrics: inout [Metric], backupUrl: URL?) throws {
        
        // Confirm url is not nil
        guard let url = URL(string: TempoUtils.getMetricsUrl()) else {
            throw MetricsError.invalidURL
        }
        
        // Create the session object
        let session = URLSession.shared
        
        // Now create the Request object using the URL object
        var request = URLRequest(url: url)
        request.httpMethod = Constants.Web.HTTP_METHOD_POST
        
        // Declare local metric/data varaibles
        let metricData: Data?
        var metricListCopy = [Metric]()
        
        // Assigned values depend on whether it's backup-resend or standard push
        if let backupUrl = backupUrl {
            metricListCopy = TempoDataBackup.fileMetric[backupUrl] ?? []
            // Confirm valid JSON from backup Metric list
            guard let jsonEncodedBackupData = try? JSONEncoder().encode(metricListCopy) else {
                throw MetricsError.jsonEncodingFailed // TODO: COnsequencs of this failing?
            }
            metricData = jsonEncodedBackupData
        } else {
            metricListCopy = currentMetrics
            // Confirm valid JSON from Metric list
            guard let jsonEncodedMetricData = try? JSONEncoder().encode(currentMetrics) else {
                throw MetricsError.jsonEncodingFailed // TODO: Consequencs of this failing?
            }
            metricData = jsonEncodedMetricData
            currentMetrics.removeAll()
        }
        
        // Pass dictionary to data object and set it as request body
        request.httpBody = metricData
        
        // Prints out metrics types being sent in this push, ends if list empty
        let outMetricList = backupUrl != nil ? TempoDataBackup.fileMetric[backupUrl!]: metricListCopy
        guard let unwrappedMetricList = outMetricList, !unwrappedMetricList.isEmpty else {
            TempoUtils.Say(msg: "📊 Metrics (0 - nothing sent)")
            throw MetricsError.emptyMetrics
        }
        
        // For printout only (Metric type list)
        var metricOutput = "Metrics (x\(outMetricList?.count ?? 0))"
        for metric in outMetricList!{
            metricOutput += "\n  - \(metric.metric_type ?? "<TYPE_UNKNOWN>")"
        }
        TempoUtils.Say(msg: "📊 \(metricOutput)")
        
        // For printout only (Metrics JSON payload)
        guard let jsonString = String(data: metricData ?? Data(), encoding: .utf8) else {
            throw MetricsError.missingJsonString // TODO: Do I really want to throw here..?
        }
        
        // On JSON metrics validation, create metrics POST request
        do {
            let formattedOutput = try formatMetricsOutput(jsonString: jsonString)
            TempoUtils.Say(msg: "📊 Payload: " + formattedOutput)
            
            // HTTP Headers
            // Super-pedantic header validation
            request.addValue(Constants.Web.APPLICATION_JSON, forHTTPHeaderField: Constants.Web.HEADER_CONTENT_TYPE)
            request.addValue(Constants.Web.APPLICATION_JSON, forHTTPHeaderField: Constants.Web.HEADER_ACCEPT)
            let metricTimeValue = String(Int(Date().timeIntervalSince1970))
            // Confirm valid date/time first
            guard !metricTimeValue.isEmpty else { throw MetricsError.invalidHeaderValue }
            request.addValue(metricTimeValue, forHTTPHeaderField: Constants.Web.HEADER_METRIC_TIME)
            
            // Create dataTask using the session object to send data to the server
            let task = session.dataTask(with: request, completionHandler: { data, response, error in
                guard error == nil else {
                    if(backupUrl == nil) {
                        TempoUtils.Warn(msg: "Data did not send, creating backup")
                        do {
                            try TempoDataBackup.storeData(metricsArray: metricListCopy)
                        } catch {
                            TempoUtils.Warn(msg:"Error while backing up data: \(error)")
                            return
                        }
                    }
                    else{
                        TempoUtils.Warn(msg:"Data did not send, keeping backup: \(backupUrl!)")
                    }
                    return
                }
                
                // If metrics were back-ups - and were successfully resent - delete the file from device storage before sending again in case rules have changed
                if(backupUrl != nil)
                {
                    TempoUtils.Say(msg: "Removing backup: \(backupUrl!) (x\(TempoDataBackup.fileMetric[backupUrl!]!.count))")
                    
                    // Remove metricList from device storage
                    do {
                        try TempoDataBackup.removeSpecificMetricList(backupUrl: backupUrl!)
                    } catch {
                        TempoUtils.Warn(msg: "Error removing file: \(error)")
                    }
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch(httpResponse.statusCode)
                    {
                    case 200:
                        TempoUtils.Say(msg: "📊 Sent metrics - safe pass: \(httpResponse.statusCode)")
                    case 400, 422, 500:
                        TempoUtils.Say(msg: "📊 Passed/Bad metrics - do not backup: \(httpResponse.statusCode)")
                        break
                    default:
                        TempoUtils.Say(msg: "📊 Non-Tempo related error - backup: \(httpResponse.statusCode)")
                        do {
                            try TempoDataBackup.storeData(metricsArray: metricListCopy)
                        } catch {
                            TempoUtils.Warn(msg:"Error while backing up data: \(error)")
                            return
                        }
                    }
                }
            })
            
            task.resume()
        } catch MetricsError.missingJsonString {
            TempoUtils.Warn(msg: "Error: Missing JSON string")
        } catch {
            TempoUtils.Warn(msg: "An unknown error occurred: \(error)")
        }
    }
}

public struct Metric : Codable {
    var metric_type: String?
    var ad_id: String?
    var app_id: String?
    var timestamp: Int?
    var is_interstitial: Bool?
    var bundle_id: String = ""
    var campaign_id: String = ""
    var session_id: String = ""
    var location: String = ""
    var country_code: String = ""
//    var gender: String = ""
//    var age_range: String = ""
//    var income_range: String = ""
    var placement_id: String = ""
    var os: String = ""
    var sdk_version: String
    var adapter_version: String
    var cpm: Float
    var adapter_type: String?
    var consent: Bool?
    var consent_type: String?
    var location_data: LocationData? = nil
}
