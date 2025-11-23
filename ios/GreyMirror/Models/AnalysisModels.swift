// GreyMirror/Models/AnalysisModels.swift
// Data models matching the web ML classifier outputs

import Foundation

// MARK: - Core Message Model

struct ParsedMessage: Identifiable, Codable {
    let id: Int
    let timestamp: Date
    let sender: String
    let content: String
    let direction: MessageDirection
    let length: Int
    var timeSinceLast: TimeInterval?

    enum MessageDirection: String, Codable {
        case sent, received
    }
}

// MARK: - Conversation Stats

struct ConversationStats: Codable {
    let totalMessages: Int
    let uniqueSenders: Int
    let dateRange: DateRange?
    let averageMessageLength: Int

    struct DateRange: Codable {
        let start: Date
        let end: Date
    }
}

// MARK: - Sentiment Analysis

struct SentimentAnalysis: Codable {
    let overallScore: Double  // -1 to 1
    let sentiment: SentimentLevel
    let confidence: Double
    let breakdown: SentimentBreakdown
    let emotionalIntensity: EmotionalIntensity
    let summary: String

    enum SentimentLevel: String, Codable {
        case positive, negative, neutral
    }

    struct SentimentBreakdown: Codable {
        let positive: Int
        let negative: Int
        let neutral: Int
        let percentages: Percentages

        struct Percentages: Codable {
            let positive: Double
            let negative: Double
            let neutral: Double
        }
    }

    struct EmotionalIntensity: Codable {
        let average: Double
        let max: Double
        let level: String  // high, moderate, low
    }
}

struct SentimentComparison: Codable {
    let youSentiment: PersonSentiment
    let themSentiment: PersonSentiment
    let difference: Double
    let morePositive: String  // "you", "them", "balanced"
    let summary: String

    struct PersonSentiment: Codable {
        let score: Double
        let sentiment: String
        let messageCount: Int
    }
}

// MARK: - Toxicity Analysis

struct ToxicityAnalysis: Codable {
    let overallToxicity: Double  // 0 to 1
    let level: ToxicityLevel
    let hasToxicity: Bool
    let toxicMessages: Int
    let toxicityPercentage: Double
    let you: PersonToxicity
    let them: PersonToxicity
    let topConcerns: [ToxicityConcern]
    let summary: String

    enum ToxicityLevel: String, Codable {
        case none, low, moderate, high, severe
    }

    struct PersonToxicity: Codable {
        let toxicity: Double
        let toxicMessages: Int
    }

    struct ToxicityConcern: Codable {
        let concern: String
        let count: Int
    }
}

// MARK: - Engagement Analysis

struct EngagementAnalysis: Codable {
    let overallScore: Int  // 0-100
    let level: EngagementLevel
    let you: PersonEngagement
    let them: PersonEngagement
    let comparison: EngagementComparison
    let drivers: EngagementDrivers
    let summary: String

    enum EngagementLevel: String, Codable {
        case minimal, low, moderate, high, very_high
    }

    struct PersonEngagement: Codable {
        let score: Int
        let level: String
        let messageCount: Int
        let drivers: [Driver]

        struct Driver: Codable {
            let name: String
            let value: Int
            let score: Double
        }
    }

    struct EngagementComparison: Codable {
        let moreEngaged: String  // "you", "them", "equal"
        let difference: Int
        let interpretation: String
    }

    struct EngagementDrivers: Codable {
        let yourTopDrivers: [String]
        let theirTopDrivers: [String]
        let sharedDrivers: [String]
    }
}

// MARK: - Double Texting Analysis

struct DoubleTextingAnalysis: Codable {
    let hasDoubleTexts: Bool
    let totalDoubleTexts: Int
    let totalTripleTexts: Int
    let totalQuadPlusTexts: Int
    let you: PersonDoubleTexting
    let them: PersonDoubleTexting
    let comparison: DoubleTextingComparison
    let analysis: String
    let summary: String

    struct PersonDoubleTexting: Codable {
        let doubleTexts: Int
        let tripleTexts: Int
        let quadPlusTexts: Int
        let longestStreak: Int
        let averageStreakLength: Double
        let totalStreakMessages: Int
        let doubleTextRate: Double
        let investmentScore: Int
        let streakBreakdown: StreakBreakdown

        struct StreakBreakdown: Codable {
            let double: Int
            let triple: Int
            let quadPlus: Int
        }
    }

    struct DoubleTextingComparison: Codable {
        let moreInvested: String
        let difference: Int
        let interpretation: String
        let whoDoubleTextsMore: String
        let whoTripleTextsMore: String
        let doubleTextRatio: Ratio
        let streakLengthDifference: Int
        let whoHasLongerStreaks: String

        struct Ratio: Codable {
            let you: Int
            let them: Int
        }
    }
}

// MARK: - Response Time Analysis

struct ResponseTimeAnalysis: Codable {
    let you: PersonResponseTime
    let them: PersonResponseTime
    let comparison: ResponseTimeComparison
    let patterns: [ResponsePattern]
    let summary: String

    struct PersonResponseTime: Codable {
        let count: Int
        let average: String  // Formatted time: "2m", "1h"
        let averageMs: Double
        let median: String
        let min: String
        let max: String
        let consistency: String  // very_consistent, consistent, somewhat_variable, highly_variable
        let averageReadiness: String  // immediate, very_quick, quick, moderate, slow
    }

    struct ResponseTimeComparison: Codable {
        let faster: String  // "you", "them", "equal"
        let timeDifference: String
        let percentDifference: Double
        let interpretation: String
    }

    struct ResponsePattern: Codable {
        let type: String
        let party: String
        let indicator: String
    }
}

// MARK: - Apology Analysis

struct ApologyAnalysis: Codable {
    let hasApologies: Bool
    let totalApologies: Int
    let apologyRatio: ApologyRatio
    let you: PersonApologies
    let them: PersonApologies
    let comparison: ApologyComparison
    let reconciliation: ReconciliationStats
    let patterns: [String]
    let summary: String

    struct ApologyRatio: Codable {
        let you: Int
        let them: Int
    }

    struct PersonApologies: Codable {
        let totalApologies: Int
        let explicitApologies: Int
        let softApologies: Int
        let apologyPercentage: Double
        let averageSincerity: Int  // 0-100
        let reconciliationAttempts: Int
        let firstToApologize: Int
    }

    struct ApologyComparison: Codable {
        let whoApologizesMore: String
        let apologyDifference: Int
        let balanceScore: Int  // 0-100, 50 is balanced
        let reconciliationBalance: Int
    }

    struct ReconciliationStats: Codable {
        let totalAttempts: Int
        let successRate: Int
        let averageResolutionTime: Int
    }
}

// MARK: - Positivity Index (Overall Health)

struct PositivityIndex: Codable {
    let score: Int  // 0-100
    let health: HealthLevel
    let trend: String  // improving, stable, declining, insufficient_data
    let you: PersonPositivity
    let them: PersonPositivity
    let comparison: PositivityComparison
    let indicators: [HealthIndicator]
    let recommendation: String
    let summary: String

    enum HealthLevel: String, Codable {
        case excellent, good, moderate, poor, toxic, unknown
    }

    struct PersonPositivity: Codable {
        let score: Int
        let positiveCount: Int
        let negativeCount: Int
        let neutralCount: Int
        let level: String
    }

    struct PositivityComparison: Codable {
        let morePositive: String
        let scoreDiff: Double
        let interpretation: String
    }

    struct HealthIndicator: Codable {
        let type: String  // positive, warning
        let text: String
    }
}

// MARK: - Communication Patterns

struct CommunicationPatterns: Codable {
    let frequency: MessageFrequency
    let engagement: PatternEngagement
    let summary: String

    struct MessageFrequency: Codable {
        let total: Int
        let youInitiated: Int
        let theyResponded: Int
        let averageMessageLength: AverageLength
        let balance: Balance

        struct AverageLength: Codable {
            let you: Int
            let them: Int
            let longer: String
        }

        struct Balance: Codable {
            let interpretation: String
        }
    }

    struct PatternEngagement: Codable {
        let questions: PersonCount
        let emoji: PersonCount

        struct PersonCount: Codable {
            let you: Int
            let them: Int
        }
    }
}

// MARK: - Complete Analysis Report

struct GreyMirrorReport: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let success: Bool
    let error: String?

    // Core stats
    let stats: ConversationStats
    let healthScore: Int
    let messageCount: Int

    // All classifier outputs
    let sentiment: SentimentAnalysis?
    let sentimentComparison: SentimentComparison?
    let toxicity: ToxicityAnalysis?
    let engagement: EngagementAnalysis?
    let doubleTexting: DoubleTextingAnalysis?
    let responseTimes: ResponseTimeAnalysis?
    let apologyPatterns: ApologyAnalysis?
    let positivity: PositivityIndex?
    let communicationPatterns: CommunicationPatterns?

    // Summary data
    let summary: String
    let insights: [KeyInsight]
    let recommendations: [Recommendation]

    // Personalization
    let personalization: Personalization

    struct KeyInsight: Codable {
        let category: String
        let insight: String
        let importance: String  // high, medium, low
    }

    struct Recommendation: Codable {
        let priority: String  // high, medium, low
        let action: String
        let details: String
    }

    struct Personalization: Codable {
        let userName: String
        let contactName: String
        let insightsGoal: String
    }
}

// MARK: - Analysis State

enum AnalysisState: Equatable {
    case idle
    case uploading(progress: Double)
    case parsing
    case analyzing(currentClassifier: String, progress: Double)
    case completed(report: GreyMirrorReport)
    case failed(error: String)

    static func == (lhs: AnalysisState, rhs: AnalysisState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.parsing, .parsing): return true
        case (.uploading(let p1), .uploading(let p2)): return p1 == p2
        case (.analyzing(let c1, let p1), .analyzing(let c2, let p2)): return c1 == c2 && p1 == p2
        case (.completed, .completed): return true
        case (.failed(let e1), .failed(let e2)): return e1 == e2
        default: return false
        }
    }
}

// MARK: - Classifier Info

struct ClassifierInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String

    static let allClassifiers: [ClassifierInfo] = [
        ClassifierInfo(id: "sentiment", name: "Sentiment Analysis", description: "Analyzes emotional tone", icon: "face.smiling"),
        ClassifierInfo(id: "sentimentComparison", name: "Sentiment Comparison", description: "Compares sentiment between parties", icon: "arrow.left.arrow.right"),
        ClassifierInfo(id: "toxicity", name: "Toxicity Detection", description: "Detects toxic language", icon: "exclamationmark.triangle"),
        ClassifierInfo(id: "engagement", name: "Engagement Scoring", description: "Measures emotional investment", icon: "heart"),
        ClassifierInfo(id: "doubleTexting", name: "Double Texting", description: "Analyzes message streaks", icon: "bubble.left.and.bubble.right"),
        ClassifierInfo(id: "streakTiming", name: "Streak Timing", description: "Analyzes timing within streaks", icon: "clock"),
        ClassifierInfo(id: "responseTimes", name: "Response Times", description: "Measures response speed", icon: "timer"),
        ClassifierInfo(id: "callbacks", name: "Callback Consistency", description: "Analyzes follow-up patterns", icon: "arrow.turn.up.left"),
        ClassifierInfo(id: "weekdayWeekend", name: "Weekday/Weekend", description: "Compares patterns by day type", icon: "calendar"),
        ClassifierInfo(id: "apologies", name: "Apology Patterns", description: "Detects apologies and reconciliation", icon: "hand.raised"),
        ClassifierInfo(id: "positivity", name: "Positivity Index", description: "Calculates overall health score", icon: "chart.line.uptrend.xyaxis"),
        ClassifierInfo(id: "patterns", name: "Communication Patterns", description: "Analyzes messaging style", icon: "message")
    ]
}

// MARK: - UI Display Models

struct MetricDisplayData: Identifiable {
    let id: String
    let title: String
    let icon: String
    let value: String
    let description: String
    let summary: String
    let youSection: [String: Any]?
    let themSection: [String: Any]?
    let comparison: String?
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let category: String
}
