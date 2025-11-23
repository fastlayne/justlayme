import Foundation
import Combine

// MARK: - WebSocket Message Type

enum WebSocketMessageType: String, Codable {
    case newSession = "NEW_SESSION"
    case newMessage = "NEW_MESSAGE"
    case sessionEnded = "SESSION_ENDED"
    case typingIndicator = "TYPING_INDICATOR"
    case error = "ERROR"
}

// MARK: - WebSocket Message

struct WebSocketMessage: Codable {
    let type: WebSocketMessageType
    let sessionId: String?
    let message: String?
    let isUser: Bool?
    let timestamp: Date?
    let userId: String?
    let characterId: String?

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case message
        case isUser = "is_user"
        case timestamp
        case userId = "user_id"
        case characterId = "character_id"
    }
}

// MARK: - WebSocket State

enum WebSocketState {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - WebSocket Service

final class WebSocketService: NSObject, ObservableObject {
    // MARK: - Singleton

    static let shared = WebSocketService()

    // MARK: - Published Properties

    @Published private(set) var state: WebSocketState = .disconnected
    @Published private(set) var lastMessage: WebSocketMessage?

    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var cancellables = Set<AnyCancellable>()

    private let messageSubject = PassthroughSubject<WebSocketMessage, Never>()
    private let stateSubject = CurrentValueSubject<WebSocketState, Never>(.disconnected)

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: Timer?

    var messagePublisher: AnyPublisher<WebSocketMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    var statePublisher: AnyPublisher<WebSocketState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        setupURLSession()
    }

    // MARK: - Setup

    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // MARK: - Connection

    func connect() {
        guard state != .connected && state != .connecting else { return }

        guard let url = URL(string: AppConfig.webSocketURL) else {
            print("Invalid WebSocket URL")
            return
        }

        updateState(.connecting)

        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()

        receiveMessage()
    }

    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        updateState(.disconnected)
    }

    // MARK: - Sending Messages

    func send(_ message: WebSocketMessage) {
        guard state == .connected else {
            print("WebSocket not connected")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(message)

            guard let jsonString = String(data: data, encoding: .utf8) else { return }

            webSocketTask?.send(.string(jsonString)) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("WebSocket encoding error: \(error)")
        }
    }

    func sendTypingIndicator(sessionId: String, isTyping: Bool) {
        let message = [
            "type": "TYPING_INDICATOR",
            "session_id": sessionId,
            "is_typing": isTyping
        ] as [String: Any]

        sendRaw(message)
    }

    private func sendRaw(_ message: [String: Any]) {
        guard state == .connected else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }

            webSocketTask?.send(.string(jsonString)) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("WebSocket serialization error: \(error)")
        }
    }

    // MARK: - Receiving Messages

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue listening

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleDisconnection()
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
            decoder.dateDecodingStrategy = .iso8601
            let message = try decoder.decode(WebSocketMessage.self, from: data)

            DispatchQueue.main.async { [weak self] in
                self?.lastMessage = message
                self?.messageSubject.send(message)
            }
        } catch {
            print("WebSocket parse error: \(error)")
        }
    }

    // MARK: - Reconnection

    private func handleDisconnection() {
        updateState(.disconnected)

        guard reconnectAttempts < maxReconnectAttempts else {
            print("Max reconnection attempts reached")
            return
        }

        updateState(.reconnecting)
        reconnectAttempts += 1

        let delay = Double(min(reconnectAttempts * 2, 30)) // Exponential backoff, max 30 seconds

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }

    // MARK: - State

    private func updateState(_ newState: WebSocketState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
            self?.stateSubject.send(newState)
        }
    }

    // MARK: - Ping

    private func startPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("WebSocket ping error: \(error)")
                self?.handleDisconnection()
            } else {
                // Schedule next ping
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                    if self?.state == .connected {
                        self?.startPing()
                    }
                }
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        reconnectAttempts = 0
        updateState(.connected)
        startPing()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        handleDisconnection()
    }
}
