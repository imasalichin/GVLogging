//
//  GVLogsModels.swift
//  GVLogs
//
//  Created by Ivan Masalichin on 14.08.2025.
//

import OSLog
import RealmSwift

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

public struct GVLogsConfig: Codable {
    let syncFrequency: Int
    let logsAfter: Date?
    let logsBefore: Date?
    let eventsCount: Int
    let pageSize: Int
    let filters: [[String: [String]]]
    
    enum CodingKeys: String, CodingKey {
        case syncFrequency = "sync_frequency"
        case logsAfter = "logs_after"
        case logsBefore = "logs_before"
        case eventsCount = "events_count"
        case pageSize = "page_size"
        case filters
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.syncFrequency = try container.decode(Int.self, forKey: .syncFrequency)
        let logsAfterString = try container.decode(String.self, forKey: .logsAfter)
        self.logsAfter = logsAfterString.asDate()
        let logsBeforeString = try container.decode(String.self, forKey: .logsBefore)
        self.logsBefore = logsBeforeString.asDate()
        self.eventsCount = try container.decode(Int.self, forKey: .eventsCount)
        self.pageSize = try container.decode(Int.self, forKey: .pageSize)
        self.filters = try container.decode([[String : [String]]].self, forKey: .filters)
    }
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
