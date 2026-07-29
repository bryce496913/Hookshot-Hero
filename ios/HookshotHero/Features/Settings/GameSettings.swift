import Foundation

struct GameSettings: Codable, Equatable, Sendable {
    var musicEnabled = true
    var soundEffectsEnabled = true
    var hapticsEnabled = true
    var reducedMotion = false
    var controlHintsEnabled = true

    static let defaults = GameSettings()
}

protocol SettingsRepository: Sendable {
    func load() -> GameSettings
    func save(_ settings: GameSettings)
}

struct UserDefaultsSettingsRepository: SettingsRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "game-settings-v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> GameSettings {
        guard let data = defaults.data(forKey: key) else { return .defaults }
        do { return try JSONDecoder().decode(GameSettings.self, from: data) }
        catch { AppLog.persistence.error("Could not decode settings: \(error.localizedDescription, privacy: .public)"); return .defaults }
    }

    func save(_ settings: GameSettings) {
        do { defaults.set(try JSONEncoder().encode(settings), forKey: key) }
        catch { AppLog.persistence.error("Could not encode settings: \(error.localizedDescription, privacy: .public)") }
    }
}
