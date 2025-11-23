# Firebase Crashlytics Setup Guide

## Complete Integration for JustLayMe

---

## 1. Firebase Project Setup

### Create Firebase Project

1. Go to https://console.firebase.google.com
2. Click "Create a project"
3. Name: "JustLayMe"
4. Enable Google Analytics (recommended)
5. Select or create Analytics account

### Add iOS App

1. Click iOS icon to add app
2. Bundle ID: `com.justlayme.app`
3. App nickname: "JustLayMe iOS"
4. App Store ID: (leave blank for now)
5. Click "Register app"

### Download Configuration

1. Download `GoogleService-Info.plist`
2. Add to Xcode project root
3. Ensure "Copy items if needed" is checked
4. Ensure target membership is checked

---

## 2. Add Firebase SDK

### Option A: Swift Package Manager (Recommended)

1. In Xcode: File → Add Package Dependencies
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Version: Up to Next Major (10.0.0)
4. Select packages:
   - FirebaseAnalytics
   - FirebaseCrashlytics

### Option B: Update Package.swift

```swift
dependencies: [
    // ... existing dependencies
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
],
targets: [
    .target(
        name: "JustLayMe",
        dependencies: [
            // ... existing dependencies
            .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
        ]
    )
]
```

---

## 3. Configure Build Settings

### Add Run Script Phase

1. Select target in Xcode
2. Build Phases → "+" → New Run Script Phase
3. Name: "Firebase Crashlytics"
4. Shell: `/bin/sh`
5. Script:

```bash
# Type a script or drag a script file from your workspace to insert its path.
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

6. Input Files:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

### Enable dSYM Upload

1. Build Settings → Debug Information Format
2. Set to: `DWARF with dSYM File` (for Release)

---

## 4. Initialize in App

### Update JustLayMeApp.swift

```swift
import SwiftUI
import FirebaseCore
import FirebaseCrashlytics

@main
struct JustLayMeApp: App {

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Configure Crashlytics
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

---

## 5. Update CrashlyticsService

Uncomment Firebase imports and calls in `Services/Crashlytics/CrashlyticsService.swift`:

```swift
import Foundation
import FirebaseCore
import FirebaseCrashlytics

final class CrashlyticsService {
    static let shared = CrashlyticsService()

    private var isInitialized = false

    private init() {}

    func initialize() {
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        isInitialized = true
        #endif
    }

    func setUserId(_ userId: String?) {
        guard isInitialized else { return }
        Crashlytics.crashlytics().setUserID(userId ?? "anonymous")
    }

    func log(_ message: String) {
        guard isInitialized else { return }
        Crashlytics.crashlytics().log(message)
    }

    func logError(_ error: Error, userInfo: [String: Any]? = nil) {
        guard isInitialized else { return }
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
    }

    func setCustomKey(_ key: CrashlyticsKey, value: Any) {
        guard isInitialized else { return }
        Crashlytics.crashlytics().setCustomValue(value, forKey: key.rawValue)
    }
}
```

---

## 6. Usage Throughout App

### In AuthViewModel

```swift
func login(email: String, password: String) async throws -> User {
    CrashlyticsService.shared.log("Login attempt")

    do {
        let user = try await authService.login(email: email, password: password)

        // Set user context for crash reports
        CrashlyticsService.shared.setUserId(String(user.id))
        CrashlyticsService.shared.setUserAttribute(key: "email", value: user.email)
        CrashlyticsService.shared.setCustomKey(.subscriptionStatus, value: user.subscriptionStatus.rawValue)

        CrashlyticsService.shared.log("Login successful")
        return user
    } catch {
        CrashlyticsService.shared.logError(error, userInfo: [
            "email_provided": !email.isEmpty
        ])
        throw error
    }
}
```

### In ChatViewModel

```swift
func sendMessage() async {
    let messageLength = inputText.count

    CrashlyticsService.shared.logAPIRequest(endpoint: "/api/chat", method: "POST")
    CrashlyticsService.shared.setCustomKey(.characterId, value: selectedCharacter?.id ?? "unknown")

    do {
        let response = try await apiService.sendMessage(request)
        CrashlyticsService.shared.log("Message sent: \(messageLength) chars")
    } catch {
        CrashlyticsService.shared.logError(error, userInfo: [
            "message_length": messageLength,
            "character_id": selectedCharacter?.id ?? 0
        ])
    }
}
```

### In Navigation/Coordinator

```swift
func navigate(to destination: AppDestination) {
    let fromScreen = currentScreen
    let toScreen = String(describing: destination)

    CrashlyticsService.shared.logNavigation(from: fromScreen, to: toScreen)
    CrashlyticsService.shared.setCustomKey(.currentScreen, value: toScreen)

    // Perform navigation
    navigationPath.append(destination)
}
```

---

## 7. Testing Crashlytics

### Force a Test Crash

```swift
// Add a button in debug builds only
#if DEBUG
Button("Test Crash") {
    fatalError("Test crash for Crashlytics")
}
#endif
```

### Verify Setup

1. Build and run app
2. Trigger test crash
3. Relaunch app (sends crash report)
4. Check Firebase Console → Crashlytics
5. Crash should appear within minutes

---

## 8. Dashboard Usage

### Firebase Console Features

**Crashes Tab**:
- View crash-free users percentage
- See crash trends over time
- Prioritize by impact

**Issues Tab**:
- Group similar crashes
- See affected versions/devices
- Stack traces and logs

**Custom Keys**:
- Filter by user attributes
- Find patterns in crashes

---

## 9. Best Practices

### What to Log

✅ DO:
- User actions (login, logout, purchase)
- API calls (endpoint, success/failure)
- Navigation events
- Error states
- Key user attributes

❌ DON'T:
- Sensitive data (passwords, tokens)
- Personal messages content
- Payment details
- Excessive logs (performance impact)

### Performance Tips

1. Don't log in tight loops
2. Use async logging for non-critical events
3. Disable in DEBUG builds
4. Keep custom keys under 64

---

## 10. Privacy Compliance

### GDPR/CCPA

Add to Privacy Policy:
```
We use Firebase Crashlytics to collect crash reports and diagnostic data.
This helps us identify and fix issues in the app. This data is anonymized
and not linked to your personal information unless you are logged in.
```

### User Consent

```swift
// If requiring explicit consent:
func enableCrashReporting(enabled: Bool) {
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    UserDefaults.standard.set(enabled, forKey: "crashlyticsEnabled")
}
```

---

## 11. Checklist

### Setup
- [ ] Firebase project created
- [ ] iOS app registered
- [ ] GoogleService-Info.plist added
- [ ] Firebase SDK added
- [ ] Run script phase added
- [ ] dSYM upload configured

### Code
- [ ] Firebase initialized in app
- [ ] CrashlyticsService integrated
- [ ] User ID set on login
- [ ] Errors logged appropriately
- [ ] Navigation logged

### Testing
- [ ] Test crash triggered
- [ ] Crash appears in console
- [ ] Logs visible in crash report
- [ ] Custom keys working

### Production
- [ ] Disabled in DEBUG mode
- [ ] Privacy policy updated
- [ ] User consent if required
