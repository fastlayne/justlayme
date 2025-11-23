// MARK: - JustLayMe WebSocket Manager
// Handles real-time WebSocket connections for chat streaming and admin monitoring

import Foundation
import Combine

// MARK: - WebSocket Connection State

public enum WebSocketConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(Error)

    public static func == (lhs: WebSocketConnectionState, rhs: WebSocketConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.reconnecting(let a), .reconnecting(let b)):
            return a == b
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

// MARK: - WebSocket Event

public enum WebSocketEvent {
    case connected
    case disconnected(Error?)
    case message(WebSocketMessage)
    case newSession(ChatSession)
    case newMessage(sessionId: String, message: String, isUser: Bool, timestamp: String)
    case sessionsList([String: ChatSession])
    case authSuccess([ChatSession])
    case error(Error)
}

// MARK: - WebSocket Manager

public final class WebSocketManager: NSObject, ObservableObject {
    public static let shared = WebSocketManager()

    // MARK: - Published Properties

    @Published public private(set) var connectionState: WebSocketConnectionState = .disconnected
    @Published public private(set) var sessions: [String: ChatSession] = [:]

    // MARK: - Private Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var configuration: APIConfiguration
    private var session: URLSession!
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 1.0
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?

    // MARK: - Publishers

    private let eventSubject = PassthroughSubject<WebSocketEvent, Never>()
    public var events: AnyPublisher<WebSocketEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private let messageSubject = PassthroughSubject<WebSocketMessage, Never>()
    public var messages: AnyPublisher<WebSocketMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private override init() {
        self.configuration = .production
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }

    public convenience init(configuration: APIConfiguration) {
        self.init()
        self.configuration = configuration
    }

    public func configure(with configuration: APIConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Connection Management

    public func connect() {
        guard connectionState == .disconnected || connectionState == .failed(APIError.unknown) else {
            return
        }

        connectionState = .connecting
        reconnectAttempts = 0

        let request = URLRequest(url: configuration.webSocketURL)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        receiveMessage()
        startPingTimer()
    }

    public func disconnect() {
        stopPingTimer()
        stopReconnectTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        eventSubject.send(.disconnected(nil))
    }

    // MARK: - Admin Authentication

    public func authenticateAdmin(password: String) {
        let authMessage: [String: Any] = [
            "type": "ADMIN_AUTH",
            "password": password
        ]
        send(json: authMessage)
    }

    // MARK: - Request Sessions

    public func requestSessions() {
        let message: [String: String] = ["type": "GET_SESSIONS"]
        send(json: message)
    }

    // MARK: - Send Message

    public func send(text: String) {
        guard connectionState == .connected else { return }

        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                self?.eventSubject.send(.error(error))
            }
        }
    }

    public func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        send(text: text)
    }

    public func send<T: Encodable>(_ message: T) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        send(text: text)
    }

    // MARK: - Message Reception

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage() // Continue receiving

            case .failure(let error):
                self.handleError(error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(WebSocketMessage.self, from: data)

            messageSubject.send(message)
            eventSubject.send(.message(message))

            // Handle specific message types
            switch message.type {
            case .authSuccess:
                if let sessions = message.sessions {
                    eventSubject.send(.authSuccess(sessions))
                    for session in sessions {
                        self.sessions[session.id] = session
                    }
                }

            case .sessionsList:
                // Parse sessions dictionary
                if let jsonData = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let sessionsDict = json["sessions"] as? [String: [String: Any]] {
                    var parsedSessions: [String: ChatSession] = [:]
                    for (key, value) in sessionsDict {
                        if let sessionData = try? JSONSerialization.data(withJSONObject: value),
                           let session = try? decoder.decode(ChatSession.self, from: sessionData) {
                            parsedSessions[key] = session
                        }
                    }
                    self.sessions = parsedSessions
                    eventSubject.send(.sessionsList(parsedSessions))
                }

            case .newSession:
                if let sessionId = message.sessionId,
                   let userId = message.userId,
                   let characterId = message.characterId,
                   let timestamp = message.timestamp {
                    let session = ChatSession(
                        id: sessionId,
                        userId: userId,
                        characterId: characterId,
                        messages: [],
                        startTime: timestamp,
                        lastActivity: timestamp
                    )
                    sessions[sessionId] = session
                    eventSubject.send(.newSession(session))
                }

            case .newMessage:
                if let sessionId = message.sessionId,
                   let messageText = message.message,
                   let isUser = message.isUser,
                   let timestamp = message.timestamp {
                    eventSubject.send(.newMessage(
                        sessionId: sessionId,
                        message: messageText,
                        isUser: isUser,
                        timestamp: timestamp
                    ))

                    // Update session messages
                    if var session = sessions[sessionId] {
                        let sessionMessage = SessionMessage(
                            content: messageText,
                            isUser: isUser,
                            timestamp: timestamp
                        )
                        var messages = session.messages ?? []
                        messages.append(sessionMessage)
                        // Recreate session with updated messages
                        sessions[sessionId] = ChatSession(
                            id: session.id,
                            userId: session.userId,
                            characterId: session.characterId,
                            messages: messages,
                            startTime: session.startTime,
                            lastActivity: timestamp
                        )
                    }
                }

            default:
                break
            }

        } catch {
            eventSubject.send(.error(error))
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        eventSubject.send(.error(error))

        if shouldReconnect() {
            attemptReconnect()
        } else {
            connectionState = .failed(error)
            eventSubject.send(.disconnected(error))
        }
    }

    // MARK: - Reconnection Logic

    private func shouldReconnect() -> Bool {
        return reconnectAttempts < maxReconnectAttempts
    }

    private func attemptReconnect() {
        reconnectAttempts += 1
        connectionState = .reconnecting(attempt: reconnectAttempts)

        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1))

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.webSocketTask = nil
            self?.connect()
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Keep Alive (Ping)

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.ping()
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func ping() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                self?.handleError(error)
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketManager: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.connectionState = .connected
            self.reconnectAttempts = 0
            self.eventSubject.send(.connected)
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.eventSubject.send(.disconnected(nil))

            if closeCode != .goingAway && self.shouldReconnect() {
                self.attemptReconnect()
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.handleError(error)
            }
        }
    }
}

// MARK: - Combine Extensions

extension WebSocketManager {
    /// Publisher for new chat messages in specific sessions
    public func messagesPublisher(for sessionId: String) -> AnyPublisher<SessionMessage, Never> {
        events
            .compactMap { event -> SessionMessage? in
                if case .newMessage(let id, let message, let isUser, let timestamp) = event,
                   id == sessionId {
                    return SessionMessage(content: message, isUser: isUser, timestamp: timestamp)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }

    /// Publisher for connection state changes
    public var connectionStatePublisher: AnyPublisher<WebSocketConnectionState, Never> {
        $connectionState.eraseToAnyPublisher()
    }

    /// Publisher for all active sessions
    public var sessionsPublisher: AnyPublisher<[String: ChatSession], Never> {
        $sessions.eraseToAnyPublisher()
    }
}

// MARK: - Async/Await Extensions

@available(iOS 15.0, macOS 12.0, *)
extension WebSocketManager {
    /// Async stream of WebSocket events
    public var eventStream: AsyncStream<WebSocketEvent> {
        AsyncStream { continuation in
            let cancellable = events.sink { event in
                continuation.yield(event)
            }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    /// Async stream of messages for a specific session
    public func messageStream(for sessionId: String) -> AsyncStream<SessionMessage> {
        AsyncStream { continuation in
            let cancellable = messagesPublisher(for: sessionId).sink { message in
                continuation.yield(message)
            }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    /// Wait for connection to be established
    public func waitForConnection() async throws {
        if connectionState == .connected { return }

        connect()

        for await event in eventStream {
            switch event {
            case .connected:
                return
            case .disconnected(let error):
                if let error = error {
                    throw error
                }
                throw APIError.networkError(URLError(.networkConnectionLost))
            case .error(let error):
                throw error
            default:
                continue
            }
        }
    }
}
