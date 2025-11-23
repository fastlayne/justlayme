// GreyMirror/Services/ML/MLOrchestrator.swift
// Coordinates all ML analysis modules and produces comprehensive report
// Matches web mlOrchestrator.js implementation

import Foundation
import Combine

final class MLOrchestrator: ObservableObject {

    // MARK: - Progress Tracking

    @Published private(set) var currentClassifier: String = ""
    @Published private(set) var progress: Double = 0.0

    private let messageParser = MessageParser()

    // MARK: - Analyzers

    private let sentimentAnalyzer = SentimentAnalyzer()
    private let toxicityClassifier = ToxicityClassifier()
    private let engagementScorer = EngagementScorer()
    private let doubleTextingDetector = DoubleTextingDetector()
    private let responseTimeAnalyzer = ResponseTimeAnalyzer()
    private let apologyClassifier = ApologyClassifier()
    private let positivityCalculator = PositivityCalculator()
    private let communicationPatternAnalyzer = CommunicationPatternAnalyzer()

    // MARK: - Main Analysis

    /// Run complete analysis pipeline
    func runCompleteAnalysis(
        data: String,
        format: MessageParser.ImportFormat = .paste,
        personalization: GreyMirrorReport.Personalization
    ) async -> GreyMirrorReport {

        // Step 1: Parse messages
        updateProgress("Parsing messages", 0.05)
        let messages = messageParser.parseConversationData(data, format: format)

        guard messages.count >= 2 else {
            return createErrorReport(
                error: "Need at least 2 messages for analysis (found \(messages.count))",
                personalization: personalization
            )
        }

        // Step 2: Get basic stats
        updateProgress("Calculating stats", 0.10)
        let stats = messageParser.getConversationStats(messages)

        // Step 3: Run all classifiers
        let classifiers: [(name: String, progress: Double)] = [
            ("Sentiment Analysis", 0.20),
            ("Sentiment Comparison", 0.28),
            ("Toxicity Detection", 0.36),
            ("Engagement Scoring", 0.44),
            ("Double Texting Analysis", 0.52),
            ("Response Time Analysis", 0.60),
            ("Apology Pattern Detection", 0.68),
            ("Communication Patterns", 0.76),
            ("Positivity Index", 0.84),
            ("Generating Insights", 0.92),
        ]

        // Run sentiment analysis
        updateProgress(classifiers[0].name, classifiers[0].progress)
        let sentiment = sentimentAnalyzer.analyzeSentiment(messages)

        // Run sentiment comparison
        updateProgress(classifiers[1].name, classifiers[1].progress)
        let sentimentComparison = sentimentAnalyzer.compareSentiment(messages)

        // Run toxicity classification
        updateProgress(classifiers[2].name, classifiers[2].progress)
        let toxicity = toxicityClassifier.classifyToxicity(messages)

        // Run engagement scoring
        updateProgress(classifiers[3].name, classifiers[3].progress)
        let engagement = engagementScorer.scoreEngagement(messages)

        // Run double texting detection
        updateProgress(classifiers[4].name, classifiers[4].progress)
        let doubleTexting = doubleTextingDetector.detectDoubleTexting(messages)

        // Run response time analysis
        updateProgress(classifiers[5].name, classifiers[5].progress)
        let responseTimes = responseTimeAnalyzer.analyzeResponseTimes(messages)

        // Run apology detection
        updateProgress(classifiers[6].name, classifiers[6].progress)
        let apologyPatterns = apologyClassifier.detectApologyPatterns(messages)

        // Run communication pattern analysis
        updateProgress(classifiers[7].name, classifiers[7].progress)
        let communicationPatterns = communicationPatternAnalyzer.analyzePatterns(messages)

        // Calculate positivity index
        updateProgress(classifiers[8].name, classifiers[8].progress)
        let positivity = positivityCalculator.calculatePositivityIndex(messages)

        // Generate insights and recommendations
        updateProgress(classifiers[9].name, classifiers[9].progress)
        let insights = extractKeyInsights(
            doubleTexting: doubleTexting,
            responseTimes: responseTimes,
            engagement: engagement,
            positivity: positivity
        )
        let recommendations = generateRecommendations(
            toxicity: toxicity,
            engagement: engagement,
            positivity: positivity
        )

        // Generate summary
        let summary = generateComprehensiveSummary(
            sentiment: sentiment,
            toxicity: toxicity,
            engagement: engagement,
            positivity: positivity,
            doubleTexting: doubleTexting
        )

        updateProgress("Complete", 1.0)

        return GreyMirrorReport(
            id: UUID(),
            timestamp: Date(),
            success: true,
            error: nil,
            stats: stats,
            healthScore: positivity.score,
            messageCount: stats.totalMessages,
            sentiment: sentiment,
            sentimentComparison: sentimentComparison,
            toxicity: toxicity,
            engagement: engagement,
            doubleTexting: doubleTexting,
            responseTimes: responseTimes,
            apologyPatterns: apologyPatterns,
            positivity: positivity,
            communicationPatterns: communicationPatterns,
            summary: summary,
            insights: insights,
            recommendations: recommendations,
            personalization: personalization
        )
    }

    // MARK: - Progress Updates

    private func updateProgress(_ classifier: String, _ value: Double) {
        DispatchQueue.main.async {
            self.currentClassifier = classifier
            self.progress = value
        }
    }

    // MARK: - Error Report

    private func createErrorReport(error: String, personalization: GreyMirrorReport.Personalization) -> GreyMirrorReport {
        return GreyMirrorReport(
            id: UUID(),
            timestamp: Date(),
            success: false,
            error: error,
            stats: ConversationStats(totalMessages: 0, uniqueSenders: 0, dateRange: nil, averageMessageLength: 0),
            healthScore: 0,
            messageCount: 0,
            sentiment: nil,
            sentimentComparison: nil,
            toxicity: nil,
            engagement: nil,
            doubleTexting: nil,
            responseTimes: nil,
            apologyPatterns: nil,
            positivity: nil,
            communicationPatterns: nil,
            summary: "",
            insights: [],
            recommendations: [],
            personalization: personalization
        )
    }

    // MARK: - Summary Generation

    private func generateComprehensiveSummary(
        sentiment: SentimentAnalysis,
        toxicity: ToxicityAnalysis,
        engagement: EngagementAnalysis,
        positivity: PositivityIndex,
        doubleTexting: DoubleTextingAnalysis
    ) -> String {
        var sections: [String] = []

        // Overall health
        sections.append("Overall Relationship Health: \(positivity.health.rawValue.uppercased()) (\(positivity.score)/100)")
        sections.append(positivity.summary)

        // Sentiment
        sections.append("\nSentiment Profile: \(sentiment.sentiment.rawValue.uppercased())")
        sections.append(sentiment.summary)

        // Double texting
        if doubleTexting.hasDoubleTexts {
            sections.append("\nDouble Texting Pattern Detected")
            sections.append(doubleTexting.comparison.interpretation)
        }

        // Toxicity
        if toxicity.hasToxicity {
            sections.append("\nToxicity Alert: \(toxicity.level.rawValue.uppercased())")
            sections.append(toxicity.summary)
        } else {
            sections.append("\nClean Communication: No significant toxicity detected")
        }

        // Engagement
        sections.append("\nEmotional Engagement: \(engagement.level.rawValue.uppercased()) (\(engagement.overallScore)/100)")
        sections.append(engagement.summary)

        return sections.joined(separator: "\n")
    }

    // MARK: - Insights Extraction

    private func extractKeyInsights(
        doubleTexting: DoubleTextingAnalysis,
        responseTimes: ResponseTimeAnalysis,
        engagement: EngagementAnalysis,
        positivity: PositivityIndex
    ) -> [GreyMirrorReport.KeyInsight] {
        var insights: [GreyMirrorReport.KeyInsight] = []

        // Double texting insight
        if doubleTexting.hasDoubleTexts && doubleTexting.comparison.difference > 20 {
            let person = doubleTexting.comparison.moreInvested == "you" ? "You" : "They"
            insights.append(GreyMirrorReport.KeyInsight(
                category: "Investment Level",
                insight: "\(person) show significantly higher investment through double texting patterns",
                importance: "high"
            ))
        }

        // Response time insight
        if responseTimes.comparison.faster != "equal" {
            insights.append(GreyMirrorReport.KeyInsight(
                category: "Responsiveness",
                insight: "\(responseTimes.comparison.faster == "you" ? "You" : "They") respond \(Int(responseTimes.comparison.percentDifference))% faster on average",
                importance: "medium"
            ))
        }

        // Engagement insight
        if !engagement.you.drivers.isEmpty {
            insights.append(GreyMirrorReport.KeyInsight(
                category: "Engagement",
                insight: "Your main engagement driver is \(engagement.you.drivers[0].name.lowercased())",
                importance: "low"
            ))
        }

        // Health trend
        if positivity.trend != "insufficient_data" {
            insights.append(GreyMirrorReport.KeyInsight(
                category: "Trend",
                insight: "Relationship is \(positivity.trend) over time",
                importance: positivity.trend == "declining" ? "high" : "low"
            ))
        }

        return insights.sorted { importance($0.importance) < importance($1.importance) }
    }

    private func importance(_ level: String) -> Int {
        switch level {
        case "high": return 0
        case "medium": return 1
        default: return 2
        }
    }

    // MARK: - Recommendations

    private func generateRecommendations(
        toxicity: ToxicityAnalysis,
        engagement: EngagementAnalysis,
        positivity: PositivityIndex
    ) -> [GreyMirrorReport.Recommendation] {
        var recommendations: [GreyMirrorReport.Recommendation] = []

        // Toxicity recommendation
        if toxicity.level == .high || toxicity.level == .severe {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "high",
                action: "Address Toxicity",
                details: "Consider having a calm discussion about communication style. Try using \"I feel\" statements instead of blaming."
            ))
        }

        // Engagement recommendation
        if engagement.overallScore < 40 {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "high",
                action: "Increase Engagement",
                details: "Try asking more questions, using emoji, or sharing more personal details to deepen connection."
            ))
        }

        // Health recommendation
        if positivity.score < 40 {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "high",
                action: "Assess Relationship Health",
                details: positivity.recommendation
            ))
        } else if positivity.score >= 70 {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "low",
                action: "Maintain Momentum",
                details: "Relationship is healthy! Continue investing in open communication and positive interactions."
            ))
        }

        return recommendations.sorted { priority($0.priority) < priority($1.priority) }
    }

    private func priority(_ level: String) -> Int {
        switch level {
        case "high": return 0
        case "medium": return 1
        default: return 2
        }
    }
}
