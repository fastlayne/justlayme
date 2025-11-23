import Foundation
import SwiftData
import Combine

// MARK: - Config Repository Protocol
/// Protocol defining configuration and settings data operations

protocol ConfigRepositoryProtocol {
    // User
    func getCurrentUser() -> AnyPublisher<User?, Error>
    func saveUser(_ user: User) -> AnyPublisher<User, Error>
    func clearUser() -> AnyPublisher<Void, Error>

    // User Preferences
    func getPreferences(userId: String) -> AnyPublisher<UserPreferencesEntity?, Error>
    func savePreferences(_ preferences: UserPreferencesEntity) -> AnyPublisher<Void, Error>

    // Characters
    func getCharacters(userId: String) -> AnyPublisher<[Character], Error>
    func saveCharacter(_ character: Character) -> AnyPublisher<Character, Error>
    func deleteCharacter(id: String) -> AnyPublisher<Void, Error>

    // Model Info Cache
    func getCachedModels() -> AnyPublisher<[ModelInfo], Error>
    func cacheModels(_ models: [ModelInfo]) -> AnyPublisher<Void, Error>
    func clearModelCache() -> AnyPublisher<Void, Error>

    // Tags
    func getTags(userId: String) -> AnyPublisher<[ConversationTag], Error>
    func saveTag(_ tag: ConversationTag) -> AnyPublisher<ConversationTag, Error>
    func deleteTag(id: String) -> AnyPublisher<Void, Error>
}

// MARK: - Config Repository
/// Repository for managing app configuration, user settings, and cached data

@MainActor
final class ConfigRepository: ConfigRepositoryProtocol, ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var currentUser: User?
    @Published private(set) var preferences: UserPreferencesEntity?
    @Published private(set) var characters: [Character] = []
    @Published private(set) var models: [ModelInfo] = []
    @Published private(set) var tags: [ConversationTag] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    // MARK: - Private Properties

    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers

    var currentUserPublisher: AnyPublisher<User?, Never> {
        $currentUser.eraseToAnyPublisher()
    }

    var preferencesPublisher: AnyPublisher<UserPreferencesEntity?, Never> {
        $preferences.eraseToAnyPublisher()
    }

    var charactersPublisher: AnyPublisher<[Character], Never> {
        $characters.eraseToAnyPublisher()
    }

    var modelsPublisher: AnyPublisher<[ModelInfo], Never> {
        $models.eraseToAnyPublisher()
    }

    var tagsPublisher: AnyPublisher<[ConversationTag], Never> {
        $tags.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(modelContext: ModelContext = DataContainer.shared.mainContext) {
        self.modelContext = modelContext
        loadCachedUser()
    }

    // MARK: - User Operations

    private func loadCachedUser() {
        Task {
            do {
                var descriptor = FetchDescriptor<UserEntity>()
                descriptor.fetchLimit = 1
                descriptor.sortBy = [SortDescriptor(\.lastLogin, order: .reverse)]

                if let entity = try modelContext.fetch(descriptor).first {
                    currentUser = entity.toModel()
                }
            } catch {
                print("Error loading cached user: \(error)")
            }
        }
    }

    func getCurrentUser() -> AnyPublisher<User?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    var descriptor = FetchDescriptor<UserEntity>()
                    descriptor.fetchLimit = 1
                    descriptor.sortBy = [SortDescriptor(\.lastLogin, order: .reverse)]

                    let entity = try self.modelContext.fetch(descriptor).first
                    let user = entity?.toModel()

                    self.currentUser = user

                    promise(.success(user))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func saveUser(_ user: User) -> AnyPublisher<User, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    // Check if user already exists
                    let userId = user.id
                    let predicate = #Predicate<UserEntity> { $0.id == userId }
                    var descriptor = FetchDescriptor<UserEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    if let existing = try self.modelContext.fetch(descriptor).first {
                        // Update existing
                        existing.email = user.email
                        existing.name = user.name
                        existing.googleId = user.googleId
                        existing.subscriptionStatus = user.subscriptionStatus.rawValue
                        existing.subscriptionEnd = user.subscriptionEnd
                        existing.messageCount = user.messageCount
                        existing.emailVerified = user.emailVerified
                        existing.lastLogin = user.lastLogin ?? Date()
                        existing.lastSyncedAt = Date()
                    } else {
                        // Create new
                        let entity = UserEntity(from: user)
                        self.modelContext.insert(entity)
                    }

                    try self.modelContext.save()

                    self.currentUser = user

                    promise(.success(user))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func clearUser() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    try self.modelContext.delete(model: UserEntity.self)
                    try self.modelContext.save()

                    self.currentUser = nil

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Preferences Operations

    func getPreferences(userId: String) -> AnyPublisher<UserPreferencesEntity?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<UserPreferencesEntity> { $0.userId == userId }
                    var descriptor = FetchDescriptor<UserPreferencesEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    let prefs = try self.modelContext.fetch(descriptor).first

                    self.preferences = prefs

                    promise(.success(prefs))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func savePreferences(_ preferences: UserPreferencesEntity) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    // Check if preferences exist
                    let userId = preferences.userId
                    let predicate = #Predicate<UserPreferencesEntity> { $0.userId == userId }
                    var descriptor = FetchDescriptor<UserPreferencesEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    if try self.modelContext.fetch(descriptor).first == nil {
                        self.modelContext.insert(preferences)
                    }

                    preferences.updatedAt = Date()
                    try self.modelContext.save()

                    self.preferences = preferences

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Character Operations

    func getCharacters(userId: String) -> AnyPublisher<[Character], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    self.isLoading = true

                    let descriptor = CharacterEntity.fetchDescriptor(userId: userId)
                    let entities = try self.modelContext.fetch(descriptor)
                    let characters = entities.map { $0.toModel() }

                    self.characters = characters
                    self.isLoading = false

                    promise(.success(characters))
                } catch {
                    self.error = error
                    self.isLoading = false
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func saveCharacter(_ character: Character) -> AnyPublisher<Character, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    // Check if character exists
                    let characterId = character.id
                    let predicate = #Predicate<CharacterEntity> { $0.id == characterId }
                    var descriptor = FetchDescriptor<CharacterEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    if let existing = try self.modelContext.fetch(descriptor).first {
                        // Update existing
                        existing.name = character.name
                        existing.backstory = character.backstory
                        existing.setPersonalityTraits(character.personalityTraits)
                        existing.setSpeechPatterns(character.speechPatterns)
                        existing.avatarUrl = character.avatarUrl
                        existing.isPublic = character.isPublic
                        existing.updatedAt = Date()
                        existing.needsSync = true
                    } else {
                        // Create new
                        let entity = CharacterEntity(from: character)
                        entity.needsSync = true
                        self.modelContext.insert(entity)
                    }

                    try self.modelContext.save()

                    // Update local cache
                    if let index = self.characters.firstIndex(where: { $0.id == character.id }) {
                        self.characters[index] = character
                    } else {
                        self.characters.insert(character, at: 0)
                    }

                    promise(.success(character))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteCharacter(id: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<CharacterEntity> { $0.id == id }
                    var descriptor = FetchDescriptor<CharacterEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    guard let entity = try self.modelContext.fetch(descriptor).first else {
                        throw RepositoryError.notFound
                    }

                    self.modelContext.delete(entity)
                    try self.modelContext.save()

                    // Update local cache
                    self.characters.removeAll { $0.id == id }

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Model Cache Operations

    func getCachedModels() -> AnyPublisher<[ModelInfo], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let descriptor = CachedModelInfo.validCacheDescriptor()
                    let entities = try self.modelContext.fetch(descriptor)
                    let models = entities.map { $0.toModel() }

                    self.models = models

                    promise(.success(models))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func cacheModels(_ models: [ModelInfo]) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    // Clear existing cache
                    try self.modelContext.delete(model: CachedModelInfo.self)

                    // Insert new cache entries
                    for model in models {
                        let entity = CachedModelInfo(from: model)
                        self.modelContext.insert(entity)
                    }

                    try self.modelContext.save()

                    self.models = models

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func clearModelCache() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    try self.modelContext.delete(model: CachedModelInfo.self)
                    try self.modelContext.save()

                    self.models = []

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Tag Operations

    func getTags(userId: String) -> AnyPublisher<[ConversationTag], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let descriptor = ConversationTagEntity.fetchDescriptor(userId: userId)
                    let entities = try self.modelContext.fetch(descriptor)
                    let tags = entities.map { $0.toModel() }

                    self.tags = tags

                    promise(.success(tags))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func saveTag(_ tag: ConversationTag) -> AnyPublisher<ConversationTag, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let entity = ConversationTagEntity(from: tag)
                    self.modelContext.insert(entity)
                    try self.modelContext.save()

                    // Update local cache
                    self.tags.append(tag)

                    promise(.success(tag))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteTag(id: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<ConversationTagEntity> { $0.id == id }
                    var descriptor = FetchDescriptor<ConversationTagEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    guard let entity = try self.modelContext.fetch(descriptor).first else {
                        throw RepositoryError.notFound
                    }

                    self.modelContext.delete(entity)
                    try self.modelContext.save()

                    // Update local cache
                    self.tags.removeAll { $0.id == id }

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
