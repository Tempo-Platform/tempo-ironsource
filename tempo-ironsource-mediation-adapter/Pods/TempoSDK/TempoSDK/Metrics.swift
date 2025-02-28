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
            TempoUtils.warn(msg: "Invalid URL for metrics")
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
                TempoUtils.warn(msg: "Error: Failed to encode backup metrics data")
                throw MetricsError.jsonEncodingFailed
            }
            metricData = jsonEncodedBackupData
        } else {
            metricListCopy = currentMetrics
            // Confirm valid JSON from Metric list
            guard let jsonEncodedMetricData = try? JSONEncoder().encode(currentMetrics) else {
                TempoUtils.warn(msg: "Error: Failed to encode metrics data")
                throw MetricsError.jsonEncodingFailed
            }
            metricData = jsonEncodedMetricData
            currentMetrics.removeAll()
        }
        
        // Pass dictionary to data object and set it as request body
        request.httpBody = metricData
        
        // Prints out metrics types being sent in this push, ends if list empty
        let outMetricList = backupUrl != nil ? TempoDataBackup.fileMetric[backupUrl!]: metricListCopy
        guard let unwrappedMetricList = outMetricList, !unwrappedMetricList.isEmpty else {
            TempoUtils.say(msg: "📊 Metrics (0 - nothing sent)")
            throw MetricsError.emptyMetrics
        }
        
        // For printout only (Metric type list)
        var metricOutput = "Metrics (x\(outMetricList?.count ?? 0))"
        for metric in outMetricList!{
            metricOutput += "\n  > \(metric.metric_type ?? "<TYPE_UNKNOWN>")"
        }
        TempoUtils.say(msg: "📊 \(metricOutput)")
        
        // For printout only (Metrics JSON payload)
        do {
            let metricJsonString = String(data: metricData ?? Data(), encoding: .utf8)
            let formattedOutput = try formatMetricsOutput(jsonString: metricJsonString)
            TempoUtils.say(msg: "📊 Payload: " + formattedOutput)
        }
        catch {
            TempoUtils.warn(msg: "📊 Payload: ERROR - could not convert metricData to JSON string")
        }
        
        // On JSON metrics validation, create metrics POST request
        do {
            // Super-pedantic header validation
            request.addValue(Constants.Web.APPLICATION_JSON, forHTTPHeaderField: Constants.Web.HEADER_CONTENT_TYPE)
            request.addValue(Constants.Web.APPLICATION_JSON, forHTTPHeaderField: Constants.Web.HEADER_ACCEPT)
            let metricTimeValue = String(Int(Date().timeIntervalSince1970))
            // Confirm valid date/time first
            guard !metricTimeValue.isEmpty else {
                TempoUtils.warn(msg: "Invalid header value for X-Timestamp header")
                throw MetricsError.invalidHeaderValue
            }
            request.addValue(metricTimeValue, forHTTPHeaderField: Constants.Web.HEADER_METRIC_TIME)
            
            // Create dataTask using the session object to send data to the server
            let task = session.dataTask(with: request, completionHandler: { data, response, error in
                guard error == nil else {
                    if(backupUrl == nil) {
                        TempoUtils.warn(msg: "Data did not send, creating backup")
                        do {
                            try TempoDataBackup.storeData(metricsArray: metricListCopy)
                        } catch {
                            TempoUtils.warn(msg:"Error while backing up data: \(error)")
                            return
                        }
                    }
                    else{
                        TempoUtils.warn(msg:"Data did not send, keeping backup: \(backupUrl!)")
                    }
                    return
                }
                
                // If metrics were back-ups - and were successfully resent - delete the file from device storage before sending again in case rules have changed
                if(backupUrl != nil)
                {
                    TempoUtils.say(msg: "Removing backup: \(backupUrl!) (x\(TempoDataBackup.fileMetric[backupUrl!]!.count))")
                    
                    // Remove metricList from device storage
                    do {
                        try TempoDataBackup.removeSpecificMetricList(backupUrl: backupUrl!)
                    } catch {
                        TempoUtils.warn(msg: "Error removing file: \(error)")
                    }
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch(httpResponse.statusCode)
                    {
                    case 200:
                        TempoUtils.say(msg: "📊 Sent metrics - safe pass: \(httpResponse.statusCode)")
                    case 400, 422, 500:
                        TempoUtils.say(msg: "📊 Passed/Bad metrics - do not backup: \(httpResponse.statusCode)")
                        break
                    default:
                        TempoUtils.say(msg: "📊 Non-Tempo related error - backup: \(httpResponse.statusCode)")
                        do {
                            try TempoDataBackup.storeData(metricsArray: metricListCopy)
                        } catch {
                            TempoUtils.warn(msg:"Error while backing up data: \(error)")
                            return
                        }
                    }
                }
            })
            
            task.resume()
        } catch MetricsError.missingJsonString {
            TempoUtils.warn(msg: "Missing JSON string")
        } catch {
            TempoUtils.warn(msg: "An unknown error occurred: \(error)")
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
