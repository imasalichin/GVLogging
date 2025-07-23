// The Swift Programming Language
// https://docs.swift.org/swift-book

import OSLog

public enum Configuration: String, Sendable {
    case domain
    case subsystem
    case category
}

final public class GVLogs: Sendable {
    private let configuration: [Configuration: String]
    private let logger: Logger
    
    public init(configuration: [Configuration: String]) {
        self.configuration = configuration
        let subsystem = configuration[.subsystem] ?? Bundle.main.bundleIdentifier!
        let category = configuration[.category] ?? "Logs"
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    public func log(event: String) {
        logger.debug("GVLogs: \(event)")
    }
}
