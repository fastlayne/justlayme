import Foundation

// MARK: - Black Mirror Analysis Models
// Maps to client/src/services/ml/mlOrchestrator.js output

/// Complete analysis report from the ML orchestrator
struct BlackMirrorReport: Codable, Equatable {
    let success: Bool
    let timestamp: Date?
    let stats: ConversationStats?
    let metrics: AnalysisMetrics?
    let summary: String?
    let insights: [String]?
    let recommendations: [String]?
    let error: String?
    let messageCount: Int?

    // UI-formatted data
    let healthScore: Int?
    let healthLabel: String?
    let metricCards: [MetricCard]?
}

/// Basic conversation statistics
struct ConversationStats: Codable, Equatable {
    let totalMessages: Int
    let yourMessages: Int
    let theirMessages: Int
    let dateRange: DateRange?
    let participants: [String]?

    struct DateRange: Codable, Equatable {
        let start: Date?
        let end: Date?
        let durationDays: Int?
    }
}

/// All ML analysis metrics
struct AnalysisMetrics: Codable, Equatable {
    let sentiment: SentimentAnalysis?
    let sentimentComparison: SentimentComparison?
    let communicationPatterns: CommunicationPatterns?
    let doubleTexting: DoubleTextingAnalysis?
    let streakTiming: StreakTiming?
    let weekdayWeekend: WeekdayWeekendAnalysis?
    let responseTimes: ResponseTimeAnalysis?
    let callbacks: CallbackAnalysis?
    let toxicity: ToxicityAnalysis?
    let engagement: EngagementAnalysis?
    let positivity: PositivityAnalysis?
    let apologyPatterns: ApologyAnalysis?
}

// MARK: - Individual Metric Types

struct SentimentAnalysis: Codable, Equatable {
    let sentiment: String  // "positive", "negative", "neutral"
    let score: Double?
    let summary: String
    let data: SentimentData?

    struct SentimentData: Codable, Equatable {
        let positive: Double?
        let negative: Double?
        let neutral: Double?
    }
}

struct SentimentComparison: Codable, Equatable {
    let summary: String
    let yourSentiment: Double?
    let theirSentiment: Double?
    let balance: String?
}

struct CommunicationPatterns: Codable, Equatable {
    let summary: String
    let initiationRatio: Double?
    let averageMessageLength: MessageLengthComparison?
    let topTopics: [String]?

    struct MessageLengthComparison: Codable, Equatable {
        let yours: Double?
        let theirs: Double?
    }
}

struct DoubleTextingAnalysis: Codable, Equatable {
    let summary: String
    let yourDoubleTexts: Int?
    let theirDoubleTexts: Int?
    let ratio: Double?
    let instances: [DoubleTextInstance]?

    struct DoubleTextInstance: Codable, Equatable {
        let timestamp: Date?
        let sender: String?
        let count: Int?
    }
}

struct StreakTiming: Codable, Equatable {
    let summary: String
    let longestStreak: Int?
    let averageStreakLength: Double?
}

struct WeekdayWeekendAnalysis: Codable, Equatable {
    let summary: String
    let weekdayActivity: Double?
    let weekendActivity: Double?
    let peakDay: String?
    let peakHour: Int?
}

struct ResponseTimeAnalysis: Codable, Equatable {
    let summary: String
    let yourAverage: TimeInterval?
    let theirAverage: TimeInterval?
    let yourMedian: TimeInterval?
    let theirMedian: TimeInterval?
    let balance: String?  // "balanced", "you respond faster", "they respond faster"
}

struct CallbackAnalysis: Codable, Equatable {
    let summary: String
    let yourCallbackRate: Double?
    let theirCallbackRate: Double?
    let consistency: String?
}

struct ToxicityAnalysis: Codable, Equatable {
    let summary: String
    let overallScore: Double?  // 0-100, lower is better
    let yourToxicity: Double?
    let theirToxicity: Double?
    let flaggedMessages: [FlaggedMessage]?

    struct FlaggedMessage: Codable, Equatable {
        let content: String?
        let score: Double?
        let sender: String?
    }
}

struct EngagementAnalysis: Codable, Equatable {
    let summary: String
    let overallScore: Double?  // 0-100
    let yourEngagement: Double?
    let theirEngagement: Double?
    let questionRatio: Double?
    let emojiUsage: EmojiUsage?

    struct EmojiUsage: Codable, Equatable {
        let yours: Double?
        let theirs: Double?
    }
}

struct PositivityAnalysis: Codable, Equatable {
    let summary: String
    let score: Int  // 0-100
    let health: String  // "healthy", "moderate", "concerning"
    let yourPositivity: Double?
    let theirPositivity: Double?
}

struct ApologyAnalysis: Codable, Equatable {
    let summary: String
    let hasApologies: Bool
    let yourApologies: Int?
    let theirApologies: Int?
    let patterns: [ApologyPattern]?

    struct ApologyPattern: Codable, Equatable {
        let type: String?
        let count: Int?
    }
}

// MARK: - UI Display Models

/// Card displayed in the results view
struct MetricCard: Codable, Identifiable, Equatable {
    var id: String { metricId }
    let metricId: String
    let title: String
    let icon: String
    let value: String
    let subtitle: String?
    let color: String
    let summary: String
    let isExpanded: Bool?
    let chartData: [ChartDataPoint]?
}

struct ChartDataPoint: Codable, Equatable {
    let label: String
    let value: Double
    let color: String?
}

// MARK: - Analysis Request/Response

struct AnalysisRequest: Codable {
    let data: String
    let method: AnalysisMethod
    let personalization: Personalization?
}

enum AnalysisMethod: String, Codable {
    case paste
    case file
    case screenshot
}

struct Personalization: Codable {
    var userName: String
    var contactName: String
    var insightsGoal: String?
}

struct AnalysisProgressResponse: Codable {
    let status: AnalysisStatus
    let progress: Int?
    let error: String?
}

enum AnalysisStatus: String, Codable {
    case pending
    case processing
    case completed
    case error
}

// MARK: - Predefined Metric Types for UI
enum MetricType: String, CaseIterable, Identifiable {
    case healthScore = "health"
    case sentiment = "sentiment"
    case engagement = "engagement"
    case responseTimes = "response_times"
    case communication = "communication"
    case toxicity = "toxicity"
    case doubleTexting = "double_texting"
    case weekendWeekday = "weekend_weekday"
    case positivity = "positivity"
    case apologies = "apologies"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healthScore: return "Relationship Health"
        case .sentiment: return "Sentiment Analysis"
        case .engagement: return "Engagement Score"
        case .responseTimes: return "Response Times"
        case .communication: return "Communication Patterns"
        case .toxicity: return "Toxicity Check"
        case .doubleTexting: return "Double Texting"
        case .weekendWeekday: return "Activity Patterns"
        case .positivity: return "Positivity Index"
        case .apologies: return "Apology Patterns"
        }
    }

    var icon: String {
        switch self {
        case .healthScore: return "heart.fill"
        case .sentiment: return "face.smiling"
        case .engagement: return "chart.bar.fill"
        case .responseTimes: return "clock.fill"
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .toxicity: return "exclamationmark.triangle.fill"
        case .doubleTexting: return "arrow.uturn.left.circle.fill"
        case .weekendWeekday: return "calendar"
        case .positivity: return "sun.max.fill"
        case .apologies: return "hand.raised.fill"
        }
    }

    var color: String {
        switch self {
        case .healthScore: return "red"
        case .sentiment: return "blue"
        case .engagement: return "green"
        case .responseTimes: return "orange"
        case .communication: return "purple"
        case .toxicity: return "yellow"
        case .doubleTexting: return "pink"
        case .weekendWeekday: return "teal"
        case .positivity: return "yellow"
        case .apologies: return "indigo"
        }
    }
}
