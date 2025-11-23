import Foundation
// Note: Uncomment Firebase imports after adding Firebase SDK
// import FirebaseCore
// import FirebaseCrashlytics

// MARK: - Crashlytics Service

/// Service for crash reporting and analytics using Firebase Crashlytics
///
/// Setup Instructions:
/// 1. Add Firebase SDK via SPM: https://github.com/firebase/firebase-ios-sdk
/// 2. Download GoogleService-Info.plist from Firebase Console
/// 3. Add to project (ensure in build target)
/// 4. Initialize in JustLayMeApp.swift
final class CrashlyticsService {
    // MARK: - Singleton

    static let shared = CrashlyticsService()

    // MARK: - Properties

    private var isInitialized = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Setup

    /// Initialize Crashlytics - call this in app delegate or @main
    func initialize() {
        #if !DEBUG
        // Only enable Crashlytics in release builds
        // Uncomment after adding Firebase:
        // FirebaseApp.configure()
        // Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        isInitialized = true
        print("✅ Crashlytics initialized")
        #else
        print("⚠️ Crashlytics disabled in DEBUG mode")
        #endif
    }

    // MARK: - User Identification

    /// Set user identifier for crash reports
    func setUserId(_ userId: String?) {
        guard isInitialized else { return }
        // Uncomment after adding Firebase:
        // Crashlytics.crashlytics().setUserID(userId ?? "anonymous")
    }

    /// Set custom user attributes
    func setUserAttribute(key: String, value: String) {
        guard isInitialized else { return }
        // Uncomment after adding Firebase:
        // Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    // MARK: - Logging

    /// Log a message to Crashlytics
    func log(_ message: String) {
        guard isInitialized else { return }
        // Uncomment after adding Firebase:
        // Crashlytics.crashlytics().log(message)
        print("📝 Crashlytics log: \(message)")
    }

    /// Log a non-fatal error
    func logError(_ error: Error, userInfo: [String: Any]? = nil) {
        guard isInitialized else { return }

        var info = userInfo ?? [:]
        info["error_description"] = error.localizedDescription

        // Uncomment after adding Firebase:
        // Crashlytics.crashlytics().record(error: error, userInfo: info)
        print("❌ Crashlytics error: \(error.localizedDescription)")
    }

    /// Log a non-fatal exception with custom message
    func logException(
        name: String,
        reason: String,
        userInfo: [String: Any]? = nil
    ) {
        guard isInitialized else { return }

        // Uncomment after adding Firebase:
        // let exception = ExceptionModel(name: name, reason: reason)
        // Crashlytics.crashlytics().record(exceptionModel: exception)
        print("⚠️ Crashlytics exception: \(name) - \(reason)")
    }

    // MARK: - Breadcrumbs

    /// Log navigation event for crash context
    func logNavigation(from: String, to: String) {
        log("Navigation: \(from) → \(to)")
    }

    /// Log user action for crash context
    func logAction(_ action: String, screen: String) {
        log("Action: \(action) on \(screen)")
    }

    /// Log API request for crash context
    func logAPIRequest(endpoint: String, method: String) {
        log("API: \(method) \(endpoint)")
    }

    // MARK: - Custom Keys

    /// Set custom key-value pair for crash reports
    func setCustomKey(_ key: CrashlyticsKey, value: Any) {
        guard isInitialized else { return }
        // Uncomment after adding Firebase:
        // Crashlytics.crashlytics().setCustomValue(value, forKey: key.rawValue)
    }

    // MARK: - Force Crash (Testing Only)

    /// Force a crash for testing - NEVER use in production!
    func testCrash() {
        #if DEBUG
        // Uncomment after adding Firebase:
        // fatalError("Test crash for Crashlytics")
        print("🧪 Test crash would be triggered here")
        #endif
    }
}

// MARK: - Crashlytics Keys

enum CrashlyticsKey: String {
    // User Info
    case userId = "user_id"
    case userEmail = "user_email"
    case subscriptionStatus = "subscription_status"

    // Session Info
    case sessionId = "session_id"
    case characterId = "character_id"
    case modelId = "model_id"

    // App State
    case currentScreen = "current_screen"
    case lastAction = "last_action"
    case messageCount = "message_count"

    // Device Info
    case freeMemory = "free_memory"
    case batteryLevel = "battery_level"
    case networkType = "network_type"
}

// MARK: - Crashlytics Error Types

enum CrashlyticsError: Error, LocalizedError {
    case networkError(String)
    case apiError(Int, String)
    case authError(String)
    case parseError(String)
    case storeKitError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .apiError(let code, let message):
            return "API Error \(code): \(message)"
        case .authError(let message):
            return "Auth Error: \(message)"
        case .parseError(let message):
            return "Parse Error: \(message)"
        case .storeKitError(let message):
            return "StoreKit Error: \(message)"
        case .unknown(let message):
            return "Unknown Error: \(message)"
        }
    }
}

// MARK: - Usage Examples

/*

 // 1. Initialize in JustLayMeApp.swift

 @main
 struct JustLayMeApp: App {
     init() {
         CrashlyticsService.shared.initialize()
     }
     // ...
 }

 // 2. Set user after login

 func onUserLogin(user: User) {
     CrashlyticsService.shared.setUserId(String(user.id))
     CrashlyticsService.shared.setCustomKey(.userEmail, value: user.email)
     CrashlyticsService.shared.setCustomKey(.subscriptionStatus, value: user.subscriptionStatus.rawValue)
 }

 // 3. Log errors in API calls

 func sendMessage(_ message: String) async {
     CrashlyticsService.shared.logAPIRequest(endpoint: "/api/chat", method: "POST")

     do {
         let response = try await api.sendMessage(message)
         CrashlyticsService.shared.log("Message sent successfully")
     } catch {
         CrashlyticsService.shared.logError(error, userInfo: [
             "message_length": message.count,
             "character_id": currentCharacterId
         ])
     }
 }

 // 4. Log navigation

 func navigate(to screen: String) {
     CrashlyticsService.shared.logNavigation(from: currentScreen, to: screen)
     CrashlyticsService.shared.setCustomKey(.currentScreen, value: screen)
 }

 */
