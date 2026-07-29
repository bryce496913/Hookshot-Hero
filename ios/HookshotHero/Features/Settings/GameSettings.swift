import Foundation

struct GameSettings: Codable, Equatable, Sendable {
    var reducedMotion: Bool
    var controlHintsEnabled: Bool

    static let defaults = GameSettings(reducedMotion: false, controlHintsEnabled: true)

    init(reducedMotion: Bool = false, controlHintsEnabled: Bool = true) {
        self.reducedMotion = reducedMotion
        self.controlHintsEnabled = controlHintsEnabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        do { reducedMotion = try values.decodeIfPresent(Bool.self, forKey: .reducedMotion) ?? Self.defaults.reducedMotion }
        catch {
            reducedMotion = Self.defaults.reducedMotion
            AppLog.persistence.error("Malformed reduced-motion setting; field default used: \(error.localizedDescription, privacy: .public)")
        }
        do { controlHintsEnabled = try values.decodeIfPresent(Bool.self, forKey: .controlHintsEnabled) ?? Self.defaults.controlHintsEnabled }
        catch {
            controlHintsEnabled = Self.defaults.controlHintsEnabled
            AppLog.persistence.error("Malformed control-hints setting; field default used: \(error.localizedDescription, privacy: .public)")
        }
    }
}

@MainActor
protocol SettingsRepository {
    func load() -> GameSettings
    func save(_ settings: GameSettings)
}

@MainActor
struct UserDefaultsSettingsRepository: SettingsRepository {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "game-settings-v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> GameSettings {
        guard let data = defaults.data(forKey: key) else { return .defaults }
        do { return try JSONDecoder().decode(GameSettings.self, from: data) }
        catch {
            AppLog.persistence.error("Could not decode settings; defaults used: \(error.localizedDescription, privacy: .public)")
            return .defaults
        }
    }

    func save(_ settings: GameSettings) {
        do { defaults.set(try JSONEncoder().encode(settings), forKey: key) }
        catch { AppLog.persistence.error("Could not encode settings: \(error.localizedDescription, privacy: .public)") }
    }
}
