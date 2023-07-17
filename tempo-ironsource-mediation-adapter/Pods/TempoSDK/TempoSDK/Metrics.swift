import Foundation
import TempoSDK

public class Metrics {
   
    
    /// Sends latest version of Metrics array to Tempo backend and then clears
    public static func pushMetrics(currentMetrics: inout [Metric], backupUrl: URL?) {
        
        // Create the url with NSURL
        let url = URL(string: TempoUtils.getMetricsUrl())!
        
        // Create the session object
        let session = URLSession.shared
        
        // Now create the Request object using the url object
        var request = URLRequest(url: url)
        request.httpMethod = "POST" //set http method as POST
        
        // Declare local metric/data varaibles
        let metricData: Data?
        var metricListCopy = [Metric]()
        
        // Assigned values depend on whether it's backup-resend or standard push
        if(backupUrl != nil)
        {
            metricListCopy = TempoDataBackup.fileMetric[backupUrl!]!
            metricData = try? JSONEncoder().encode(metricListCopy)
        }
        else {
            metricListCopy = currentMetrics;
            metricData = try? JSONEncoder().encode(currentMetrics)
            currentMetrics.removeAll()
        }
        request.httpBody = metricData // pass dictionary to data object and set it as request body
        
        // Prints out metrics types being sent in this push
        let outMetricList = backupUrl != nil ? TempoDataBackup.fileMetric[backupUrl!]: metricListCopy
        if(outMetricList != nil)
        {
            var metricOutput = "Metrics: "
            for metric in outMetricList!{
                metricOutput += "\n  - \(metric.metric_type ?? "<TYPE_UNKNOWN>")"
            }
            TempoUtils.Say(msg: "📊 \(metricOutput)")
            TempoUtils.Say(msg: "📊 Payload: " + String(data: metricData ?? Data(), encoding: .utf8)!)
        }
        
        // HTTP Headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(String(Int(Date().timeIntervalSince1970)), forHTTPHeaderField: Constants.Web.METRIC_TIME_HEADER)
        
        // Create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                if(backupUrl == nil) {
                    TempoUtils.Warn(msg: "Data did not send, creating backup")
                    TempoDataBackup.sendData(metricsArray: metricListCopy)
                }
                else{
                    TempoUtils.Warn(msg:"Data did not send, keeping backup: \(backupUrl!)")
                }
                return
            }
            
//            // Output details of response TODO: Harmless - "The data couldn’t be read because it isn’t in the correct format"
//            do{
//                let dataDictionary = try JSONSerialization.jsonObject(with: data!, options: [])
//                TempoUtils.Say(msg: "Response dictionary is: \(dataDictionary)")
//
//            } catch let error as NSError {
//                TempoUtils.Say(msg: "Error: \(error.localizedDescription)")
//            }
            
            // If metrics were backeups - and were successfully resent - delete the file from device storage before sending again in case rules have changed
            if(backupUrl != nil)
            {
                TempoUtils.Say(msg: "Removing backup: \(backupUrl!) (x\(TempoDataBackup.fileMetric[backupUrl!]!.count))")
                
                // Remove metricList from device storage
                TempoDataBackup.removeSpecificMetricList(backupUrl: backupUrl!)
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                //print("Tempo status code: \(httpResponse.statusCode)")
                
                switch(httpResponse.statusCode)
                {
                case 200:
                    TempoUtils.Say(msg: "📊 Passed metrics - do not backup: \(httpResponse.statusCode)")
                    break
                case 400:
                    fallthrough
                case 422:
                    fallthrough
                case 500:
                    TempoUtils.Say(msg: "📊 Passed/Bad metrics - do not backup: \(httpResponse.statusCode)")
                    break
                default:
                    TempoUtils.Say(msg: "📊 Non-Tempo related error - backup: \(httpResponse.statusCode)")
                    TempoDataBackup.sendData(metricsArray: metricListCopy)
                }
            }
        })
        
        task.resume()
    }
}


public struct Metric : Codable {
    var metric_type: String?
    var ad_id: String?
    var app_id: String?
    var timestamp: Int?
    var is_interstitial: Bool?
    var bundle_id: String = "unknown"
    var campaign_id: String = "unknown"
    var session_id: String = "unknown"
    var location: String = "unknown"
//    var gender: String = "?"
//    var age_range: String = "unknown"
//    var income_range: String = "unknown"
    var placement_id: String = "unknown"
    var country_code: String? = TempoUserInfo.getIsoCountryCode2Digit()
    var os: String = "unknown"
    var sdk_version: String
    var adapter_version: String
    var cpm: Float
    var adapter_type: String?
    var consent: Bool?
    var consent_type: String?
}
