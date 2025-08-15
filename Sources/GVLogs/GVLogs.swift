//
//  Logger.swift
//  givelify
//
//  Created by Ivan Masalichin on 11.08.2025.
//  Copyright © 2025 Givelify. All rights reserved.
//

import OSLog
import RealmSwift
import UIKit

final public class GVLogger: @unchecked Sendable {
    private let configuration: GVLogsConfig
    private var subsystem: String {
        Bundle.main.bundleIdentifier ?? "GVLogger"
    }
    private var category: String {
        "GVLogger"
    }
    private lazy var logger: os.Logger = {
        Logger(subsystem: subsystem, category: category)
    }()
    private var dataFields: [GVLoggerField: String] = [:]
    private var persistenceQueue = DispatchQueue(label: "GVLogger")
    private lazy var realm: Realm = {
        var config = Realm.Configuration(deleteRealmIfMigrationNeeded: true)
        return try! Realm(configuration: config, queue: persistenceQueue)
    }()
    
    public init(configuration: GVLogsConfig) {
        self.configuration = configuration
        Task {
            await fillDeviceFields()
        }
    }
    
    public func log(event: String, properties: [String: Any]?, level: GVLogLevel, completion: (@Sendable (String) -> Void)? = nil) {
        fillTimeFields()
        save(event: event, properties: stringifyDict(properties: properties), level: level, completion: { [weak self] log in
            guard let log, let self else {
                self?.logger.fault("\(event) failed to save")
                return
            }
            let logMessage = "GVLogger: \(log.asJSON)"
            switch level {
            case .info:
                logger.info("\(logMessage)")
            case .debug:
                logger.debug("\(logMessage)")
            case .error:
                logger.error("\(logMessage)")
            case .fault:
                logger.fault("\(logMessage)")
            default:
                logger.log("\(logMessage)")
            }
            completion?(logMessage)
        })
    }
    
    public func setUser(id: String, name: String, email: String?) {
        dataFields[.userID] = id
        dataFields[.userName] = name
        dataFields[.userEmail] = email
    }
    
    public func set(deviceID: String) {
        dataFields[.deviceID] = deviceID
    }
    
    public func setLocation(latitude: Double?, longitude: Double?) {
        if let latitude {
            dataFields[.latitude] = String(format: "%.6f", latitude)
        } else {
            dataFields[.latitude] = nil
        }
        if let longitude {
            dataFields[.longitude] = String(format: "%.6f", longitude)
        } else {
            dataFields[.longitude] = nil
        }
    }
    
    public func fetch(completion: @Sendable @escaping ([[GVLogObject]]) -> Void) {
        persistenceQueue.async { [weak self] in
            guard let self else {
                completion([])
                return
            }
            let results = filter(logs: realm.objects(GVLogObject.self))
            completion(results)
        }
    }
}

extension GVLogger {
    private func save(event: String, properties: [String: String]?, level: GVLogLevel, completion: @Sendable @escaping (GVLogObject?) -> Void) {
        let logID = UUID().uuidString
        persistenceQueue.async { [weak self] in
            guard let self else {
                completion(nil)
                return }
            let userInfoObject = GVUserInfoObject()
            userInfoObject.name = dataFields[.userName] ?? "nil"
            userInfoObject.userID =  dataFields[.userID] ?? "nil"
            userInfoObject.email = dataFields[.userEmail] ?? "nil"
            
            let deviceInfoObject = GVDeviceInfoObject()
            deviceInfoObject.operatingSystem = dataFields[.operatingSystem] ?? "nil"
            deviceInfoObject.model = dataFields[.model] ?? "nil"
            deviceInfoObject.deviceID = dataFields[.deviceID] ?? "nil"
            deviceInfoObject.timeZone = dataFields[.timeZone] ?? "nil"
            deviceInfoObject.latitude = dataFields[.latitude] ?? "nil"
            deviceInfoObject.longitude = dataFields[.longitude] ?? "nil"
            deviceInfoObject.osVersion = dataFields[.osVersion] ?? "nil"
            deviceInfoObject.appVersion = dataFields[.appVersion] ?? "nil"
            
            let logObject = GVLogObject()
            logObject.logID = logID
            logObject.createdAt = dataFields[.createdAt]?.asDate() ?? Date()
            logObject.eventName = event
            logObject.logLevel = level.rawValue
            logObject.correlationID = logID
            logObject.userInfo = userInfoObject
            logObject.deviceInfo = deviceInfoObject
            properties?.forEach({ key, value in
                logObject.properties[key] = value
            })
            logObject.asJSON = logObject.encode()
            
            do {
                try self.realm.write {
                    self.realm.add(logObject)
                }
            } catch {
                print("An error occurred while saving the log: \(error)")
            }
            completion(logObject)
        }
    }
    
    private func filter(logs: Results<GVLogObject>) -> [[GVLogObject]] {
        var predicates: [String] = []
        var arguments: [Any] = []
        let createdAtField = String(describing: GVLoggerField.createdAt)
        if let logsAfter = configuration.logsAfter {
            predicates.append("\(createdAtField) >= %@")
            arguments.append(logsAfter)
        }
        if let logsBefore = configuration.logsBefore {
            predicates.append("\(createdAtField) <= %@")
            arguments.append(logsBefore)
        }
        
        let filtersArray = configuration.filters
        filtersArray.forEach({ filterDict in
            filterDict.values.forEach({ filterValues in
                if let filterKey = filterDict.keys.first, let filterField = GVLoggerField(rawValue: filterKey) {
                    predicates.append("\(filterField) IN %@")
                    arguments.append(filterValues)
                }
            })
        })
        
        let predicateList = predicates.joined(separator: " AND ")
        let predicate = NSPredicate(format: predicateList, argumentArray: arguments)
        print("\nREALM FILTER PREDICATE: \(predicate)\n")
        
        let sortedResults = logs.sorted(byKeyPath: createdAtField, ascending: false)
        let results = sortedResults.filter(predicate).compactMap { $0 } ?? []
        let limitResults = Array(results.prefix(configuration.eventsCount))
        return limitResults.chunked(into: configuration.pageSize)
    }
    
    private func fillDeviceFields() async {
        Task {
            dataFields[.model] = await UIDevice.current.model
            dataFields[.osVersion] = await UIDevice.current.systemVersion
            dataFields[.operatingSystem] = await UIDevice.current.systemName
            let versionNumber: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            dataFields[.appVersion] = versionNumber + "." + buildNumber
        }
    }
    
    private func fillTimeFields() {
        dataFields[.createdAt] = Date().description
        dataFields[.timeZone] = TimeZone.current.identifier
    }
    
    private func stringifyDict(properties: [String: Any]?) -> [String: String] {
        let stringKeys = properties?.map({ (key, value) in
            if let str = value as? String {
                return (key, str)
            } else if let int = value as? Int {
                return (key, String(int))
            } else if let dbl = value as? Double {
                return (key, String(dbl))
            } else if let bool = value as? Bool {
                return (key, String(bool))
            } else {
                return (key, "nil")
            }
        })
        
        return Dictionary(uniqueKeysWithValues: stringKeys ?? [("", "")])
    }
}
