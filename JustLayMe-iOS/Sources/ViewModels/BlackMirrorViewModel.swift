import Foundation
import Combine
import UniformTypeIdentifiers

// MARK: - Black Mirror ViewModel
@MainActor
final class BlackMirrorViewModel: ObservableObject {
    // MARK: - Published Properties

    // Upload State
    @Published var inputText = ""
    @Published var uploadMethod: AnalysisMethod = .paste
    @Published var isAnalyzing = false
    @Published var uploadProgress: Double = 0

    // Personalization
    @Published var userName = "You"
    @Published var contactName = "Them"
    @Published var insightsGoal = ""

    // Results
    @Published var analysisReport: BlackMirrorReport?
    @Published var expandedMetrics: Set<String> = []

    // Errors
    @Published var errorMessage: String?
    @Published var showError = false

    // Export
    @Published var isExporting = false
    @Published var showExportOptions = false

    // MARK: - Services
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var hasResults: Bool {
        analysisReport?.success == true
    }

    var healthScore: Int {
        analysisReport?.healthScore ?? analysisReport?.metrics?.positivity?.score ?? 0
    }

    var healthLabel: String {
        analysisReport?.healthLabel ?? analysisReport?.metrics?.positivity?.health ?? "Unknown"
    }

    var healthColor: String {
        switch healthLabel.lowercased() {
        case "healthy": return "green"
        case "moderate": return "yellow"
        case "concerning": return "red"
        default: return "gray"
        }
    }

    var canAnalyze: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    var metricCards: [MetricCard] {
        analysisReport?.metricCards ?? buildMetricCards()
    }

    // MARK: - Analysis
    func startAnalysis() async {
        guard canAnalyze else { return }

        isAnalyzing = true
        uploadProgress = 0
        errorMessage = nil

        do {
            // Run client-side ML analysis (would need to port ML code to Swift)
            // For now, we'll send to backend for processing
            let report = try await performAnalysis()

            analysisReport = report
            isAnalyzing = false
            uploadProgress = 100

        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
            showError = true
            isAnalyzing = false
        }
    }

    private func performAnalysis() async throws -> BlackMirrorReport {
        // Simulate progress updates
        for progress in stride(from: 10, through: 90, by: 10) {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            uploadProgress = Double(progress)
        }

        // In production, this would:
        // 1. Either run ML locally using CoreML
        // 2. Or send to backend API endpoint

        // For now, parse messages locally and create mock analysis
        let messages = parseMessages(from: inputText)

        guard messages.count >= 2 else {
            throw AnalysisError.insufficientData
        }

        return createLocalAnalysis(from: messages)
    }

    // MARK: - Message Parsing
    private func parseMessages(from text: String) -> [ParsedMessage] {
        var messages: [ParsedMessage] = []
        let lines = text.components(separatedBy: .newlines)

        // Common message formats:
        // iOS: "[12/25/23, 3:45:22 PM] John: Hello"
        // WhatsApp: "12/25/23, 3:45 PM - John: Hello"
        // Generic: "John: Hello"

        let patterns = [
            // iOS Messages format
            #"\[(\d{1,2}/\d{1,2}/\d{2,4}),?\s*(\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?)\]\s*([^:]+):\s*(.+)"#,
            // WhatsApp format
            #"(\d{1,2}/\d{1,2}/\d{2,4}),?\s*(\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?)\s*-\s*([^:]+):\s*(.+)"#,
            // Simple format
            #"([^:]+):\s*(.+)"#
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            var matched = false
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) {

                    if match.numberOfRanges >= 3 {
                        let senderRange = Range(match.range(at: match.numberOfRanges - 2), in: trimmed)!
                        let contentRange = Range(match.range(at: match.numberOfRanges - 1), in: trimmed)!

                        let sender = String(trimmed[senderRange]).trimmingCharacters(in: .whitespaces)
                        let content = String(trimmed[contentRange]).trimmingCharacters(in: .whitespaces)

                        messages.append(ParsedMessage(
                            sender: sender,
                            content: content,
                            timestamp: Date(), // Would parse from regex groups 1-2 if available
                            isUser: sender.lowercased() == userName.lowercased()
                        ))
                        matched = true
                        break
                    }
                }
            }

            // If no pattern matched, try to infer
            if !matched && !trimmed.isEmpty {
                // Alternate between senders for unparsed messages
                let isUser = messages.count % 2 == 0
                messages.append(ParsedMessage(
                    sender: isUser ? userName : contactName,
                    content: trimmed,
                    timestamp: Date(),
                    isUser: isUser
                ))
            }
        }

        return messages
    }

    private func createLocalAnalysis(from messages: [ParsedMessage]) -> BlackMirrorReport {
        let userMessages = messages.filter { $0.isUser }
        let theirMessages = messages.filter { !$0.isUser }

        // Basic sentiment analysis
        let positiveWords = Set(["love", "happy", "great", "amazing", "wonderful", "thanks", "thank", "good", "nice", "awesome", "❤️", "😊", "😍", "🥰"])
        let negativeWords = Set(["hate", "angry", "sad", "bad", "terrible", "sorry", "upset", "mad", "annoyed", "😢", "😠", "😡"])

        var positiveCount = 0
        var negativeCount = 0

        for message in messages {
            let words = message.content.lowercased().components(separatedBy: .whitespaces)
            for word in words {
                if positiveWords.contains(word) { positiveCount += 1 }
                if negativeWords.contains(word) { negativeCount += 1 }
            }
        }

        let totalSentimentWords = max(positiveCount + negativeCount, 1)
        let positivityScore = Int((Double(positiveCount) / Double(totalSentimentWords)) * 100)

        let healthLabel: String
        if positivityScore >= 70 {
            healthLabel = "Healthy"
        } else if positivityScore >= 40 {
            healthLabel = "Moderate"
        } else {
            healthLabel = "Concerning"
        }

        // Build stats
        let stats = ConversationStats(
            totalMessages: messages.count,
            yourMessages: userMessages.count,
            theirMessages: theirMessages.count,
            dateRange: nil,
            participants: [userName, contactName]
        )

        // Build metrics
        let sentiment = SentimentAnalysis(
            sentiment: positivityScore >= 50 ? "positive" : "negative",
            score: Double(positivityScore) / 100.0,
            summary: "Overall sentiment is \(positivityScore >= 50 ? "positive" : "negative") with a score of \(positivityScore)%",
            data: SentimentAnalysis.SentimentData(
                positive: Double(positiveCount),
                negative: Double(negativeCount),
                neutral: Double(messages.count - positiveCount - negativeCount)
            )
        )

        let engagement = EngagementAnalysis(
            summary: "Engagement levels appear \(userMessages.count > theirMessages.count ? "higher from you" : "balanced")",
            overallScore: Double(min(100, messages.count * 2)),
            yourEngagement: Double(userMessages.count) / Double(max(messages.count, 1)) * 100,
            theirEngagement: Double(theirMessages.count) / Double(max(messages.count, 1)) * 100,
            questionRatio: nil,
            emojiUsage: nil
        )

        let positivity = PositivityAnalysis(
            summary: "Your conversation has a \(healthLabel.lowercased()) positivity level",
            score: positivityScore,
            health: healthLabel.lowercased(),
            yourPositivity: nil,
            theirPositivity: nil
        )

        let metrics = AnalysisMetrics(
            sentiment: sentiment,
            sentimentComparison: nil,
            communicationPatterns: nil,
            doubleTexting: nil,
            streakTiming: nil,
            weekdayWeekend: nil,
            responseTimes: nil,
            callbacks: nil,
            toxicity: nil,
            engagement: engagement,
            positivity: positivity,
            apologyPatterns: nil
        )

        return BlackMirrorReport(
            success: true,
            timestamp: Date(),
            stats: stats,
            metrics: metrics,
            summary: "Analysis complete! Found \(messages.count) messages between \(userName) and \(contactName).",
            insights: [
                "Message balance: \(userMessages.count) from you, \(theirMessages.count) from them",
                "Sentiment: \(positivityScore)% positive"
            ],
            recommendations: positivityScore < 50 ? [
                "Consider more positive language",
                "Try to balance conversation initiation"
            ] : [
                "Keep up the positive communication!",
                "Your conversation appears healthy"
            ],
            error: nil,
            messageCount: messages.count,
            healthScore: positivityScore,
            healthLabel: healthLabel,
            metricCards: nil
        )
    }

    // MARK: - Metric Expansion
    func toggleMetric(_ metricId: String) {
        if expandedMetrics.contains(metricId) {
            expandedMetrics.remove(metricId)
        } else {
            expandedMetrics.insert(metricId)
        }
    }

    func isMetricExpanded(_ metricId: String) -> Bool {
        expandedMetrics.contains(metricId)
    }

    // MARK: - Build UI Cards
    private func buildMetricCards() -> [MetricCard] {
        guard let metrics = analysisReport?.metrics else { return [] }

        var cards: [MetricCard] = []

        if let positivity = metrics.positivity {
            cards.append(MetricCard(
                metricId: MetricType.healthScore.rawValue,
                title: "Relationship Health",
                icon: "heart.fill",
                value: "\(positivity.score)%",
                subtitle: positivity.health.capitalized,
                color: positivity.health == "healthy" ? "green" : (positivity.health == "moderate" ? "yellow" : "red"),
                summary: positivity.summary,
                isExpanded: false,
                chartData: nil
            ))
        }

        if let sentiment = metrics.sentiment {
            cards.append(MetricCard(
                metricId: MetricType.sentiment.rawValue,
                title: "Sentiment",
                icon: "face.smiling",
                value: sentiment.sentiment.capitalized,
                subtitle: sentiment.score.map { "\(Int($0 * 100))%" },
                color: sentiment.sentiment == "positive" ? "green" : "orange",
                summary: sentiment.summary,
                isExpanded: false,
                chartData: nil
            ))
        }

        if let engagement = metrics.engagement {
            cards.append(MetricCard(
                metricId: MetricType.engagement.rawValue,
                title: "Engagement",
                icon: "chart.bar.fill",
                value: engagement.overallScore.map { "\(Int($0))%" } ?? "N/A",
                subtitle: "Overall engagement",
                color: "blue",
                summary: engagement.summary,
                isExpanded: false,
                chartData: nil
            ))
        }

        return cards
    }

    // MARK: - Clear Results
    func clearResults() {
        analysisReport = nil
        inputText = ""
        uploadProgress = 0
        expandedMetrics.removeAll()
    }

    // MARK: - Export
    func exportResults() {
        showExportOptions = true
    }

    func getExportJSON() -> String? {
        guard let report = analysisReport else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(report) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}

// MARK: - Supporting Types
struct ParsedMessage {
    let sender: String
    let content: String
    let timestamp: Date
    let isUser: Bool
}

enum AnalysisError: LocalizedError {
    case insufficientData
    case parsingFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Need at least 2 messages for analysis"
        case .parsingFailed:
            return "Could not parse message format"
        case .networkError:
            return "Network error occurred"
        }
    }
}
