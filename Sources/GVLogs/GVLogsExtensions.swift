//
//  GVLogsExtensions.swift
//  GVLogs
//
//  Created by NarberalGamma on 14.08.2025.
//

import Foundation

extension String {
    func asDate() -> Date? {
        if  let startDate = ISO8601DateFormatter.formatterWithFractionalSeconds().date(from: self) {
            return startDate
        } else if !self.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone.ReferenceType.local
            return formatter.date(from: self)
        }
        return nil
    }
}

extension ISO8601DateFormatter {
    static func formatterWithFractionalSeconds() -> ISO8601DateFormatter {
        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions.insert(.withFractionalSeconds)
        
        return isoDateFormatter
    }
    
    static func local() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        formatter.timeZone = TimeZone.current
        return formatter
    }
}
