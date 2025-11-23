// PersistenceController.swift
// JustLayMe iOS - CoreData Persistence
// Local storage for conversations and settings

import Foundation
import CoreData
import Combine

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    private var cancellables = Set<AnyCancellable>()

    // Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // Add sample data for previews
        controller.addSampleData()
        return controller
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "JustLayMe")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                print("CoreData failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Context

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    // MARK: - Save

    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Conversations

    func saveConversation(_ conversation: Conversation) {
        let context = viewContext

        // Check if conversation exists
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id)

        do {
            let results = try context.fetch(fetchRequest)
            let entity: ConversationEntity

            if let existing = results.first {
                entity = existing
            } else {
                entity = ConversationEntity(context: context)
                entity.id = conversation.id
                entity.createdAt = conversation.createdAt
            }

            entity.modelType = conversation.modelType.rawValue
            entity.title = conversation.title
            entity.updatedAt = conversation.updatedAt
            entity.isArchived = conversation.isArchived
            entity.tags = conversation.tags.joined(separator: ",")

            // Save messages
            for message in conversation.messages {
                saveMessage(message, for: entity)
            }

            save()
        } catch {
            print("Failed to save conversation: \(error.localizedDescription)")
        }
    }

    func saveMessage(_ message: ChatMessage, for conversation: ConversationEntity) {
        let context = viewContext

        // Check if message exists
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)

        do {
            let results = try context.fetch(fetchRequest)
            let entity: MessageEntity

            if let existing = results.first {
                entity = existing
            } else {
                entity = MessageEntity(context: context)
                entity.id = message.id
                entity.conversation = conversation
            }

            entity.content = message.content
            entity.isUser = message.isUser
            entity.timestamp = message.timestamp
            entity.modelType = message.modelType

        } catch {
            print("Failed to save message: \(error.localizedDescription)")
        }
    }

    func fetchConversations(archived: Bool = false) -> [Conversation] {
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: archived))
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationEntity.updatedAt, ascending: false)]

        do {
            let entities = try viewContext.fetch(fetchRequest)
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let modelTypeString = entity.modelType,
                      let modelType = AIModel(rawValue: modelTypeString),
                      let createdAt = entity.createdAt,
                      let updatedAt = entity.updatedAt else {
                    return nil
                }

                let messages = fetchMessages(for: id)
                let tags = (entity.tags ?? "").split(separator: ",").map(String.init)

                return Conversation(
                    id: id,
                    modelType: modelType,
                    title: entity.title,
                    messages: messages,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    isArchived: entity.isArchived,
                    tags: tags
                )
            }
        } catch {
            print("Failed to fetch conversations: \(error.localizedDescription)")
            return []
        }
    }

    func fetchMessages(for conversationId: String) -> [ChatMessage] {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "conversation.id == %@", conversationId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.timestamp, ascending: true)]

        do {
            let entities = try viewContext.fetch(fetchRequest)
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let content = entity.content,
                      let timestamp = entity.timestamp else {
                    return nil
                }

                return ChatMessage(
                    id: id,
                    content: content,
                    isUser: entity.isUser,
                    timestamp: timestamp,
                    modelType: entity.modelType,
                    isStreaming: false
                )
            }
        } catch {
            print("Failed to fetch messages: \(error.localizedDescription)")
            return []
        }
    }

    func deleteConversation(_ conversation: Conversation) {
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            for entity in results {
                viewContext.delete(entity)
            }
            save()
        } catch {
            print("Failed to delete conversation: \(error.localizedDescription)")
        }
    }

    func deleteAllConversations() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ConversationEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try viewContext.execute(deleteRequest)
            save()
        } catch {
            print("Failed to delete all conversations: \(error.localizedDescription)")
        }
    }

    func searchConversations(query: String) -> [Conversation] {
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR ANY messages.content CONTAINS[cd] %@",
            query, query
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationEntity.updatedAt, ascending: false)]

        do {
            let entities = try viewContext.fetch(fetchRequest)
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let modelTypeString = entity.modelType,
                      let modelType = AIModel(rawValue: modelTypeString),
                      let createdAt = entity.createdAt,
                      let updatedAt = entity.updatedAt else {
                    return nil
                }

                let messages = fetchMessages(for: id)
                let tags = (entity.tags ?? "").split(separator: ",").map(String.init)

                return Conversation(
                    id: id,
                    modelType: modelType,
                    title: entity.title,
                    messages: messages,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    isArchived: entity.isArchived,
                    tags: tags
                )
            }
        } catch {
            print("Failed to search conversations: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Settings

    func saveSettings(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: "appSettings")
        } catch {
            print("Failed to save settings: \(error.localizedDescription)")
        }
    }

    func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "appSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    // MARK: - Sample Data

    private func addSampleData() {
        var conversation1 = Conversation(
            modelType: .laymeV1,
            title: "Welcome Chat"
        )
        conversation1.addMessage(ChatMessage(
            content: "Hello! How are you today?",
            isUser: true
        ))
        conversation1.addMessage(ChatMessage(
            content: "Hi! I'm Layme V1, completely free with unlimited messages! I'm here to chat about absolutely anything with no restrictions or limits. What would you like to talk about?",
            isUser: false
        ))

        var conversation2 = Conversation(
            modelType: .roleplay,
            title: "Roleplay Session"
        )
        conversation2.addMessage(ChatMessage(
            content: "Can you roleplay as a detective?",
            isUser: true
        ))
        conversation2.addMessage(ChatMessage(
            content: "Ah, you've come to the right place. *adjusts fedora* The name's Detective Noir. I've seen things in this city that would make your hair stand on end. What case brings you to my office today?",
            isUser: false
        ))

        saveConversation(conversation1)
        saveConversation(conversation2)
    }
}

// MARK: - CoreData Model Classes

// These would normally be generated by CoreData, but we define them manually for reference

@objc(ConversationEntity)
public class ConversationEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var modelType: String?
    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var isArchived: Bool
    @NSManaged public var tags: String?
    @NSManaged public var messages: NSSet?
}

extension ConversationEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConversationEntity> {
        return NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
    }
}

@objc(MessageEntity)
public class MessageEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var content: String?
    @NSManaged public var isUser: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var modelType: String?
    @NSManaged public var conversation: ConversationEntity?
}

extension MessageEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageEntity> {
        return NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
    }
}
