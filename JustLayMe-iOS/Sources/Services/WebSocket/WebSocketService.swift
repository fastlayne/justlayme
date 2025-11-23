import Foundation
import Starscream
import Combine

// MARK: - WebSocket Service
final class WebSocketService: ObservableObject, WebSocketDelegate {
    static let shared = WebSocketService()

    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected

    private var socket: WebSocket?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    private let messageSubject = PassthroughSubject<WebSocketMessage, Never>()
    var messagePublisher: AnyPublisher<WebSocketMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
    }

    private init() {}

    // MARK: - Connection Management
    func connect() {
        guard socket == nil || !isConnected else { return }

        connectionState = .connecting

        var request = URLRequest(url: URL(string: AppConfig.websocketURL)!)
        request.timeoutInterval = 10

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0

        socket?.disconnect()
        socket = nil

        isConnected = false
        connectionState = .disconnected
    }

    // MARK: - Send Messages
    func send(_ message: WebSocketMessage) {
        guard isConnected, let socket = socket else {
            print("WebSocket: Cannot send - not connected")
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            socket.write(data: data)
        } catch {
            print("WebSocket: Failed to encode message - \(error)")
        }
    }

    func sendRaw(_ text: String) {
        guard isConnected, let socket = socket else { return }
        socket.write(string: text)
    }

    // MARK: - WebSocketDelegate
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            isConnected = true
            connectionState = .connected
            reconnectAttempts = 0
            print("WebSocket: Connected")

        case .disconnected(let reason, let code):
            isConnected = false
            connectionState = .disconnected
            print("WebSocket: Disconnected - \(reason) (code: \(code))")
            scheduleReconnect()

        case .text(let text):
            handleMessage(text)

        case .binary(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleMessage(text)
            }

        case .pong:
            break

        case .ping:
            socket?.write(pong: Data())

        case .error(let error):
            print("WebSocket: Error - \(String(describing: error))")
            isConnected = false
            scheduleReconnect()

        case .viabilityChanged(let viable):
            if !viable {
                scheduleReconnect()
            }

        case .reconnectSuggested(let suggested):
            if suggested {
                scheduleReconnect()
            }

        case .cancelled:
            isConnected = false
            connectionState = .disconnected

        case .peerClosed:
            isConnected = false
            connectionState = .disconnected
            scheduleReconnect()
        }
    }

    // MARK: - Message Handling
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            let message = try JSONDecoder().decode(WebSocketMessage.self, from: data)
            DispatchQueue.main.async {
                self.messageSubject.send(message)
            }
        } catch {
            print("WebSocket: Failed to decode message - \(error)")
        }
    }

    // MARK: - Reconnection
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .disconnected
            return
        }

        connectionState = .reconnecting
        reconnectAttempts += 1

        let delay = pow(2.0, Double(reconnectAttempts)) // Exponential backoff
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
}

// MARK: - WebSocket Message Types
struct WebSocketMessage: Codable {
    let type: String
    let sessionId: String?
    let message: String?
    let isUser: Bool?
    let timestamp: Date?
    let userId: String?
    let characterId: String?
    let sessions: [String: SessionData]?
    let password: String?

    enum CodingKeys: String, CodingKey {
        case type, sessionId, message, isUser, timestamp, userId, characterId, sessions, password
    }
}

struct SessionData: Codable {
    let userId: String?
    let characterId: String?
    let messages: [SessionMessage]?
    let lastActivity: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case characterId = "character_id"
        case messages
        case lastActivity = "last_activity"
    }
}

struct SessionMessage: Codable {
    let content: String
    let isUser: Bool
    let timestamp: Date?
}

// MARK: - Outgoing Message Types
extension WebSocketMessage {
    static func adminAuth(password: String) -> WebSocketMessage {
        WebSocketMessage(
            type: "ADMIN_AUTH",
            sessionId: nil,
            message: nil,
            isUser: nil,
            timestamp: nil,
            userId: nil,
            characterId: nil,
            sessions: nil,
            password: password
        )
    }

    static var getSessions: WebSocketMessage {
        WebSocketMessage(
            type: "GET_SESSIONS",
            sessionId: nil,
            message: nil,
            isUser: nil,
            timestamp: nil,
            userId: nil,
            characterId: nil,
            sessions: nil,
            password: nil
        )
    }
}
