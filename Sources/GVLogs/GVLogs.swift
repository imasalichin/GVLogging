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

public enum GVLoggerField: String {
    case logID = "log_id"
    case createdAt = "created_at"
    case eventName = "event_name"
    case logLevel = "log_level"
    case correlationID = "correlation_id"
    case properties
    
    case userID = "user_id"
    case userName = "user_name"
    case userEmail = "user_email"
    
    case model
    case osVersion = "os_version"
    case operatingSystem
    case appVersion = "app_version"
    case latitude
    case longitude
    case timeZone
    case deviceID = "device_id"
    
    case userInfo = "user_info"
    case deviceInfo = "device_info"
}

public enum GVLogLevel: String, CaseIterable, Sendable {
    case `default`
    case info
    case debug
    case error
    case fault
}

public class GVUserInfoObject: Object, Encodable  {
    @Persisted var name: String
    @Persisted var userID: String
    @Persisted var email: String
    
    enum CodingKeys: String, CodingKey {
        case userID = "id"
        case name = "name"
        case email = "email"
    }
}

public class GVDeviceInfoObject: Object, Encodable  {
    @Persisted var operatingSystem: String
    @Persisted var model: String
    @Persisted var deviceID: String
    @Persisted var timeZone: String
    @Persisted var latitude: String
    @Persisted var longitude: String
    @Persisted var osVersion: String
    @Persisted var appVersion: String
    
    enum CodingKeys: String, CodingKey {
        case model
        case osVersion = "os_version"
        case operatingSystem = "os"
        case appVersion = "app_version"
        case latitude
        case longitude
        case timeZone = "time_zone"
        case deviceID = "device_id"
    }
}

public class GVLogObject: Object, Encodable {
    @Persisted(primaryKey: true) var logID: String
    @Persisted var createdAt: String
    @Persisted var eventName: String
    @Persisted var logLevel: String
    @Persisted var correlationID: String
    @Persisted var userInfo: GVUserInfoObject?
    @Persisted var deviceInfo: GVDeviceInfoObject?
    @Persisted var properties: Map<String, String>
    @Persisted public var asJSON: String
    
    enum CodingKeys: String, CodingKey {
        case logID = "log_id"
        case createdAt = "created_at"
        case eventName = "event_name"
        case userInfo = "user_info"
        case deviceInfo = "device_info"
        case logLevel = "log_level"
        case correlationID = "correlation_id"
        case properties
    }
}

final public class GVLogger: @unchecked Sendable {
    private let configuration: [String: String]
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
        var config = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 1 {
                    migration.enumerateObjects(ofType: "GVLogObject") { oldObject, _ in
                        migration.delete(oldObject!)
                    }
                }
            })
        return try! Realm(configuration: config, queue: persistenceQueue)
    }()
    
    public init(configuration: [String: String]) {
        self.configuration = configuration
        Task {
            await fillDeviceFields()
        }
    }
    
    public func log(event: String, properties: [String: Any]?, level: GVLogLevel) {
        fillTimeFields()
        save(event: event, properties: stringifyDict(properties: properties), level: level, completion: { [weak self] log in
            guard let log, let self else {
                self?.logger.fault("\(event) failed to save")
                return
            }
            let logMessage = "/n/nGVLogger: \(log.asJSON)/n/n"
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
            logObject.createdAt = dataFields[.createdAt] ?? "nil"
            logObject.eventName = event
            logObject.logLevel = level.rawValue
            logObject.correlationID = logID
            logObject.userInfo = userInfoObject
            logObject.deviceInfo = deviceInfoObject
            properties?.forEach({ key, value in
                logObject.properties[key] = value
            })
            logObject.asJSON = encode(log: logObject)
            
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
    
    public func fetch(completion: @Sendable @escaping ([GVLogObject]) -> Void) {
        persistenceQueue.async { [weak self] in
            let results: [GVLogObject] = self?.realm.objects(GVLogObject.self).compactMap { $0 } ?? []
            completion(results)
        }
    }
    
    private func encode(log: GVLogObject) -> String {
        do {
            let jsonData = try JSONEncoder().encode(log)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            return jsonString
        } catch { return error.localizedDescription }
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

