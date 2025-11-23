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

    // MARK: - Original Analyzers (12)

    private let sentimentAnalyzer = SentimentAnalyzer()
    private let toxicityClassifier = ToxicityClassifier()
    private let engagementScorer = EngagementScorer()
    private let doubleTextingDetector = DoubleTextingDetector()
    private let responseTimeAnalyzer = ResponseTimeAnalyzer()
    private let apologyClassifier = ApologyClassifier()
    private let positivityCalculator = PositivityCalculator()
    private let communicationPatternAnalyzer = CommunicationPatternAnalyzer()

    // MARK: - Advanced Analyzers (28 new)

    // Attachment & Connection (1-8)
    private let attachmentStyleDetector = AttachmentStyleDetector()
    private let loveLanguageAnalyzer = LoveLanguageAnalyzer()
    private let powerDynamicsDetector = PowerDynamicsDetector()
    private let emotionalLaborTracker = EmotionalLaborTracker()
    private let breadcrumbingDetector = BreadcrumbingDetector()
    private let interestLevelScorer = InterestLevelScorer()
    private let redFlagDetector = RedFlagDetector()
    private let greenFlagDetector = GreenFlagDetector()

    // Emotional Depth (9-14)
    private let vulnerabilityDetector = VulnerabilityDetector()
    private let trustIndicatorAnalyzer = TrustIndicatorAnalyzer()
    private let jealousyDetector = JealousyDetector()
    private let futurePlanningAnalyzer = FuturePlanningAnalyzer()
    private let humorCompatibilityAnalyzer = HumorCompatibilityAnalyzer()
    private let topicDiversityAnalyzer = TopicDiversityAnalyzer()

    // Behavioral Patterns (15-22)
    private let consistencyAnalyzer = ConsistencyAnalyzer()
    private let ghostingRiskPredictor = GhostingRiskPredictor()
    private let emotionalAvailabilityAnalyzer = EmotionalAvailabilityAnalyzer()
    private let conflictStyleAnalyzer = ConflictStyleAnalyzer()
    private let affectionExpressionAnalyzer = AffectionExpressionAnalyzer()
    private let resentmentAccumulator = ResentmentAccumulator()
    private let boundaryRespectAnalyzer = BoundaryRespectAnalyzer()
    private let emotionalIntelligenceScorer = EmotionalIntelligenceScorer()

    // Quality & Growth (23-28)
    private let listeningQualityScorer = ListeningQualityScorer()
    private let memoryRecallAnalyzer = MemoryRecallAnalyzer()
    private let initiationBalanceAnalyzer = InitiationBalanceAnalyzer()
    private let supportQualityAnalyzer = SupportQualityAnalyzer()
    private let validationPatternDetector = ValidationPatternDetector()
    private let growthMindsetDetector = GrowthMindsetDetector()

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

        // Step 3: Run original 12 classifiers (quick progress updates)
        updateProgress("Sentiment Analysis", 0.10)
        let sentiment = sentimentAnalyzer.analyzeSentiment(messages)
        let sentimentComparison = sentimentAnalyzer.compareSentiment(messages)

        updateProgress("Toxicity Detection", 0.14)
        let toxicity = toxicityClassifier.classifyToxicity(messages)

        updateProgress("Engagement Scoring", 0.18)
        let engagement = engagementScorer.scoreEngagement(messages)

        updateProgress("Double Texting Analysis", 0.22)
        let doubleTexting = doubleTextingDetector.detectDoubleTexting(messages)

        updateProgress("Response Time Analysis", 0.26)
        let responseTimes = responseTimeAnalyzer.analyzeResponseTimes(messages)

        updateProgress("Apology Pattern Detection", 0.30)
        let apologyPatterns = apologyClassifier.detectApologyPatterns(messages)

        updateProgress("Communication Patterns", 0.34)
        let communicationPatterns = communicationPatternAnalyzer.analyzePatterns(messages)

        updateProgress("Positivity Index", 0.38)
        let positivity = positivityCalculator.calculatePositivityIndex(messages)

        // Step 4: Run 28 Advanced Classifiers
        updateProgress("Attachment Style", 0.40)
        let attachmentStyle = attachmentStyleDetector.analyze(messages)

        updateProgress("Love Languages", 0.42)
        let loveLanguages = loveLanguageAnalyzer.analyze(messages)

        updateProgress("Power Dynamics", 0.44)
        let powerDynamics = powerDynamicsDetector.analyze(messages)

        updateProgress("Emotional Labor", 0.46)
        let emotionalLabor = emotionalLaborTracker.analyze(messages)

        updateProgress("Breadcrumbing Detection", 0.48)
        let breadcrumbing = breadcrumbingDetector.analyze(messages)

        updateProgress("Interest Level", 0.50)
        let interestLevel = interestLevelScorer.analyze(messages)

        updateProgress("Red Flags", 0.52)
        let redFlags = redFlagDetector.analyze(messages)

        updateProgress("Green Flags", 0.54)
        let greenFlags = greenFlagDetector.analyze(messages)

        updateProgress("Vulnerability", 0.56)
        let vulnerability = vulnerabilityDetector.analyze(messages)

        updateProgress("Trust Indicators", 0.58)
        let trust = trustIndicatorAnalyzer.analyze(messages)

        updateProgress("Jealousy Patterns", 0.60)
        let jealousy = jealousyDetector.analyze(messages)

        updateProgress("Future Planning", 0.62)
        let futurePlanning = futurePlanningAnalyzer.analyze(messages)

        updateProgress("Humor Compatibility", 0.64)
        let humorCompatibility = humorCompatibilityAnalyzer.analyze(messages)

        updateProgress("Topic Diversity", 0.66)
        let topicDiversity = topicDiversityAnalyzer.analyze(messages)

        updateProgress("Consistency", 0.68)
        let consistency = consistencyAnalyzer.analyze(messages)

        updateProgress("Ghosting Risk", 0.70)
        let ghostingRisk = ghostingRiskPredictor.analyze(messages)

        updateProgress("Emotional Availability", 0.72)
        let emotionalAvailability = emotionalAvailabilityAnalyzer.analyze(messages)

        updateProgress("Conflict Style", 0.74)
        let conflictStyle = conflictStyleAnalyzer.analyze(messages)

        updateProgress("Affection Expression", 0.76)
        let affectionExpression = affectionExpressionAnalyzer.analyze(messages)

        updateProgress("Resentment", 0.78)
        let resentment = resentmentAccumulator.analyze(messages)

        updateProgress("Boundary Respect", 0.80)
        let boundaryRespect = boundaryRespectAnalyzer.analyze(messages)

        updateProgress("Emotional Intelligence", 0.82)
        let emotionalIntelligence = emotionalIntelligenceScorer.analyze(messages)

        updateProgress("Listening Quality", 0.84)
        let listeningQuality = listeningQualityScorer.analyze(messages)

        updateProgress("Memory & Recall", 0.86)
        let memoryRecall = memoryRecallAnalyzer.analyze(messages)

        updateProgress("Initiation Balance", 0.88)
        let initiationBalance = initiationBalanceAnalyzer.analyze(messages)

        updateProgress("Support Quality", 0.90)
        let supportQuality = supportQualityAnalyzer.analyze(messages)

        updateProgress("Validation Patterns", 0.92)
        let validationPatterns = validationPatternDetector.analyze(messages)

        updateProgress("Growth Mindset", 0.94)
        let growthMindset = growthMindsetDetector.analyze(messages)

        // Package advanced analysis
        let advancedAnalysis = AdvancedAnalysis(
            attachmentStyle: attachmentStyle,
            loveLanguages: loveLanguages,
            powerDynamics: powerDynamics,
            emotionalLabor: emotionalLabor,
            breadcrumbing: breadcrumbing,
            interestLevel: interestLevel,
            redFlags: redFlags,
            greenFlags: greenFlags,
            vulnerability: vulnerability,
            trust: trust,
            jealousy: jealousy,
            futurePlanning: futurePlanning,
            humorCompatibility: humorCompatibility,
            topicDiversity: topicDiversity,
            consistency: consistency,
            ghostingRisk: ghostingRisk,
            emotionalAvailability: emotionalAvailability,
            conflictStyle: conflictStyle,
            affectionExpression: affectionExpression,
            resentment: resentment,
            boundaryRespect: boundaryRespect,
            emotionalIntelligence: emotionalIntelligence,
            listeningQuality: listeningQuality,
            memoryRecall: memoryRecall,
            initiationBalance: initiationBalance,
            supportQuality: supportQuality,
            validationPatterns: validationPatterns,
            growthMindset: growthMindset
        )

        // Generate insights and recommendations (now with advanced data)
        updateProgress("Generating Insights", 0.96)
        let insights = extractKeyInsights(
            doubleTexting: doubleTexting,
            responseTimes: responseTimes,
            engagement: engagement,
            positivity: positivity,
            advanced: advancedAnalysis
        )
        let recommendations = generateRecommendations(
            toxicity: toxicity,
            engagement: engagement,
            positivity: positivity,
            advanced: advancedAnalysis
        )

        // Generate comprehensive summary
        let summary = generateComprehensiveSummary(
            sentiment: sentiment,
            toxicity: toxicity,
            engagement: engagement,
            positivity: positivity,
            doubleTexting: doubleTexting,
            advanced: advancedAnalysis
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
            advancedAnalysis: advancedAnalysis,
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
            advancedAnalysis: nil,
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
        doubleTexting: DoubleTextingAnalysis,
        advanced: AdvancedAnalysis
    ) -> String {
        var sections: [String] = []

        // Overall health
        sections.append("Overall Relationship Health: \(positivity.health.rawValue.uppercased()) (\(positivity.score)/100)")
        sections.append(positivity.summary)

        // Sentiment
        sections.append("\nSentiment Profile: \(sentiment.sentiment.rawValue.uppercased())")
        sections.append(sentiment.summary)

        // Advanced Insights
        if let attachment = advanced.attachmentStyle {
            sections.append("\nAttachment Styles: You: \(attachment.you.rawValue), Them: \(attachment.them.rawValue)")
        }

        if let loveLanguages = advanced.loveLanguages {
            sections.append("\nTop Love Language: \(loveLanguages.you.first?.rawValue.replacingOccurrences(of: "_", with: " ").capitalized ?? "Unknown")")
        }

        if let redFlags = advanced.redFlags, redFlags.detected {
            sections.append("\n⚠️ Warning: \(redFlags.totalFlags) red flags detected in \(redFlags.severity.rawValue) severity")
        }

        if let greenFlags = advanced.greenFlags {
            sections.append("\n✅ Positive Signs: \(greenFlags.totalFlags) green flags detected")
        }

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

        // Interest Level
        if let interest = advanced.interestLevel {
            sections.append("\nInterest Level: You: \(interest.you.score)/100, Them: \(interest.them.score)/100")
        }

        // Growth Potential
        if let growth = advanced.growthMindset {
            sections.append("\nGrowth Mindset: \(growth.overallGrowth)/100")
        }

        return sections.joined(separator: "\n")
    }

    // MARK: - Insights Extraction

    private func extractKeyInsights(
        doubleTexting: DoubleTextingAnalysis,
        responseTimes: ResponseTimeAnalysis,
        engagement: EngagementAnalysis,
        positivity: PositivityIndex,
        advanced: AdvancedAnalysis
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

        // Red flags insight
        if let redFlags = advanced.redFlags, redFlags.detected {
            insights.append(GreyMirrorReport.KeyInsight(
                category: "Red Flags",
                insight: "\(redFlags.totalFlags) concerning patterns detected: \(redFlags.detectedFlags.prefix(3).joined(separator: ", "))",
                importance: redFlags.severity == .severe || redFlags.severity == .high ? "high" : "medium"
            ))
        }

        // Green flags insight
        if let greenFlags = advanced.greenFlags, greenFlags.totalFlags > 5 {
            insights.append(GreyMirrorReport.KeyInsight(
                category: "Positive Signs",
                insight: "Strong positive indicators: \(greenFlags.detectedFlags.prefix(3).joined(separator: ", "))",
                importance: "low"
            ))
        }

        // Attachment style insight
        if let attachment = advanced.attachmentStyle {
            if attachment.compatibility < 50 {
                insights.append(GreyMirrorReport.KeyInsight(
                    category: "Attachment",
                    insight: "Attachment styles may create friction (You: \(attachment.you.rawValue), Them: \(attachment.them.rawValue))",
                    importance: "medium"
                ))
            }
        }

        // Interest imbalance
        if let interest = advanced.interestLevel {
            let diff = abs(interest.you.score - interest.them.score)
            if diff > 30 {
                let moreInterested = interest.you.score > interest.them.score ? "You" : "They"
                insights.append(GreyMirrorReport.KeyInsight(
                    category: "Interest Level",
                    insight: "\(moreInterested) show significantly higher interest (\(diff) point difference)",
                    importance: "high"
                ))
            }
        }

        // Ghosting risk
        if let ghosting = advanced.ghostingRisk, ghosting.riskLevel == .high || ghosting.riskLevel == .critical {
            insights.append(GreyMirrorReport.KeyInsight(
                category: "Ghosting Risk",
                insight: "Warning: Signs suggest risk of fading interest - \(ghosting.warningSignsFromThem.first ?? "decreasing engagement")",
                importance: "high"
            ))
        }

        // Trust issues
        if let trust = advanced.trust, trust.overallTrust < 40 {
            insights.append(GreyMirrorReport.KeyInsight(
                category: "Trust",
                insight: "Trust levels appear low - consider addressing communication barriers",
                importance: "high"
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
        positivity: PositivityIndex,
        advanced: AdvancedAnalysis
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

        // Red flags recommendation
        if let redFlags = advanced.redFlags, redFlags.severity == .severe || redFlags.severity == .high {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "high",
                action: "Evaluate Red Flags",
                details: "Serious concerns detected. Consider discussing boundaries or seeking outside perspective on these patterns."
            ))
        }

        // Attachment style recommendation
        if let attachment = advanced.attachmentStyle, attachment.compatibility < 40 {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "medium",
                action: "Understand Attachment Styles",
                details: "Your attachment styles may clash. Learning about each other's needs can improve communication."
            ))
        }

        // Ghosting risk recommendation
        if let ghosting = advanced.ghostingRisk, ghosting.riskLevel == .high || ghosting.riskLevel == .critical {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "high",
                action: "Address Declining Interest",
                details: "Signs suggest potential fading interest. Consider having an honest conversation about the relationship's direction."
            ))
        }

        // Initiation balance recommendation
        if let initiation = advanced.initiationBalance, initiation.balance < 30 {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "medium",
                action: "Balance Initiation",
                details: "One person initiates significantly more. \(initiation.pattern). Consider a more balanced approach."
            ))
        }

        // Support quality recommendation
        if let support = advanced.supportQuality, !support.mutualSupport {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "medium",
                action: "Improve Mutual Support",
                details: "Emotional support appears one-sided. Practice active listening and validation."
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

        // Love languages recommendation
        if let languages = advanced.loveLanguages {
            if let topLanguage = languages.you.first {
                recommendations.append(GreyMirrorReport.Recommendation(
                    priority: "low",
                    action: "Speak Their Love Language",
                    details: "Consider expressing care through their preferred love language: \(topLanguage.rawValue.replacingOccurrences(of: "_", with: " "))."
                ))
            }
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

        // Growth mindset recommendation
        if let growth = advanced.growthMindset, growth.overallGrowth > 60 {
            recommendations.append(GreyMirrorReport.Recommendation(
                priority: "low",
                action: "Keep Growing Together",
                details: "Great growth mindset detected! Continue learning and evolving together."
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
