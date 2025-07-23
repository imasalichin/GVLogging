// The Swift Programming Language
// https://docs.swift.org/swift-book

import OSLog

public enum Configuration: String {
    case domain
    case subsystem
    case category
}

final class GVLogs {
    public var shared: GVLogs = GVLogs()
    
    fileprivate let configuration: [Configuration: Any]?
    private var subsystem: String {
        configuration?[.subsystem] as? String ?? Bundle.main.bundleIdentifier!
    }
    private var category: String {
        configuration?[.category] as? String ?? "Logs"
    }
    
    private lazy var logger: Logger = {
        Logger(subsystem: subsystem, category: category)
    }()
    
    init(configuration: [Configuration: Any]? = nil) {
        self.configuration = configuration
    }
    
    public func log(event: String) {
        logger.debug("\(event)")
    }
}
