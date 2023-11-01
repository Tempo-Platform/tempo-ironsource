import Foundation

/**
 * The class is used to backup any metrics that are not sent due to unforeseen network/communication errors
 * It backs references of them up in the local storage and attempts to send them again the next time the app is restarted
 */
public class TempoDataBackup
{
    public static var readyForCheck: Bool = true
    private static var backupsAtMax: Bool = false
    static var fileMetric: [URL: [Metric]] = [:]
    
    /// Public funciton to start retrieval of backup data
    public static func initCheck() {
        //clearAllData()
        buildMetricArrays()
    }
    
    /// Adds Metric JSON array as data file to device's backup folder
    internal static func storeData(metricsArray: [Metric]?) {
        
        if(backupsAtMax)
        {
            TempoUtils.Warn(msg: "❌ Cannot add anymore backups. At full capacity!")
        }
        else {
            if(metricsArray != nil)
            {
                // Declare file subdirectory to fetch data
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let jsonDirectory = documentsDirectory.appendingPathComponent(Constants.Backup.METRIC_BACKUP_FOLDER)
                do {
                    try FileManager.default.createDirectory(at: jsonDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    TempoUtils.Shout(msg: "Error creating document directory: \(error.localizedDescription)")
                    return
                }
                
                let encoder = JSONEncoder()
                do {
                    // Encode metric array to JSON data object
                    let jsonData = try encoder.encode(metricsArray)
                    
                    // Create unique name using datetime
                    var filename = String(Int(Date().timeIntervalSince1970 * 1000))
                    filename = filename.replacingOccurrences(of: ".", with: "_") +  Constants.Backup.METRIC_BACKUP_APPEND
                    
                    // Create file URL to device storage
                    let fileURL = jsonDirectory.appendingPathComponent(filename)
                    
                    // Add metric arrays to device file storage
                    try jsonData.write(to: fileURL)
                    
                    // Output array details durign debugging
                    let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber
                    var nameList = "Saved files: \(filename) (\(fileSize?.intValue ?? 0 ) bytes)"
                    for metric in metricsArray! {
                        nameList += "\n - \(metric.metric_type ?? "[type_undefined]")"
                    }
                    TempoUtils.Say(msg: "📂 \(nameList)")
                    
                }
                catch{
                    TempoUtils.Shout(msg: "Error either creating or saving JSON: \(error.localizedDescription)")
                    return
                }
            }
        }
        
    }

    /// Checks device's folder allocated to metrics data and builds an array of metric arrays from it
    static func buildMetricArrays() {
        
        // Declare file subdirectory to store data
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let jsonDirectory = documentsDirectory.appendingPathComponent(Constants.Backup.METRIC_BACKUP_FOLDER)
        
        guard let contents = try? FileManager.default.contentsOfDirectory(at: jsonDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        if(contents.count == 0) {
            TempoUtils.Say(msg: "✅ No Backups! [\(contents.count)]")
            return
        }
        else {
            TempoUtils.Say(msg: "📂 Backups Found! [\(contents.count)]")
        }
        
        // Check backups are not at full capacity
        if(contents.count > Constants.Backup.MAX_BACKUPS) {
            TempoUtils.Warn(msg: "❌ Max Backups! [\(contents.count)]")
            backupsAtMax = true
        }
        
        // Loop through backend metrics and add to static dictionary
        for fileURL in contents {
            do {
                // Check is backup has passed expiry date
                var filepathString: String
                if #available(iOS 16.0, *) {
                    filepathString = fileURL.path()
                } else {
                    filepathString = fileURL.path
                }
                
                do{
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: filepathString)
                    if let creationDate = fileAttributes[.creationDate] as? Date {
                        let currentDate = Date()
                        let calendar = Calendar.current
                        let daysOld = calendar.dateComponents([.day], from: creationDate, to: currentDate).day ?? 0
                        
                        if daysOld >= Constants.Backup.EXPIRY_DAYS {
                            removeSpecificMetricList(backupUrl: fileURL)
                            TempoUtils.Warn(msg: "File is older than \(Constants.Backup.EXPIRY_DAYS) days")
                            continue
                        }
                    }
                    
                } catch {
                    TempoUtils.Shout(msg: "Error checking backup file date: \(error)")
                }
                
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                
                // Individual metric objects
                let metricPayload = try decoder.decode([Metric].self, from: data)
                for metric in metricPayload
                {
                    fileMetric[fileURL] = metricPayload
                    TempoUtils.Say(msg: "📊 \(fileURL) => \(metric.metric_type ?? "UNKNOWN")")
                }
                
            } catch let error {
                TempoUtils.Shout(msg: "Error reading file at \(fileURL): \(error)")
                continue
            }
        }
    }

    /// Uses parameter file URL to locate and remove the file from local backup folder
    public static func removeSpecificMetricList(backupUrl: URL) {
        do {
            // Remove each file
            try FileManager.default.removeItem(at: backupUrl)
            TempoUtils.Say(msg: "Removing file: \(backupUrl)")
        } catch {
            TempoUtils.Shout(msg: "Error while attempting to remove '\(backupUrl)' from backup folder: \(error)")        }
    }
    
    
    public static func getMostRecentLocationData() -> LocationData {
        
        // To retrieve the instance from UserDefaults:
        if let savedLocationData = UserDefaults.standard.data(forKey: Constants.Backup.LOC_BACKUP_REF),
            let decodedLocation = try? JSONDecoder().decode(LocationData.self, from: savedLocationData) {
            // Use the retrieved location data
            TempoUtils.Say(msg: "🌎 Most recent location backed up: admin=\(decodedLocation.admin_area ?? "nil"), locality=\(decodedLocation.locality ?? "nil")")
            return decodedLocation
        } else {
            TempoUtils.Warn(msg: "🌎 Failed to backup most recent location")
        }
        
        return LocationData()
    }
    
    /// Clears ALL references in the dedicated local backup folder
    static func clearAllData()  {
        let jsonDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(Constants.Backup.METRIC_BACKUP_FOLDER)
        
        do {
            // Get the contents of the directory
            let contents = try FileManager.default.contentsOfDirectory(at: jsonDirectory, includingPropertiesForKeys: nil, options: [])

            // Iterate over the contents and remove each file
            for fileURL in contents {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            TempoUtils.Shout(msg: "Error while attempting to clear backup folder: \(error)")
        }
    }
    
    public static func checkHeldMetrics(completion: @escaping (inout [Metric], URL) -> Void) {
        // See if check has already been called
        if(readyForCheck) {
            // Request creation of backup metrics dictionary
            initCheck()
            //TempoUtils.Say(msg: "Resending: \(TempoDataBackup.fileMetric.count)")
            
            var emptyArray: [Metric] = []
            
            // Cycles through each stored arrays and resends
            for url in fileMetric.keys
            {
                // Attempt to push metric(s) again
                completion(&emptyArray, url)
            }
            
            // Prevents from being checked again this session. If network is failing, no point retrying during this session
            readyForCheck = false
        }
    }
}
