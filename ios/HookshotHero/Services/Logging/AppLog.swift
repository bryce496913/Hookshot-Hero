import OSLog

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "HookshotHero"
    static let lifecycle = Logger(subsystem: subsystem, category: "app-lifecycle")
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
    static let session = Logger(subsystem: subsystem, category: "game-session")
    static let rendering = Logger(subsystem: subsystem, category: "rendering")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let errors = Logger(subsystem: subsystem, category: "errors")
}
