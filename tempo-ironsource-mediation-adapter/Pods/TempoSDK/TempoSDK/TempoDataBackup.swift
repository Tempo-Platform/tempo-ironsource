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
    public static func initCheck() throws {
        try buildMetricArrays()
    }
    
    /// Adds Metric JSON array as data file to device's backup folder
    internal static func storeData(metricsArray: [Metric]?) throws {
        
        // Full capacity - end job
        guard !backupsAtMax else {
            TempoUtils.warn(msg: "❌ Cannot add anymore backups. At full capacity!")
            return
        }
        
        // If metrics array is nil, no action needed
        guard let metricsArray = metricsArray else {
            return
        }
        
        // Declare file subdirectory to fetch data
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let jsonDirectory = documentsDirectory.appendingPathComponent(Constants.Backup.METRIC_BACKUP_FOLDER)
        do {
            try FileManager.default.createDirectory(at: jsonDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            TempoUtils.shout(msg: "Error creating document directory: \(error.localizedDescription)")
            throw StoreDataError.directoryCreationFailed
        }
        
        do {
            // Encode metric array to JSON data object
            let jsonData = try JSONEncoder().encode(metricsArray)
            
            // Create unique name using datetime
            var filename = String(Int(Date().timeIntervalSince1970 * 1000))
            filename = filename.replacingOccurrences(of: ".", with: "_") +  Constants.Backup.METRIC_BACKUP_APPEND
            
            // Create file URL to device storage
            let fileURL = jsonDirectory.appendingPathComponent(filename)
            
            // Add metric arrays to device file storage
            do {
                try jsonData.write(to: fileURL)
            } catch {
                TempoUtils.shout(msg: "Error saving JSON data to file: \(error.localizedDescription)")
                throw StoreDataError.fileWriteFailed
            }
            
            // Output array details durign debugging
            if let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber {
                var nameList = "Saved files: \(filename) (\(fileSize.intValue) bytes)"
                for metric in metricsArray {
                    nameList += "\n - \(metric.metric_type ?? "[type_undefined]")"
                }
                TempoUtils.say(msg: "📂 \(nameList)")
            } else {
                TempoUtils.shout(msg: "Error fetching file attributes after saving")
                throw StoreDataError.attributesFetchFailed
            }
        } catch {
            TempoUtils.shout(msg: "Error saving JSON data to file: \(error.localizedDescription)")
            throw StoreDataError.jsonDataEncodingFailed
        }
    }

    /// Checks device's folder allocated to metrics data and builds an array of metric arrays from it
    static func buildMetricArrays() throws {
        
        // Declare file subdirectory to store data, escape if failed validation
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            TempoUtils.shout(msg: "Directory targeted for backups is invalid")
            throw MetricsError.invalidDirectory
        }
        let jsonDirectory = documentsDirectory.appendingPathComponent(Constants.Backup.METRIC_BACKUP_FOLDER)
        
        // Get contents of directory,, escape if failed validation
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(at: jsonDirectory, includingPropertiesForKeys: nil)
        } catch {
            TempoUtils.shout(msg: "Contents of directory failed: \(error.localizedDescription)")
            throw MetricsError.contentsOfDirectoryFailed(error)
        }
        
        // If no backups, ignore and leave
        if(contents.isEmpty) {
            TempoUtils.say(msg: "✅ No Backups! [\(contents.count)]")
            return
        }
        else {
            TempoUtils.say(msg: "📂 Backups Found! [\(contents.count)]")
        }
        
        // Check backups are not at full capacity
        if(contents.count > Constants.Backup.MAX_BACKUPS) {
            TempoUtils.warn(msg: "❌ Max Backups! [\(contents.count)]")
            backupsAtMax = true
        }
        
        // Loop through backend metrics and add to static dictionary
        for fileURL in contents {
            // Check is backup has passed expiry date
            var filepathString: String
            if #available(iOS 16.0, *) {
                filepathString = fileURL.path()
            } else {
                filepathString = fileURL.path
            }
            
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: filepathString)
                if let creationDate = fileAttributes[.creationDate] as? Date {
                    let currentDate = Date()
                    let calendar = Calendar.current
                    let daysOld = calendar.dateComponents([.day], from: creationDate, to: currentDate).day ?? 0
                    
                    if daysOld >= Constants.Backup.EXPIRY_DAYS {
                        try removeSpecificMetricList(backupUrl: fileURL)
                        TempoUtils.warn(msg: "File is older than \(Constants.Backup.EXPIRY_DAYS) days")
                        continue
                    }
                }
            } catch {
                TempoUtils.shout(msg: "Error checking backup file date: \(error)")
                //throw MetricsError.attributesOfItemFailed(error) // Don't throw as others may be valid
                continue
            }
            
            // Confirm file data is valid
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch {
                TempoUtils.shout(msg: "Error checking backup file date: \(error)")
                //throw MetricsError.dataReadingFailed(error) // Don't throw as others may be valid
                continue
            }
            let decoder = JSONDecoder()
            
            // Individual metric objects
            let metricPayload:[Metric]
            do {
                metricPayload = try decoder.decode([Metric].self, from: data)
                TempoUtils.say(msg: "metricPayload validated")
            } catch {
                TempoUtils.shout(msg: "Decoding failed: \(error.localizedDescription)")
                //throw MetricsError.decodingFailed(error) // Don't throw as others may be valid
                continue
            }
            
            for metric in metricPayload
            {
                fileMetric[fileURL] = metricPayload
                TempoUtils.say(msg: "📊 \(fileURL) => \(metric.metric_type ?? "UNKNOWN")")
            }
        }
    }

    /// Uses parameter file URL to locate and remove the file from local backup folder
    public static func removeSpecificMetricList(backupUrl: URL) throws {
        do {
            // Remove each file
            try FileManager.default.removeItem(at: backupUrl)
            TempoUtils.say(msg: "Removing file: \(backupUrl)")
        } catch let error as NSError {
            switch error.code {
            case NSFileNoSuchFileError: TempoUtils.warn(msg: "Error: File not found '\(backupUrl)'")
            case NSFileWriteNoPermissionError:  TempoUtils.warn(msg: "Error: No permission to remove file '\(backupUrl)'")
            case NSFileWriteFileExistsError:  TempoUtils.warn(msg: "Error: Directory not empty '\(backupUrl)'")
            case NSFileWriteVolumeReadOnlyError:  TempoUtils.warn(msg: "Error: File system is read-only '\(backupUrl)'")
            default: TempoUtils.warn(msg: "Error while attempting to remove '\(backupUrl)' from backup folder: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    /// Checks backups for any cached location data
    public static func getLocationDataFromCache() throws -> LocationData {
        
        // Validate backup location exists with UserDefaults using 'locationData' key
        guard let savedLocationData = UserDefaults.standard.data(forKey: Constants.Backup.LOC_BACKUP_REF) else {
            TempoUtils.warn(msg: "Could not find cache location for LocData")
            throw LocationDataError.missingBackupData
        }
        
        // Confirm backup file is valid
        do {
            let decodedLocation = try JSONDecoder().decode(LocationData.self, from: savedLocationData)
            TempoUtils.say(msg: "🌎 Most recent location backed up: admin=\(decodedLocation.admin_area ?? "nil"), locality=\(decodedLocation.locality ?? "nil")")
            return decodedLocation
        } catch {
            TempoUtils.warn(msg: "Error decoding existing LocData JSON: \(error)")
            throw LocationDataError.decodingFailed(error)
        }
    }
    
    /// Clears ALL references in the dedicated local backup folder
    static func clearAllData() throws {
        let jsonDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(Constants.Backup.METRIC_BACKUP_FOLDER)
        
        do {
            // Get the contents of the directory
            let contents = try FileManager.default.contentsOfDirectory(at: jsonDirectory, includingPropertiesForKeys: nil, options: [])

            // Iterate over the contents and remove each file
            for fileURL in contents {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            TempoUtils.shout(msg: "Error while attempting to clear backup folder: \(error)")
            throw MetricsError.failedToRemoveFiles(error)
        }
    }
    
    /// Checks if any metric data held in case, actions completion task (usually PushMetrics) if existing data valid
    public static func checkHeldMetrics(completion: @escaping (inout [Metric], URL) throws -> Void) throws {
        // See if check has already been called
        if(readyForCheck) {
            // Request creation of backup metrics dictionary
            do{
                try initCheck()
                //TempoUtils.Say(msg: "Resending: \(TempoDataBackup.fileMetric.count)")
                
                var emptyArray: [Metric] = []
                
                // Cycles through each stored arrays and resends
                for url in fileMetric.keys
                {
                    // Attempt to push metric(s) again
                    do{
                        try completion(&emptyArray, url)
                    }
                    catch {
                        TempoUtils.warn(msg: "\(error)")
                        //throw MetricsError.metricResendFailed(url, error) // Don't throw as others may be valid
                        continue
                    }
                }
            } catch {
                TempoUtils.warn(msg: "Error while checking backup metrics: \(error.localizedDescription)")
                throw MetricsError.checkingFailed(error)
            }
            
            // Prevents from being checked again this session. If network is failing, no point retrying during this session
            readyForCheck = false
        }
    }
}
