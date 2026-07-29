import Combine

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: GameSettings { didSet { repository.save(settings) } }
    private let repository: any SettingsRepository
    init(repository: any SettingsRepository) {
        self.repository = repository
        settings = repository.load()
    }
}
