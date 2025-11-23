// GreyMirror/Services/ML/Classifiers.swift
// Individual ML classifiers matching the web implementation

import Foundation

// MARK: - Sentiment Analyzer

final class SentimentAnalyzer {

    private let positiveKeywords = SentimentKeywords.positive
    private let negativeKeywords = SentimentKeywords.negative
    private let positiveEmoji = ["😊", "😄", "😍", "❤️", "👍", "🎉", "💯", "✨", "🔥", "😘", "🥰", "💕", "💖"]
    private let negativeEmoji = ["😢", "😞", "😡", "😠", "💔", "👎", "😒", "🙄", "😤", "😭", "😫", "😩"]

    func analyzeSentiment(_ messages: [ParsedMessage]) -> SentimentAnalysis {
        guard !messages.isEmpty else {
            return SentimentAnalysis(
                overallScore: 0,
                sentiment: .neutral,
                confidence: 0,
                breakdown: SentimentAnalysis.SentimentBreakdown(
                    positive: 0, negative: 0, neutral: 0,
                    percentages: .init(positive: 0, negative: 0, neutral: 0)
                ),
                emotionalIntensity: .init(average: 0, max: 0, level: "low"),
                summary: "No messages to analyze"
            )
        }

        var positiveCount = 0
        var negativeCount = 0
        var neutralCount = 0
        var totalScore: Double = 0

        for message in messages {
            let score = analyzeSingleMessage(message)
            totalScore += score

            if score > 0.15 {
                positiveCount += 1
            } else if score < -0.15 {
                negativeCount += 1
            } else {
                neutralCount += 1
            }
        }

        let averageScore = totalScore / Double(messages.count)
        let total = Double(messages.count)

        let sentiment: SentimentAnalysis.SentimentLevel
        if averageScore > 0.2 {
            sentiment = .positive
        } else if averageScore < -0.2 {
            sentiment = .negative
        } else {
            sentiment = .neutral
        }

        let dominant = max(positiveCount, negativeCount, neutralCount)
        let confidence = Double(dominant) / total * 100

        return SentimentAnalysis(
            overallScore: averageScore,
            sentiment: sentiment,
            confidence: confidence,
            breakdown: SentimentAnalysis.SentimentBreakdown(
                positive: positiveCount,
                negative: negativeCount,
                neutral: neutralCount,
                percentages: .init(
                    positive: Double(positiveCount) / total * 100,
                    negative: Double(negativeCount) / total * 100,
                    neutral: Double(neutralCount) / total * 100
                )
            ),
            emotionalIntensity: .init(average: abs(averageScore), max: 1.0, level: abs(averageScore) > 0.6 ? "high" : abs(averageScore) > 0.3 ? "moderate" : "low"),
            summary: generateSentimentSummary(sentiment, averageScore, positiveCount, negativeCount, messages.count)
        )
    }

    private func analyzeSingleMessage(_ message: ParsedMessage) -> Double {
        let text = message.content.lowercased()
        var score: Double = 0

        // Check positive keywords
        for keyword in positiveKeywords.strong {
            if text.contains(keyword) { score += 0.6 }
        }
        for keyword in positiveKeywords.moderate {
            if text.contains(keyword) { score += 0.35 }
        }
        for keyword in positiveKeywords.weak {
            if text.contains(keyword) { score += 0.15 }
        }

        // Check negative keywords
        for keyword in negativeKeywords.strong {
            if text.contains(keyword) { score -= 0.6 }
        }
        for keyword in negativeKeywords.moderate {
            if text.contains(keyword) { score -= 0.35 }
        }
        for keyword in negativeKeywords.mild {
            if text.contains(keyword) { score -= 0.15 }
        }

        // Check emoji
        for emoji in positiveEmoji {
            if message.content.contains(emoji) { score += 0.3 }
        }
        for emoji in negativeEmoji {
            if message.content.contains(emoji) { score -= 0.3 }
        }

        // Questions show engagement
        let questionCount = message.content.filter { $0 == "?" }.count
        score += Double(min(questionCount, 3)) * 0.12

        return max(-1, min(1, score))
    }

    private func generateSentimentSummary(_ sentiment: SentimentAnalysis.SentimentLevel, _ score: Double, _ positive: Int, _ negative: Int, _ total: Int) -> String {
        switch sentiment {
        case .positive:
            return "Overall positive sentiment (\(positive)/\(total) messages). Shows warmth and positive emotion."
        case .negative:
            return "Overall negative sentiment (\(negative)/\(total) messages). Shows frustration or dissatisfaction."
        case .neutral:
            return "Overall neutral sentiment. Mix of \(positive) positive, \(negative) negative messages. Balanced communication style."
        }
    }

    func compareSentiment(_ messages: [ParsedMessage]) -> SentimentComparison {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        guard !sent.isEmpty && !received.isEmpty else {
            return SentimentComparison(
                youSentiment: .init(score: 0, sentiment: "neutral", messageCount: sent.count),
                themSentiment: .init(score: 0, sentiment: "neutral", messageCount: received.count),
                difference: 0,
                morePositive: "equal",
                summary: "Need messages from both parties"
            )
        }

        let sentAnalysis = analyzeSentiment(sent)
        let receivedAnalysis = analyzeSentiment(received)

        let diff = sentAnalysis.overallScore - receivedAnalysis.overallScore
        let morePositive = diff > 0.1 ? "you" : diff < -0.1 ? "them" : "balanced"

        return SentimentComparison(
            youSentiment: .init(score: sentAnalysis.overallScore, sentiment: sentAnalysis.sentiment.rawValue, messageCount: sent.count),
            themSentiment: .init(score: receivedAnalysis.overallScore, sentiment: receivedAnalysis.sentiment.rawValue, messageCount: received.count),
            difference: diff,
            morePositive: morePositive,
            summary: morePositive == "balanced" ? "Both show similar sentiment" : "\(morePositive == "you" ? "You" : "They") show more positive sentiment"
        )
    }
}

// MARK: - Toxicity Classifier

final class ToxicityClassifier {

    private let severeKeywords = ["kill yourself", "kys", "go die", "worthless", "piece of shit"]
    private let strongKeywords = ["hate you", "fuck you", "fuck off", "idiot", "stupid", "moron", "asshole", "bitch", "shut up"]
    private let moderateKeywords = ["hate", "horrible", "terrible", "annoyed", "pissed", "sick of", "done with"]
    private let gaslightingPatterns = ["you're crazy", "that never happened", "you're overreacting", "you're too sensitive", "you always", "you never"]

    func classifyToxicity(_ messages: [ParsedMessage]) -> ToxicityAnalysis {
        guard !messages.isEmpty else {
            return ToxicityAnalysis(
                overallToxicity: 0, level: .none, hasToxicity: false, toxicMessages: 0, toxicityPercentage: 0,
                you: .init(toxicity: 0, toxicMessages: 0),
                them: .init(toxicity: 0, toxicMessages: 0),
                topConcerns: [], summary: "No messages to analyze"
            )
        }

        var toxicCount = 0
        var totalScore: Double = 0
        var yourToxicity: Double = 0
        var yourToxicCount = 0
        var theirToxicity: Double = 0
        var theirToxicCount = 0
        var concerns: [String: Int] = [:]

        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        for message in messages {
            let (score, indicators) = scoreToxicity(message)
            totalScore += score

            if score > 0.25 {
                toxicCount += 1
                if message.direction == .sent {
                    yourToxicCount += 1
                    yourToxicity += score
                } else {
                    theirToxicCount += 1
                    theirToxicity += score
                }
            }

            for indicator in indicators {
                concerns[indicator, default: 0] += 1
            }
        }

        let avgToxicity = totalScore / Double(messages.count)
        let level = determineToxicityLevel(avgToxicity, toxicCount, messages.count)

        let yourAvg = sent.isEmpty ? 0 : yourToxicity / Double(sent.count)
        let theirAvg = received.isEmpty ? 0 : theirToxicity / Double(received.count)

        let topConcerns = concerns.sorted { $0.value > $1.value }.prefix(5).map {
            ToxicityAnalysis.ToxicityConcern(concern: $0.key, count: $0.value)
        }

        return ToxicityAnalysis(
            overallToxicity: avgToxicity,
            level: level,
            hasToxicity: toxicCount > 0,
            toxicMessages: toxicCount,
            toxicityPercentage: Double(toxicCount) / Double(messages.count) * 100,
            you: .init(toxicity: yourAvg, toxicMessages: yourToxicCount),
            them: .init(toxicity: theirAvg, toxicMessages: theirToxicCount),
            topConcerns: Array(topConcerns),
            summary: generateToxicitySummary(avgToxicity, yourAvg, theirAvg)
        )
    }

    private func scoreToxicity(_ message: ParsedMessage) -> (Double, [String]) {
        let text = message.content.lowercased()
        var score: Double = 0
        var indicators: [String] = []

        for keyword in severeKeywords {
            if text.contains(keyword) {
                score += 1.0
                indicators.append("severe: \(keyword)")
            }
        }

        for keyword in strongKeywords {
            if text.contains(keyword) {
                score += 0.7
                indicators.append("strong: \(keyword)")
            }
        }

        for keyword in moderateKeywords {
            if text.contains(keyword) {
                score += 0.4
                indicators.append("moderate: \(keyword)")
            }
        }

        for pattern in gaslightingPatterns {
            if text.contains(pattern) {
                score += 0.8
                indicators.append("gaslighting: \(pattern)")
            }
        }

        return (min(1, score), indicators)
    }

    private func determineToxicityLevel(_ average: Double, _ count: Int, _ total: Int) -> ToxicityAnalysis.ToxicityLevel {
        let percentage = Double(count) / Double(total) * 100
        if average < 0.1 || percentage < 5 { return .none }
        if average < 0.3 || percentage < 15 { return .low }
        if average < 0.5 || percentage < 30 { return .moderate }
        if average < 0.7 || percentage < 50 { return .high }
        return .severe
    }

    private func generateToxicitySummary(_ avg: Double, _ yours: Double, _ theirs: Double) -> String {
        var parts: [String] = []
        if avg == 0 {
            parts.append("No toxic language detected - healthy communication")
        } else if avg < 0.3 {
            parts.append("Minimal toxicity - mostly respectful conversation")
        } else if avg < 0.5 {
            parts.append("Moderate toxicity detected - some hostile language")
        } else {
            parts.append("High toxicity detected - significant conflict in language")
        }

        if yours > theirs {
            parts.append("You use more toxic language")
        } else if theirs > yours {
            parts.append("They use more toxic language")
        }

        return parts.joined(separator: ". ")
    }
}

// MARK: - Engagement Scorer

final class EngagementScorer {

    func scoreEngagement(_ messages: [ParsedMessage]) -> EngagementAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourEngagement = calculateEngagementScore(sent)
        let theirEngagement = calculateEngagementScore(received)

        let overallScore = (yourEngagement.score + theirEngagement.score) / 2
        let level = getEngagementLevel(overallScore)

        let moreEngaged = yourEngagement.score > theirEngagement.score ? "you" :
                          yourEngagement.score < theirEngagement.score ? "them" : "equal"

        return EngagementAnalysis(
            overallScore: overallScore,
            level: level,
            you: yourEngagement,
            them: theirEngagement,
            comparison: .init(
                moreEngaged: moreEngaged,
                difference: abs(yourEngagement.score - theirEngagement.score),
                interpretation: moreEngaged == "equal" ? "Both show similar engagement" : "\(moreEngaged == "you" ? "You" : "They") are more engaged"
            ),
            drivers: .init(
                yourTopDrivers: yourEngagement.drivers.prefix(2).map { $0.name },
                theirTopDrivers: theirEngagement.drivers.prefix(2).map { $0.name },
                sharedDrivers: []
            ),
            summary: generateEngagementSummary(yourEngagement, theirEngagement)
        )
    }

    private func calculateEngagementScore(_ messages: [ParsedMessage]) -> EngagementAnalysis.PersonEngagement {
        guard !messages.isEmpty else {
            return .init(score: 0, level: "none", messageCount: 0, drivers: [])
        }

        var score = 0
        var drivers: [EngagementAnalysis.PersonEngagement.Driver] = []

        // Questions (20 points max)
        let questionCount = messages.filter { $0.content.contains("?") }.count
        let questionScore = min(Double(questionCount) / Double(messages.count) * 20, 20)
        if questionCount > 0 {
            drivers.append(.init(name: "Questions", value: questionCount, score: questionScore))
        }

        // Emoji (15 points max)
        let emojiPattern = try! NSRegularExpression(pattern: "[\\u{1F300}-\\u{1F9FF}]", options: [])
        let emojiCount = messages.filter { msg in
            emojiPattern.firstMatch(in: msg.content, range: NSRange(msg.content.startIndex..., in: msg.content)) != nil
        }.count
        let emojiScore = min(Double(emojiCount) / Double(messages.count) * 15, 15)
        if emojiCount > 0 {
            drivers.append(.init(name: "Emoji usage", value: emojiCount, score: emojiScore))
        }

        // Message depth (15 points max)
        let avgLength = messages.reduce(0) { $0 + $1.length } / messages.count
        let depthScore = min(Double(avgLength) / 100 * 15, 15)
        if avgLength > 20 {
            drivers.append(.init(name: "Message depth", value: avgLength, score: depthScore))
        }

        // Enthusiasm - exclamation marks (10 points max)
        let exclamationCount = messages.reduce(0) { $0 + $1.content.filter { $0 == "!" }.count }
        let enthusiasmScore = min(Double(exclamationCount) / Double(messages.count) * 10, 10)
        if exclamationCount > 0 {
            drivers.append(.init(name: "Enthusiasm", value: exclamationCount, score: enthusiasmScore))
        }

        score = Int(questionScore + emojiScore + depthScore + enthusiasmScore)

        return .init(
            score: min(100, score),
            level: getEngagementLevel(score).rawValue,
            messageCount: messages.count,
            drivers: drivers.sorted { $0.score > $1.score }
        )
    }

    private func getEngagementLevel(_ score: Int) -> EngagementAnalysis.EngagementLevel {
        if score < 20 { return .minimal }
        if score < 40 { return .low }
        if score < 60 { return .moderate }
        if score < 80 { return .high }
        return .very_high
    }

    private func generateEngagementSummary(_ yours: EngagementAnalysis.PersonEngagement, _ theirs: EngagementAnalysis.PersonEngagement) -> String {
        var parts: [String] = []

        if yours.score > 70 {
            parts.append("You show very high emotional engagement")
        } else if yours.score > 50 {
            parts.append("You show moderate engagement")
        } else {
            parts.append("You show low engagement")
        }

        if theirs.score > 70 {
            parts.append("They show very high emotional engagement")
        } else if theirs.score > 50 {
            parts.append("They show moderate engagement")
        } else {
            parts.append("They show low engagement")
        }

        return parts.joined(separator: ". ")
    }
}

// MARK: - Double Texting Detector

final class DoubleTextingDetector {

    func detectDoubleTexting(_ messages: [ParsedMessage]) -> DoubleTextingAnalysis {
        guard messages.count >= 2 else {
            return emptyResult()
        }

        let streaks = findMessageStreaks(messages)
        let yourStreaks = streaks.filter { $0.direction == .sent }
        let theirStreaks = streaks.filter { $0.direction == .received }

        let yourStats = calculateStats(yourStreaks, messages.filter { $0.direction == .sent })
        let theirStats = calculateStats(theirStreaks, messages.filter { $0.direction == .received })

        let yourInvestment = calculateInvestmentScore(yourStreaks, messages)
        let theirInvestment = calculateInvestmentScore(theirStreaks, messages)

        let moreInvested = yourInvestment > theirInvestment ? "you" :
                          yourInvestment < theirInvestment ? "them" : "equal"

        return DoubleTextingAnalysis(
            hasDoubleTexts: yourStats.doubleTexts > 0 || theirStats.doubleTexts > 0,
            totalDoubleTexts: yourStats.doubleTexts + theirStats.doubleTexts,
            totalTripleTexts: yourStats.tripleTexts + theirStats.tripleTexts,
            totalQuadPlusTexts: yourStats.quadPlusTexts + theirStats.quadPlusTexts,
            you: yourStats,
            them: theirStats,
            comparison: .init(
                moreInvested: moreInvested,
                difference: abs(yourInvestment - theirInvestment),
                interpretation: compareInvestment(yourInvestment, theirInvestment),
                whoDoubleTextsMore: yourStats.doubleTexts > theirStats.doubleTexts ? "you" : theirStats.doubleTexts > yourStats.doubleTexts ? "them" : "equal",
                whoTripleTextsMore: yourStats.tripleTexts > theirStats.tripleTexts ? "you" : theirStats.tripleTexts > yourStats.tripleTexts ? "them" : "equal",
                doubleTextRatio: .init(
                    you: yourStats.doubleTexts + theirStats.doubleTexts > 0 ? yourStats.doubleTexts * 100 / max(1, yourStats.doubleTexts + theirStats.doubleTexts) : 0,
                    them: yourStats.doubleTexts + theirStats.doubleTexts > 0 ? theirStats.doubleTexts * 100 / max(1, yourStats.doubleTexts + theirStats.doubleTexts) : 0
                ),
                streakLengthDifference: abs(yourStats.longestStreak - theirStats.longestStreak),
                whoHasLongerStreaks: yourStats.longestStreak > theirStats.longestStreak ? "you" : theirStats.longestStreak > yourStats.longestStreak ? "them" : "equal"
            ),
            analysis: generateAnalysis(yourStats, theirStats, yourInvestment, theirInvestment),
            summary: generateSummary(yourStats, theirStats, yourInvestment, theirInvestment)
        )
    }

    private struct Streak {
        let direction: ParsedMessage.MessageDirection
        let length: Int
        let startIndex: Int
        let endIndex: Int
    }

    private func findMessageStreaks(_ messages: [ParsedMessage]) -> [Streak] {
        var streaks: [Streak] = []
        var currentStart = 0
        var currentLength = 1

        for i in 1..<messages.count {
            if messages[i].direction == messages[i-1].direction {
                currentLength += 1
            } else {
                if currentLength > 1 {
                    streaks.append(Streak(
                        direction: messages[i-1].direction,
                        length: currentLength,
                        startIndex: currentStart,
                        endIndex: i - 1
                    ))
                }
                currentStart = i
                currentLength = 1
            }
        }

        if currentLength > 1 {
            streaks.append(Streak(
                direction: messages.last!.direction,
                length: currentLength,
                startIndex: currentStart,
                endIndex: messages.count - 1
            ))
        }

        return streaks
    }

    private func calculateStats(_ streaks: [Streak], _ messages: [ParsedMessage]) -> DoubleTextingAnalysis.PersonDoubleTexting {
        let doubleTexts = streaks.filter { $0.length >= 2 }.count
        let tripleTexts = streaks.filter { $0.length >= 3 }.count
        let quadPlusTexts = streaks.filter { $0.length >= 4 }.count
        let longestStreak = streaks.map { $0.length }.max() ?? 0
        let avgLength = streaks.isEmpty ? 0 : Double(streaks.reduce(0) { $0 + $1.length }) / Double(streaks.count)
        let totalStreakMessages = streaks.reduce(0) { $0 + $1.length }
        let doubleTextRate = messages.isEmpty ? 0 : Double(totalStreakMessages) / Double(messages.count) * 100

        return .init(
            doubleTexts: doubleTexts,
            tripleTexts: tripleTexts,
            quadPlusTexts: quadPlusTexts,
            longestStreak: longestStreak,
            averageStreakLength: avgLength,
            totalStreakMessages: totalStreakMessages,
            doubleTextRate: doubleTextRate,
            investmentScore: 0, // Set later
            streakBreakdown: .init(
                double: doubleTexts - tripleTexts,
                triple: tripleTexts - quadPlusTexts,
                quadPlus: quadPlusTexts
            )
        )
    }

    private func calculateInvestmentScore(_ streaks: [Streak], _ messages: [ParsedMessage]) -> Int {
        guard !streaks.isEmpty else { return 0 }

        var score = 0
        let doubleTexts = streaks.filter { $0.length >= 2 }.count
        let tripleTexts = streaks.filter { $0.length >= 3 }.count
        let longStreaks = streaks.filter { $0.length >= 4 }.count

        score += min(doubleTexts * 5, 30)
        score += min(tripleTexts * 8, 25)
        score += min(longStreaks * 5, 20)

        let frequency = Double(doubleTexts) / Double(messages.count)
        score += min(Int(frequency * 100), 25)

        return min(100, score)
    }

    private func compareInvestment(_ yours: Int, _ theirs: Int) -> String {
        let diff = abs(yours - theirs)
        let more = yours > theirs ? "You" : "They"

        if diff < 10 { return "Both show similar investment levels" }
        if diff < 25 { return "\(more) show slightly more investment" }
        return "\(more) show significantly more investment"
    }

    private func generateAnalysis(_ yours: DoubleTextingAnalysis.PersonDoubleTexting, _ theirs: DoubleTextingAnalysis.PersonDoubleTexting, _ yourScore: Int, _ theirScore: Int) -> String {
        var parts: [String] = []

        if yours.doubleTexts == 0 {
            parts.append("You don't send double texts - measured approach")
        } else if yours.doubleTexts <= 3 {
            parts.append("You occasionally double text - shows some eagerness")
        } else {
            parts.append("You frequently double text - shows high investment")
        }

        if theirs.doubleTexts == 0 {
            parts.append("They don't send double texts - more reserved")
        } else if theirs.doubleTexts <= 3 {
            parts.append("They occasionally double text - casual investment")
        } else {
            parts.append("They frequently double text - shows they're invested")
        }

        return parts.joined(separator: ". ")
    }

    private func generateSummary(_ yours: DoubleTextingAnalysis.PersonDoubleTexting, _ theirs: DoubleTextingAnalysis.PersonDoubleTexting, _ yourScore: Int, _ theirScore: Int) -> String {
        let total = yours.doubleTexts + theirs.doubleTexts
        if total == 0 {
            return "No double texting detected - both maintain measured messaging."
        }

        if yours.doubleTexts > theirs.doubleTexts * 2 {
            return "You double text significantly more (\(yours.doubleTexts) vs \(theirs.doubleTexts))"
        } else if theirs.doubleTexts > yours.doubleTexts * 2 {
            return "They double text significantly more (\(theirs.doubleTexts) vs \(yours.doubleTexts))"
        }
        return "Double texting is balanced (\(yours.doubleTexts) from you, \(theirs.doubleTexts) from them)"
    }

    private func emptyResult() -> DoubleTextingAnalysis {
        let emptyPerson = DoubleTextingAnalysis.PersonDoubleTexting(
            doubleTexts: 0, tripleTexts: 0, quadPlusTexts: 0, longestStreak: 0,
            averageStreakLength: 0, totalStreakMessages: 0, doubleTextRate: 0, investmentScore: 0,
            streakBreakdown: .init(double: 0, triple: 0, quadPlus: 0)
        )
        return DoubleTextingAnalysis(
            hasDoubleTexts: false, totalDoubleTexts: 0, totalTripleTexts: 0, totalQuadPlusTexts: 0,
            you: emptyPerson, them: emptyPerson,
            comparison: .init(
                moreInvested: "equal", difference: 0, interpretation: "Not enough data",
                whoDoubleTextsMore: "equal", whoTripleTextsMore: "equal",
                doubleTextRatio: .init(you: 0, them: 0), streakLengthDifference: 0, whoHasLongerStreaks: "equal"
            ),
            analysis: "Need at least 2 messages", summary: "Not enough data"
        )
    }
}

// MARK: - Response Time Analyzer

final class ResponseTimeAnalyzer {

    func analyzeResponseTimes(_ messages: [ParsedMessage]) -> ResponseTimeAnalysis {
        guard messages.count >= 2 else {
            return emptyResult()
        }

        var yourResponseTimes: [TimeInterval] = []
        var theirResponseTimes: [TimeInterval] = []

        for i in 1..<messages.count {
            if messages[i].direction != messages[i-1].direction {
                let time = messages[i].timestamp.timeIntervalSince(messages[i-1].timestamp)
                if messages[i].direction == .sent {
                    yourResponseTimes.append(time)
                } else {
                    theirResponseTimes.append(time)
                }
            }
        }

        let yourStats = calculateStats(yourResponseTimes)
        let theirStats = calculateStats(theirResponseTimes)

        let faster: String
        let timeDiff: TimeInterval
        let percentDiff: Double

        if let yourAvg = yourStats.averageMs, let theirAvg = theirStats.averageMs {
            if yourAvg < theirAvg {
                faster = "you"
                timeDiff = theirAvg - yourAvg
                percentDiff = timeDiff / max(yourAvg, theirAvg) * 100
            } else if theirAvg < yourAvg {
                faster = "them"
                timeDiff = yourAvg - theirAvg
                percentDiff = timeDiff / max(yourAvg, theirAvg) * 100
            } else {
                faster = "equal"
                timeDiff = 0
                percentDiff = 0
            }
        } else {
            faster = "equal"
            timeDiff = 0
            percentDiff = 0
        }

        return ResponseTimeAnalysis(
            you: yourStats,
            them: theirStats,
            comparison: .init(
                faster: faster,
                timeDifference: formatTime(timeDiff),
                percentDifference: percentDiff,
                interpretation: generateComparison(faster, percentDiff)
            ),
            patterns: [],
            summary: generateSummary(yourStats, theirStats)
        )
    }

    private func calculateStats(_ times: [TimeInterval]) -> ResponseTimeAnalysis.PersonResponseTime {
        guard !times.isEmpty else {
            return .init(count: 0, average: "—", averageMs: 0, median: "—", min: "—", max: "—", consistency: "unknown", averageReadiness: "unknown")
        }

        let sorted = times.sorted()
        let avg = times.reduce(0, +) / Double(times.count)
        let median = sorted[sorted.count / 2]

        let variance = times.reduce(0) { $0 + pow($1 - avg, 2) } / Double(times.count)
        let stdDev = sqrt(variance)
        let cv = avg > 0 ? stdDev / avg : 0

        let consistency: String
        if cv < 0.5 { consistency = "very_consistent" }
        else if cv < 1.0 { consistency = "consistent" }
        else if cv < 2.0 { consistency = "somewhat_variable" }
        else { consistency = "highly_variable" }

        return .init(
            count: times.count,
            average: formatTime(avg),
            averageMs: avg * 1000,
            median: formatTime(median),
            min: formatTime(sorted.first ?? 0),
            max: formatTime(sorted.last ?? 0),
            consistency: consistency,
            averageReadiness: getReadiness(avg)
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86400))d"
    }

    private func getReadiness(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "immediate" }
        if seconds < 300 { return "very_quick" }
        if seconds < 1800 { return "quick" }
        if seconds < 3600 { return "moderate" }
        return "slow"
    }

    private func generateComparison(_ faster: String, _ percent: Double) -> String {
        if faster == "equal" { return "Both respond with similar speed" }
        if percent < 50 { return "\(faster == "you" ? "You" : "They") respond somewhat faster" }
        return "\(faster == "you" ? "You" : "They") respond significantly faster"
    }

    private func generateSummary(_ yours: ResponseTimeAnalysis.PersonResponseTime, _ theirs: ResponseTimeAnalysis.PersonResponseTime) -> String {
        var parts: [String] = []
        if yours.count > 0 {
            parts.append("You respond on average in \(yours.average) (\(yours.averageReadiness))")
        }
        if theirs.count > 0 {
            parts.append("They respond on average in \(theirs.average) (\(theirs.averageReadiness))")
        }
        return parts.joined(separator: ". ")
    }

    private func emptyResult() -> ResponseTimeAnalysis {
        let empty = ResponseTimeAnalysis.PersonResponseTime(count: 0, average: "—", averageMs: 0, median: "—", min: "—", max: "—", consistency: "unknown", averageReadiness: "unknown")
        return ResponseTimeAnalysis(
            you: empty, them: empty,
            comparison: .init(faster: "equal", timeDifference: "—", percentDifference: 0, interpretation: "Need more messages"),
            patterns: [], summary: "Need at least 2 messages"
        )
    }
}

// MARK: - Apology Classifier

final class ApologyClassifier {

    private let explicitApologies = ["sorry", "apologize", "apologies", "my bad", "my mistake", "my fault", "forgive me", "i was wrong", "i messed up"]
    private let softApologies = ["didn't mean to", "wasn't trying to", "i understand why", "that came out wrong", "let me explain"]
    private let reconciliationPhrases = ["can we talk", "let's talk", "i miss you", "i love you", "you're right", "fair enough", "let's move on", "truce"]

    func detectApologyPatterns(_ messages: [ParsedMessage]) -> ApologyAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourApologies = analyzeApologies(sent)
        let theirApologies = analyzeApologies(received)
        let yourReconciliation = analyzeReconciliation(sent)
        let theirReconciliation = analyzeReconciliation(received)

        let total = yourApologies.total + theirApologies.total
        let whoApologizesMore = yourApologies.total > theirApologies.total ? "you" :
                                theirApologies.total > yourApologies.total ? "them" : "equal"

        return ApologyAnalysis(
            hasApologies: total > 0,
            totalApologies: total,
            apologyRatio: .init(
                you: total > 0 ? yourApologies.total * 100 / total : 0,
                them: total > 0 ? theirApologies.total * 100 / total : 0
            ),
            you: yourApologies,
            them: theirApologies,
            comparison: .init(
                whoApologizesMore: whoApologizesMore,
                apologyDifference: abs(yourApologies.total - theirApologies.total),
                balanceScore: calculateBalance(yourApologies.total, theirApologies.total),
                reconciliationBalance: calculateBalance(yourReconciliation, theirReconciliation)
            ),
            reconciliation: .init(totalAttempts: yourReconciliation + theirReconciliation, successRate: 0, averageResolutionTime: 0),
            patterns: [],
            summary: generateSummary(yourApologies, theirApologies, yourReconciliation, theirReconciliation)
        )
    }

    private struct ApologyStats {
        let total: Int
        let explicit: Int
        let soft: Int
        let sincerity: Int
    }

    private func analyzeApologies(_ messages: [ParsedMessage]) -> ApologyAnalysis.PersonApologies {
        var explicit = 0
        var soft = 0
        var totalSincerity = 0
        var reconciliationCount = 0

        for message in messages {
            let text = message.content.lowercased()

            let hasExplicit = explicitApologies.contains { text.contains($0) }
            if hasExplicit {
                explicit += 1
                totalSincerity += calculateSincerity(text)
            }

            let hasSoft = softApologies.contains { text.contains($0) }
            if hasSoft && !hasExplicit {
                soft += 1
                totalSincerity += Int(Double(calculateSincerity(text)) * 0.7)
            }

            if reconciliationPhrases.contains(where: { text.contains($0) }) {
                reconciliationCount += 1
            }
        }

        let total = explicit + soft
        return ApologyAnalysis.PersonApologies(
            totalApologies: total,
            explicitApologies: explicit,
            softApologies: soft,
            apologyPercentage: messages.isEmpty ? 0 : Double(total) / Double(messages.count) * 100,
            averageSincerity: total > 0 ? totalSincerity / total : 0,
            reconciliationAttempts: reconciliationCount,
            firstToApologize: 0
        )
    }

    private func calculateSincerity(_ text: String) -> Int {
        var score = 50
        if text.count > 100 { score += 15 }
        if text.contains("i was wrong") { score += 20 }
        if text.contains("my fault") { score += 15 }
        if text.contains("i promise") { score += 10 }
        if text.contains("but you") { score -= 20 }
        if text.contains("whatever") { score -= 15 }
        return max(0, min(100, score))
    }

    private func analyzeReconciliation(_ messages: [ParsedMessage]) -> Int {
        return messages.filter { msg in
            reconciliationPhrases.contains { msg.content.lowercased().contains($0) }
        }.count
    }

    private func calculateBalance(_ a: Int, _ b: Int) -> Int {
        let total = a + b
        guard total > 0 else { return 50 }
        let ratio = Double(a) / Double(total)
        return 50 - Int(abs(50 - ratio * 100))
    }

    private func generateSummary(_ yours: ApologyAnalysis.PersonApologies, _ theirs: ApologyAnalysis.PersonApologies, _ yourRec: Int, _ theirRec: Int) -> String {
        let total = yours.totalApologies + theirs.totalApologies
        if total == 0 { return "No apologies detected in the conversation." }

        var parts: [String] = []
        if yours.totalApologies > theirs.totalApologies * 2 {
            parts.append("You apologize significantly more (\(yours.totalApologies) vs \(theirs.totalApologies))")
        } else if theirs.totalApologies > yours.totalApologies * 2 {
            parts.append("They apologize significantly more (\(theirs.totalApologies) vs \(yours.totalApologies))")
        } else {
            parts.append("Apologies are relatively balanced")
        }

        let totalRec = yourRec + theirRec
        if totalRec > 0 {
            parts.append("\(totalRec) reconciliation attempts detected")
        }

        return parts.joined(separator: ". ") + "."
    }
}

// MARK: - Positivity Calculator

final class PositivityCalculator {

    func calculatePositivityIndex(_ messages: [ParsedMessage]) -> PositivityIndex {
        guard messages.count >= 2 else {
            return PositivityIndex(
                score: 0, health: .unknown, trend: "insufficient_data",
                you: .init(score: 0, positiveCount: 0, negativeCount: 0, neutralCount: 0, level: "unknown"),
                them: .init(score: 0, positiveCount: 0, negativeCount: 0, neutralCount: 0, level: "unknown"),
                comparison: .init(morePositive: "equal", scoreDiff: 0, interpretation: "Need more data"),
                indicators: [], recommendation: "Need more messages", summary: "Need at least 2 messages"
            )
        }

        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourPositivity = calculatePersonPositivity(sent)
        let theirPositivity = calculatePersonPositivity(received)

        let sentimentScore = calculateSentimentComponent(messages)
        let engagementScore = calculateEngagementComponent(messages)
        let toxicityPenalty = calculateToxicityPenalty(messages)

        let finalScore = max(0, min(100, sentimentScore + engagementScore + toxicityPenalty))
        let health = determineHealth(finalScore)
        let trend = detectTrend(messages)

        let morePositive = yourPositivity.score > theirPositivity.score + 5 ? "you" :
                          theirPositivity.score > yourPositivity.score + 5 ? "them" : "equal"

        return PositivityIndex(
            score: finalScore,
            health: health,
            trend: trend,
            you: yourPositivity,
            them: theirPositivity,
            comparison: .init(
                morePositive: morePositive,
                scoreDiff: Double(abs(yourPositivity.score - theirPositivity.score)),
                interpretation: generateComparison(yourPositivity.score, theirPositivity.score)
            ),
            indicators: generateIndicators(finalScore, messages),
            recommendation: generateRecommendation(finalScore, health),
            summary: "Overall relationship health: \(health.rawValue.uppercased()) (\(finalScore)/100)"
        )
    }

    private func calculatePersonPositivity(_ messages: [ParsedMessage]) -> PositivityIndex.PersonPositivity {
        var positive = 0
        var negative = 0

        let positiveKeywords = SentimentKeywords.positive.strong + SentimentKeywords.positive.moderate
        let negativeKeywords = SentimentKeywords.negative.strong + SentimentKeywords.negative.moderate

        for msg in messages {
            let text = msg.content.lowercased()
            let hasPositive = positiveKeywords.contains { text.contains($0) }
            let hasNegative = negativeKeywords.contains { text.contains($0) }

            if hasPositive && !hasNegative { positive += 1 }
            else if hasNegative { negative += 1 }
        }

        let neutral = messages.count - positive - negative
        let rawScore = messages.isEmpty ? 0 : ((Double(positive) - Double(negative) * 2) / Double(messages.count) + 0.5) * 100
        let score = max(0, min(100, Int(rawScore)))

        let level: String
        if score >= 70 { level = "very_positive" }
        else if score >= 55 { level = "positive" }
        else if score >= 45 { level = "neutral" }
        else if score >= 30 { level = "negative" }
        else { level = "very_negative" }

        return .init(score: score, positiveCount: positive, negativeCount: negative, neutralCount: neutral, level: level)
    }

    private func calculateSentimentComponent(_ messages: [ParsedMessage]) -> Int {
        var positive = 0
        var negative = 0

        let positiveKeywords = SentimentKeywords.positive.strong + SentimentKeywords.positive.moderate
        let negativeKeywords = SentimentKeywords.negative.strong + SentimentKeywords.negative.moderate

        for msg in messages {
            let text = msg.content.lowercased()
            if positiveKeywords.contains(where: { text.contains($0) }) { positive += 1 }
            if negativeKeywords.contains(where: { text.contains($0) }) { negative += 1 }
        }

        let ratio = Double(positive - negative) / Double(messages.count)
        return max(0, min(40, Int(20 + ratio * 40)))
    }

    private func calculateEngagementComponent(_ messages: [ParsedMessage]) -> Int {
        let questions = messages.filter { $0.content.contains("?") }.count
        let avgLength = messages.reduce(0) { $0 + $1.length } / max(1, messages.count)

        var score = 0
        score += min(Int(Double(questions) / Double(messages.count) * 10), 10)
        score += min(avgLength / 10, 10)
        return min(30, score)
    }

    private func calculateToxicityPenalty(_ messages: [ParsedMessage]) -> Int {
        let toxicKeywords = ["hate", "fuck", "stupid", "idiot", "shut up", "asshole"]
        var toxicCount = 0

        for msg in messages {
            let text = msg.content.lowercased()
            if toxicKeywords.contains(where: { text.contains($0) }) {
                toxicCount += 1
            }
        }

        let percentage = Double(toxicCount) / Double(messages.count) * 100
        if percentage > 50 { return -30 }
        if percentage > 30 { return -25 }
        if percentage > 20 { return -20 }
        if percentage > 10 { return -15 }
        if percentage > 5 { return -10 }
        return 0
    }

    private func determineHealth(_ score: Int) -> PositivityIndex.HealthLevel {
        if score >= 80 { return .excellent }
        if score >= 60 { return .good }
        if score >= 40 { return .moderate }
        if score >= 20 { return .poor }
        return .toxic
    }

    private func detectTrend(_ messages: [ParsedMessage]) -> String {
        guard messages.count >= 10 else { return "insufficient_data" }

        let half = messages.count / 2
        let firstHalf = Array(messages[..<half])
        let secondHalf = Array(messages[half...])

        let firstScore = calculateSentimentComponent(firstHalf)
        let secondScore = calculateSentimentComponent(Array(secondHalf))

        if secondScore > firstScore + 5 { return "improving" }
        if secondScore < firstScore - 5 { return "declining" }
        return "stable"
    }

    private func generateComparison(_ yours: Int, _ theirs: Int) -> String {
        let diff = yours - theirs
        if abs(diff) <= 5 { return "Both parties show similar levels of positivity" }
        if diff > 20 { return "You are significantly more positive" }
        if diff > 0 { return "You tend to be slightly more positive" }
        if diff < -20 { return "They are significantly more positive" }
        return "They tend to be slightly more positive"
    }

    private func generateIndicators(_ score: Int, _ messages: [ParsedMessage]) -> [PositivityIndex.HealthIndicator] {
        var indicators: [PositivityIndex.HealthIndicator] = []

        if score >= 70 {
            indicators.append(.init(type: "positive", text: "Overall positive and healthy communication"))
        }
        if score < 40 {
            indicators.append(.init(type: "warning", text: "Low engagement and positivity"))
        }

        let questions = messages.filter { $0.content.contains("?") }.count
        if questions > messages.count / 10 {
            indicators.append(.init(type: "positive", text: "Good amount of question asking - shows interest"))
        }

        return indicators
    }

    private func generateRecommendation(_ score: Int, _ health: PositivityIndex.HealthLevel) -> String {
        switch health {
        case .excellent:
            return "Relationship is very healthy! Continue investing in open communication."
        case .good:
            return "Relationship is good. Focus on increasing engagement and emotional connection."
        case .moderate:
            return "Relationship needs attention. Try increasing positive interactions."
        case .poor:
            return "Relationship shows warning signs. Prioritize communication and rebuilding trust."
        case .toxic:
            return "Significant issues detected. Consider professional help or serious discussion."
        case .unknown:
            return "Need more data for analysis."
        }
    }
}

// MARK: - Communication Pattern Analyzer

final class CommunicationPatternAnalyzer {

    func analyzePatterns(_ messages: [ParsedMessage]) -> CommunicationPatterns {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourAvgLength = sent.isEmpty ? 0 : sent.reduce(0) { $0 + $1.length } / sent.count
        let theirAvgLength = received.isEmpty ? 0 : received.reduce(0) { $0 + $1.length } / received.count

        let yourQuestions = sent.filter { $0.content.contains("?") }.count
        let theirQuestions = received.filter { $0.content.contains("?") }.count

        let emojiPattern = try! NSRegularExpression(pattern: "[\\u{1F300}-\\u{1F9FF}]", options: [])
        let yourEmoji = sent.filter { msg in
            emojiPattern.firstMatch(in: msg.content, range: NSRange(msg.content.startIndex..., in: msg.content)) != nil
        }.count
        let theirEmoji = received.filter { msg in
            emojiPattern.firstMatch(in: msg.content, range: NSRange(msg.content.startIndex..., in: msg.content)) != nil
        }.count

        let balanceInterpretation: String
        if abs(sent.count - received.count) < messages.count / 10 {
            balanceInterpretation = "Conversation is well balanced"
        } else if sent.count > received.count {
            balanceInterpretation = "You send more messages"
        } else {
            balanceInterpretation = "They send more messages"
        }

        return CommunicationPatterns(
            frequency: .init(
                total: messages.count,
                youInitiated: sent.count,
                theyResponded: received.count,
                averageMessageLength: .init(
                    you: yourAvgLength,
                    them: theirAvgLength,
                    longer: yourAvgLength > theirAvgLength ? "you" : theirAvgLength > yourAvgLength ? "them" : "equal"
                ),
                balance: .init(interpretation: balanceInterpretation)
            ),
            engagement: .init(
                questions: .init(you: yourQuestions, them: theirQuestions),
                emoji: .init(you: yourEmoji, them: theirEmoji)
            ),
            summary: "Total \(messages.count) messages - \(sent.count) from you, \(received.count) from them"
        )
    }
}

// MARK: - Sentiment Keywords

enum SentimentKeywords {
    struct KeywordSet {
        let strong: [String]
        let moderate: [String]
        let weak: [String]
    }

    static let positive = KeywordSet(
        strong: ["love", "amazing", "wonderful", "fantastic", "excellent", "awesome", "beautiful", "perfect", "incredible", "adore"],
        moderate: ["good", "great", "nice", "happy", "glad", "pleased", "enjoyed", "like", "lovely", "sweet", "kind", "fun", "appreciate", "grateful"],
        weak: ["okay", "fine", "sure", "yeah", "alright", "decent", "chill"]
    )

    static let negative = KeywordSet(
        strong: ["hate", "horrible", "terrible", "awful", "disgusting", "despise", "furious", "devastated", "miserable"],
        moderate: ["bad", "sad", "disappointed", "upset", "annoyed", "frustrated", "worried", "confused", "stressed", "tired", "dislike", "gross", "ugh"],
        mild: ["meh", "eh", "hmm", "nah", "nope", "not great"]
    )
}
