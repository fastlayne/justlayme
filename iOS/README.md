# JustLayMe iOS Test Suite

Comprehensive test suite for the JustLayMe iOS application.

## Test Structure

```
iOS/
├── JustLayMe/
│   └── Sources/
│       ├── Models/          # Data models
│       ├── ViewModels/      # View models
│       ├── Services/        # API client, networking
│       ├── Repositories/    # Data repositories
│       └── Views/           # SwiftUI views
├── JustLayMeTests/
│   ├── Unit/
│   │   ├── ViewModels/      # ViewModel unit tests
│   │   ├── Networking/      # API client tests
│   │   └── Repositories/    # Repository tests
│   ├── Integration/         # Integration tests
│   ├── Performance/         # Performance tests
│   ├── Mocks/              # Mock objects
│   └── Helpers/            # Test utilities
├── JustLayMeUITests/        # UI tests
└── JustLayMeSnapshotTests/  # Snapshot tests
```

## Running Tests

### Using Make

```bash
# Run all tests
make test

# Run specific test suites
make test-unit
make test-integration
make test-ui
make test-performance
make test-snapshot

# Run with coverage
make coverage
make coverage-report
```

### Using Xcode

1. Open `JustLayMe.xcodeproj`
2. Select a simulator
3. Press `Cmd + U` to run all tests
4. Use `Cmd + Ctrl + U` to run tests for the current file

### Using xcodebuild

```bash
xcodebuild test \
  -scheme JustLayMe \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES
```

## Test Categories

### Unit Tests

- **ViewModel Tests**: Test business logic in ViewModels
  - `AuthViewModelTests` - Authentication flows
  - `ChatViewModelTests` - Chat functionality
  - `SubscriptionViewModelTests` - Subscription management
  - `CharacterViewModelTests` - Character CRUD
  - `ProfileViewModelTests` - Profile management
  - `SettingsViewModelTests` - Settings persistence

- **Networking Tests**: Test API client behavior
  - Request building
  - Response parsing
  - Error handling
  - Authentication

- **Repository Tests**: Test data layer
  - CRUD operations
  - Caching
  - State management

### Integration Tests

- Complete user flows
- ViewModel to API integration
- Error recovery scenarios
- Concurrent operations

### UI Tests

- Login/Registration flows
- Chat interactions
- Subscription purchase
- Navigation

### Snapshot Tests

- Visual regression testing
- Multiple device sizes
- Dark/Light mode
- Accessibility

### Performance Tests

- API response times
- Model creation
- JSON encoding/decoding
- Memory management

## Mock Objects

### MockAPIClient

```swift
let mockClient = MockAPIClient()
mockClient.stub(endpoint: "/api/login", with: authResponse)
mockClient.shouldFail = true
mockClient.errorToThrow = .unauthorized
```

### MockDataFactory

```swift
let user = MockDataFactory.createUser()
let premiumUser = MockDataFactory.createPremiumUser()
let chatResponse = MockDataFactory.createChatResponse()
```

## CI/CD

Tests run automatically on:
- Push to `main` or `develop`
- Pull requests to `main` or `develop`

### GitHub Actions Workflow

1. **Unit Tests** - Fast feedback on code changes
2. **Integration Tests** - Verify component interactions
3. **UI Tests** - End-to-end user flows
4. **Performance Tests** - Catch performance regressions
5. **Code Coverage** - Enforce 70% minimum coverage
6. **SwiftLint** - Code style enforcement

## Coverage Requirements

- Minimum: 70%
- Target: 80%
- ViewModels: 90%+

## Best Practices

1. **Use Mocks**: Always use mock objects in unit tests
2. **Async Testing**: Use async/await for async operations
3. **State Verification**: Test state changes, not just final state
4. **Edge Cases**: Cover error states, empty data, limits
5. **Performance**: Use `measure {}` for performance-critical code

## Adding New Tests

1. Create test file in appropriate directory
2. Inherit from `ViewModelTestCase` for ViewModel tests
3. Use `MockDataFactory` for test data
4. Follow naming: `test<Method>_<Scenario>_<ExpectedResult>`

Example:
```swift
final class NewFeatureViewModelTests: ViewModelTestCase {
    var sut: NewFeatureViewModel!

    override func setUp() {
        super.setUp()
        sut = NewFeatureViewModel(apiClient: env.mockAPIClient)
    }

    func testLoadData_Success_UpdatesState() async {
        // Given
        env.mockAPIClient.stub(endpoint: "/api/data", with: mockData)

        // When
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.data.count, expectedCount)
    }
}
```

## Troubleshooting

### Tests timing out
- Increase timeout in test plan
- Check for deadlocks in async code

### Snapshot tests failing
- Record new snapshots: set `isRecording = true`
- Ensure consistent simulator state

### Code coverage not generating
- Enable coverage in scheme
- Use `-enableCodeCoverage YES` flag
