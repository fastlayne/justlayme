import Foundation

// MARK: - Validation Result

public struct ValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]

    public init(isValid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }

    public static var valid: ValidationResult {
        ValidationResult(isValid: true)
    }

    public static func invalid(_ errors: [String]) -> ValidationResult {
        ValidationResult(isValid: false, errors: errors)
    }
}

// MARK: - Validation Rule

public protocol ValidationRule {
    associatedtype Value
    func validate(_ value: Value) -> ValidationResult
}

// MARK: - Common Validation Rules

public struct RequiredRule<T>: ValidationRule {
    public typealias Value = T?
    private let fieldName: String

    public init(fieldName: String) {
        self.fieldName = fieldName
    }

    public func validate(_ value: T?) -> ValidationResult {
        if value == nil {
            return .invalid(["\(fieldName) is required"])
        }
        return .valid
    }
}

public struct StringLengthRule: ValidationRule {
    public typealias Value = String?
    private let fieldName: String
    private let minLength: Int?
    private let maxLength: Int?

    public init(fieldName: String, minLength: Int? = nil, maxLength: Int? = nil) {
        self.fieldName = fieldName
        self.minLength = minLength
        self.maxLength = maxLength
    }

    public func validate(_ value: String?) -> ValidationResult {
        guard let string = value else { return .valid }

        var errors: [String] = []

        if let min = minLength, string.count < min {
            errors.append("\(fieldName) must be at least \(min) characters")
        }

        if let max = maxLength, string.count > max {
            errors.append("\(fieldName) must be at most \(max) characters")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

public struct EmailRule: ValidationRule {
    public typealias Value = String
    private let fieldName: String

    public init(fieldName: String = "Email") {
        self.fieldName = fieldName
    }

    public func validate(_ value: String) -> ValidationResult {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if predicate.evaluate(with: value) {
            return .valid
        }

        return .invalid(["\(fieldName) is not a valid email address"])
    }
}

public struct RangeRule<T: Comparable>: ValidationRule {
    public typealias Value = T
    private let fieldName: String
    private let range: ClosedRange<T>

    public init(fieldName: String, range: ClosedRange<T>) {
        self.fieldName = fieldName
        self.range = range
    }

    public func validate(_ value: T) -> ValidationResult {
        if range.contains(value) {
            return .valid
        }
        return .invalid(["\(fieldName) must be between \(range.lowerBound) and \(range.upperBound)"])
    }
}

public struct URLRule: ValidationRule {
    public typealias Value = String?
    private let fieldName: String

    public init(fieldName: String) {
        self.fieldName = fieldName
    }

    public func validate(_ value: String?) -> ValidationResult {
        guard let urlString = value else { return .valid }

        if URL(string: urlString) != nil {
            return .valid
        }

        return .invalid(["\(fieldName) is not a valid URL"])
    }
}

// MARK: - Data Validator

public final class DataValidator {

    // MARK: - Singleton

    public static let shared = DataValidator()

    // MARK: - Initialization

    private init() {}

    // MARK: - User Validation

    public func validate(_ user: User) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Email validation
        let emailResult = EmailRule().validate(user.email)
        errors.append(contentsOf: emailResult.errors)

        // Name validation
        if let name = user.name {
            let nameResult = StringLengthRule(fieldName: "Name", minLength: 1, maxLength: 255).validate(name)
            errors.append(contentsOf: nameResult.errors)
        }

        // Subscription validation
        if user.subscriptionStatus != .free && user.subscriptionStatus != .lifetime {
            if user.subscriptionEnd == nil {
                warnings.append("Subscription end date is missing for non-free subscription")
            } else if user.subscriptionEnd! < Date() {
                warnings.append("Subscription has expired")
            }
        }

        // Message count validation
        if user.messageCount < 0 {
            errors.append("Message count cannot be negative")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    // MARK: - Conversation Validation

    public func validate(_ conversation: Conversation) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Title validation
        if let title = conversation.title {
            let titleResult = StringLengthRule(fieldName: "Title", maxLength: 255).validate(title)
            errors.append(contentsOf: titleResult.errors)
        }

        // Message count validation
        if conversation.messageCount < 0 {
            errors.append("Message count cannot be negative")
        }

        // Date validation
        if conversation.createdAt > Date() {
            warnings.append("Created date is in the future")
        }

        if let lastMessage = conversation.lastMessageAt, lastMessage < conversation.createdAt {
            warnings.append("Last message date is before creation date")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    // MARK: - Message Validation

    public func validate(_ message: Message) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Content validation
        let contentResult = StringLengthRule(fieldName: "Content", minLength: 1).validate(message.content)
        errors.append(contentsOf: contentResult.errors)

        // Tokens validation
        if let tokens = message.tokensUsed, tokens < 0 {
            errors.append("Tokens used cannot be negative")
        }

        // Response time validation
        if let responseTime = message.responseTimeMs, responseTime < 0 {
            errors.append("Response time cannot be negative")
        }

        // Date validation
        if message.createdAt > Date() {
            warnings.append("Created date is in the future")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    // MARK: - Character Validation

    public func validate(_ character: Character) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Name validation
        let nameResult = StringLengthRule(fieldName: "Name", minLength: 1, maxLength: 100).validate(character.name)
        errors.append(contentsOf: nameResult.errors)

        // Backstory validation
        if let backstory = character.backstory {
            let backstoryResult = StringLengthRule(fieldName: "Backstory", maxLength: 10000).validate(backstory)
            errors.append(contentsOf: backstoryResult.errors)
        }

        // Avatar URL validation
        let urlResult = URLRule(fieldName: "Avatar URL").validate(character.avatarUrl)
        errors.append(contentsOf: urlResult.errors)

        // Speech patterns validation
        if character.speechPatterns.count > 50 {
            warnings.append("Large number of speech patterns may impact performance")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    // MARK: - Character Memory Validation

    public func validate(_ memory: CharacterMemory) -> ValidationResult {
        var errors: [String] = []

        // User message validation
        let userMessageResult = StringLengthRule(fieldName: "User Message", minLength: 1).validate(memory.userMessage)
        errors.append(contentsOf: userMessageResult.errors)

        // AI response validation
        let aiResponseResult = StringLengthRule(fieldName: "AI Response", minLength: 1).validate(memory.aiResponse)
        errors.append(contentsOf: aiResponseResult.errors)

        // Feedback score validation
        if let score = memory.feedbackScore {
            if score < 1 || score > 5 {
                errors.append("Feedback score must be between 1 and 5")
            }
        }

        // Importance score validation
        if memory.importanceScore < 0 || memory.importanceScore > 1 {
            errors.append("Importance score must be between 0 and 1")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    // MARK: - Character Learning Validation

    public func validate(_ learning: CharacterLearning) -> ValidationResult {
        var errors: [String] = []

        // User input validation
        let inputResult = StringLengthRule(fieldName: "User Input", minLength: 1).validate(learning.userInput)
        errors.append(contentsOf: inputResult.errors)

        // Expected output validation
        let outputResult = StringLengthRule(fieldName: "Expected Output", minLength: 1).validate(learning.expectedOutput)
        errors.append(contentsOf: outputResult.errors)

        // Confidence validation
        if learning.confidence < 0 || learning.confidence > 1 {
            errors.append("Confidence must be between 0 and 1")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    // MARK: - Batch Validation

    public func validateAll<T>(_ items: [T], validator: (T) -> ValidationResult) -> ValidationResult {
        var allErrors: [String] = []
        var allWarnings: [String] = []

        for (index, item) in items.enumerated() {
            let result = validator(item)
            for error in result.errors {
                allErrors.append("Item \(index): \(error)")
            }
            for warning in result.warnings {
                allWarnings.append("Item \(index): \(warning)")
            }
        }

        return ValidationResult(
            isValid: allErrors.isEmpty,
            errors: allErrors,
            warnings: allWarnings
        )
    }

    // MARK: - Input Sanitization

    /// Sanitize string input
    public func sanitize(_ input: String) -> String {
        var sanitized = input

        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove control characters
        sanitized = sanitized.components(separatedBy: CharacterSet.controlCharacters).joined()

        // Limit consecutive whitespace
        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }

        return sanitized
    }

    /// Sanitize HTML/script tags
    public func sanitizeHTML(_ input: String) -> String {
        var sanitized = input

        // Remove script tags
        let scriptPattern = #"<script[^>]*>[\s\S]*?</script>"#
        sanitized = sanitized.replacingOccurrences(
            of: scriptPattern,
            with: "",
            options: .regularExpression
        )

        // Remove style tags
        let stylePattern = #"<style[^>]*>[\s\S]*?</style>"#
        sanitized = sanitized.replacingOccurrences(
            of: stylePattern,
            with: "",
            options: .regularExpression
        )

        // Remove all HTML tags
        let tagPattern = #"<[^>]+>"#
        sanitized = sanitized.replacingOccurrences(
            of: tagPattern,
            with: "",
            options: .regularExpression
        )

        return sanitized
    }
}

// MARK: - Validation Extensions

extension User {
    public func validate() -> ValidationResult {
        DataValidator.shared.validate(self)
    }
}

extension Conversation {
    public func validate() -> ValidationResult {
        DataValidator.shared.validate(self)
    }
}

extension Message {
    public func validate() -> ValidationResult {
        DataValidator.shared.validate(self)
    }
}

extension Character {
    public func validate() -> ValidationResult {
        DataValidator.shared.validate(self)
    }
}

extension CharacterMemory {
    public func validate() -> ValidationResult {
        DataValidator.shared.validate(self)
    }
}

extension CharacterLearning {
    public func validate() -> ValidationResult {
        DataValidator.shared.validate(self)
    }
}
