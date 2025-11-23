// GreyMirror/Services/ML/AdvancedClassifiers2.swift
// Remaining 20 Advanced Relationship Classifiers

import Foundation

// MARK: - 9. Vulnerability Detector
/// Measures emotional openness and vulnerability in communication

final class VulnerabilityDetector {

    struct VulnerabilityAnalysis: Codable {
        let you: PersonVulnerability
        let them: PersonVulnerability
        let intimacyLevel: IntimacyLevel
        let summary: String

        struct PersonVulnerability: Codable {
            let score: Int
            let emotionalDisclosures: Int
            let fearSharing: Int
            let pastTraumaReferences: Int
            let dreamSharing: Int
            let insecurityAdmissions: Int
        }

        enum IntimacyLevel: String, Codable {
            case superficial, developing, moderate, deep, profound
        }
    }

    private let vulnerabilityIndicators = [
        "i'm scared", "i'm afraid", "i've never told anyone", "this is hard to say",
        "i'm insecure about", "my biggest fear", "i struggle with", "i'm worried that",
        "it hurts me when", "i feel alone", "i don't feel good enough", "i'm anxious about"
    ]

    private let dreamIndicators = ["my dream is", "i hope to", "i want to become", "someday i want", "my goal is"]
    private let pastIndicators = ["when i was young", "my childhood", "my ex", "i went through", "that experience"]

    func analyze(_ messages: [ParsedMessage]) -> VulnerabilityAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourVuln = analyzePersonVulnerability(sent)
        let theirVuln = analyzePersonVulnerability(received)

        let totalScore = (yourVuln.score + theirVuln.score) / 2
        let intimacy: VulnerabilityAnalysis.IntimacyLevel
        if totalScore < 15 { intimacy = .superficial }
        else if totalScore < 30 { intimacy = .developing }
        else if totalScore < 50 { intimacy = .moderate }
        else if totalScore < 75 { intimacy = .deep }
        else { intimacy = .profound }

        return VulnerabilityAnalysis(
            you: yourVuln,
            them: theirVuln,
            intimacyLevel: intimacy,
            summary: "Emotional intimacy level: \(intimacy.rawValue). Your vulnerability: \(yourVuln.score)/100, Theirs: \(theirVuln.score)/100"
        )
    }

    private func analyzePersonVulnerability(_ messages: [ParsedMessage]) -> VulnerabilityAnalysis.PersonVulnerability {
        var emotionalDisclosures = 0
        var fearSharing = 0
        var pastRefs = 0
        var dreamSharing = 0
        var insecurityAdmissions = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for indicator in vulnerabilityIndicators {
                if text.contains(indicator) {
                    emotionalDisclosures += 1
                    if indicator.contains("scared") || indicator.contains("afraid") || indicator.contains("fear") {
                        fearSharing += 1
                    }
                    if indicator.contains("insecure") || indicator.contains("good enough") {
                        insecurityAdmissions += 1
                    }
                }
            }

            for indicator in dreamIndicators where text.contains(indicator) { dreamSharing += 1 }
            for indicator in pastIndicators where text.contains(indicator) { pastRefs += 1 }
        }

        let score = min(100, (emotionalDisclosures * 8) + (fearSharing * 10) + (pastRefs * 6) + (dreamSharing * 8) + (insecurityAdmissions * 12))

        return VulnerabilityAnalysis.PersonVulnerability(
            score: score,
            emotionalDisclosures: emotionalDisclosures,
            fearSharing: fearSharing,
            pastTraumaReferences: pastRefs,
            dreamSharing: dreamSharing,
            insecurityAdmissions: insecurityAdmissions
        )
    }
}

// MARK: - 10. Trust Indicator Analyzer

final class TrustIndicatorAnalyzer {

    struct TrustAnalysis: Codable {
        let overallTrust: Int
        let you: PersonTrust
        let them: PersonTrust
        let trustBuilding: [String]
        let trustBreaking: [String]
        let summary: String

        struct PersonTrust: Codable {
            let score: Int
            let trustingStatements: Int
            let distrustStatements: Int
            let checkingBehavior: Int
            let reassuranceNeeded: Int
        }
    }

    private let trustPhrases = ["i trust you", "i believe you", "i know you would never", "i have faith", "i don't need to worry"]
    private let distrustPhrases = ["are you sure", "prove it", "i don't believe", "you're lying", "show me", "let me see your phone"]

    func analyze(_ messages: [ParsedMessage]) -> TrustAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourTrust = analyzePersonTrust(sent)
        let theirTrust = analyzePersonTrust(received)

        let overall = (yourTrust.score + theirTrust.score) / 2

        return TrustAnalysis(
            overallTrust: overall,
            you: yourTrust,
            them: theirTrust,
            trustBuilding: identifyTrustBuilders(sent + received),
            trustBreaking: identifyTrustBreakers(sent + received),
            summary: "Trust level: \(overall)/100. \(overall > 60 ? "Healthy trust present" : "Trust may need work")"
        )
    }

    private func analyzePersonTrust(_ messages: [ParsedMessage]) -> TrustAnalysis.PersonTrust {
        var trusting = 0
        var distrusting = 0
        var checking = 0
        var reassurance = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in trustPhrases where text.contains(phrase) { trusting += 1 }
            for phrase in distrustPhrases where text.contains(phrase) { distrusting += 1 }

            if text.contains("where are you") || text.contains("who are you with") { checking += 1 }
            if text.contains("do you still") || text.contains("are we okay") { reassurance += 1 }
        }

        let score = 50 + (trusting * 10) - (distrusting * 15) - (checking * 8) - (reassurance * 3)

        return TrustAnalysis.PersonTrust(
            score: max(0, min(100, score)),
            trustingStatements: trusting,
            distrustStatements: distrusting,
            checkingBehavior: checking,
            reassuranceNeeded: reassurance
        )
    }

    private func identifyTrustBuilders(_ messages: [ParsedMessage]) -> [String] {
        var builders: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("thank you for being honest") { builders.append("Honesty appreciation") }
            if text.contains("i'm glad you told me") { builders.append("Open communication valued") }
        }
        return Array(Set(builders))
    }

    private func identifyTrustBreakers(_ messages: [ParsedMessage]) -> [String] {
        var breakers: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("you lied") { breakers.append("Lie accusation") }
            if text.contains("i caught you") { breakers.append("Caught in deception") }
        }
        return Array(Set(breakers))
    }
}

// MARK: - 11. Jealousy Pattern Detector

final class JealousyDetector {

    struct JealousyAnalysis: Codable {
        let detected: Bool
        let you: PersonJealousy
        let them: PersonJealousy
        let severity: Severity
        let triggers: [String]
        let summary: String

        struct PersonJealousy: Codable {
            let score: Int
            let possessiveStatements: Int
            let comparisonStatements: Int
            let accusationStatements: Int
            let controlAttempts: Int
        }

        enum Severity: String, Codable { case none, mild, moderate, severe, toxic }
    }

    private let jealousyPhrases = [
        "who is that", "why are they texting you", "are they attractive",
        "do you like them", "why do you talk to them", "i saw you looking at",
        "you're always with", "i don't want you seeing", "they're into you"
    ]

    func analyze(_ messages: [ParsedMessage]) -> JealousyAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourJealousy = analyzePersonJealousy(sent)
        let theirJealousy = analyzePersonJealousy(received)

        let maxScore = max(yourJealousy.score, theirJealousy.score)
        let severity: JealousyAnalysis.Severity
        if maxScore < 10 { severity = .none }
        else if maxScore < 25 { severity = .mild }
        else if maxScore < 50 { severity = .moderate }
        else if maxScore < 75 { severity = .severe }
        else { severity = .toxic }

        return JealousyAnalysis(
            detected: maxScore > 15,
            you: yourJealousy,
            them: theirJealousy,
            severity: severity,
            triggers: identifyTriggers(sent + received),
            summary: severity == .none ? "No jealousy patterns detected" : "Jealousy level: \(severity.rawValue)"
        )
    }

    private func analyzePersonJealousy(_ messages: [ParsedMessage]) -> JealousyAnalysis.PersonJealousy {
        var possessive = 0
        var comparison = 0
        var accusation = 0
        var control = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in jealousyPhrases where text.contains(phrase) { possessive += 1 }
            if text.contains("better than") || text.contains("hotter than") { comparison += 1 }
            if text.contains("cheating") || text.contains("behind my back") { accusation += 1 }
            if text.contains("don't talk to") || text.contains("stay away from") { control += 1 }
        }

        let score = (possessive * 8) + (comparison * 10) + (accusation * 15) + (control * 20)

        return JealousyAnalysis.PersonJealousy(
            score: min(100, score),
            possessiveStatements: possessive,
            comparisonStatements: comparison,
            accusationStatements: accusation,
            controlAttempts: control
        )
    }

    private func identifyTriggers(_ messages: [ParsedMessage]) -> [String] {
        var triggers: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("ex") { triggers.append("Ex mentioned") }
            if text.contains("friend") && text.contains("?") { triggers.append("Friends questioned") }
            if text.contains("coworker") || text.contains("colleague") { triggers.append("Work relationships") }
        }
        return Array(Set(triggers))
    }
}

// MARK: - 12. Future Planning Analyzer

final class FuturePlanningAnalyzer {

    struct FutureAnalysis: Codable {
        let score: Int
        let you: PersonFuture
        let them: PersonFuture
        let sharedPlans: [String]
        let commitment: CommitmentLevel
        let summary: String

        struct PersonFuture: Codable {
            let score: Int
            let shortTermPlans: Int  // Days/weeks
            let mediumTermPlans: Int  // Months
            let longTermPlans: Int  // Years
            let weStatements: Int
        }

        enum CommitmentLevel: String, Codable {
            case nonexistent, casual, developing, committed, deeplyCommitted
        }
    }

    private let shortTermWords = ["tomorrow", "this weekend", "next week", "later today", "tonight"]
    private let mediumTermWords = ["next month", "in a few weeks", "this summer", "this year", "holiday"]
    private let longTermWords = ["someday", "in the future", "when we", "years from now", "eventually", "married", "kids", "house", "grow old"]

    func analyze(_ messages: [ParsedMessage]) -> FutureAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourFuture = analyzePersonFuture(sent)
        let theirFuture = analyzePersonFuture(received)

        let overallScore = (yourFuture.score + theirFuture.score) / 2
        let sharedPlans = findSharedPlans(sent + received)

        let commitment: FutureAnalysis.CommitmentLevel
        if overallScore < 10 { commitment = .nonexistent }
        else if overallScore < 25 { commitment = .casual }
        else if overallScore < 50 { commitment = .developing }
        else if overallScore < 75 { commitment = .committed }
        else { commitment = .deeplyCommitted }

        return FutureAnalysis(
            score: overallScore,
            you: yourFuture,
            them: theirFuture,
            sharedPlans: sharedPlans,
            commitment: commitment,
            summary: "Future planning score: \(overallScore)/100. Commitment level: \(commitment.rawValue)"
        )
    }

    private func analyzePersonFuture(_ messages: [ParsedMessage]) -> FutureAnalysis.PersonFuture {
        var shortTerm = 0
        var mediumTerm = 0
        var longTerm = 0
        var weStatements = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for word in shortTermWords where text.contains(word) { shortTerm += 1 }
            for word in mediumTermWords where text.contains(word) { mediumTerm += 1 }
            for word in longTermWords where text.contains(word) { longTerm += 1 }

            if text.contains("we should") || text.contains("we could") || text.contains("let's") || text.contains("we will") {
                weStatements += 1
            }
        }

        let score = (shortTerm * 3) + (mediumTerm * 8) + (longTerm * 15) + (weStatements * 5)

        return FutureAnalysis.PersonFuture(
            score: min(100, score),
            shortTermPlans: shortTerm,
            mediumTermPlans: mediumTerm,
            longTermPlans: longTerm,
            weStatements: weStatements
        )
    }

    private func findSharedPlans(_ messages: [ParsedMessage]) -> [String] {
        var plans: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("vacation") || text.contains("trip") { plans.append("Travel together") }
            if text.contains("move in") || text.contains("live together") { plans.append("Living together") }
            if text.contains("meet my") || text.contains("meet your") { plans.append("Meeting family/friends") }
            if text.contains("married") || text.contains("wedding") { plans.append("Marriage") }
        }
        return Array(Set(plans))
    }
}

// MARK: - 13. Humor Compatibility Analyzer

final class HumorCompatibilityAnalyzer {

    struct HumorAnalysis: Codable {
        let compatibility: Int
        let you: PersonHumor
        let them: PersonHumor
        let sharedJokes: Int
        let laughingTogether: Int
        let summary: String

        struct PersonHumor: Codable {
            let humorScore: Int
            let jokesAttempted: Int
            let sarcasmUsed: Int
            let playfulTeasing: Int
            let laughingResponses: Int
        }
    }

    private let humorIndicators = ["haha", "lol", "lmao", "rofl", "😂", "🤣", "dead", "i'm dying", "that's hilarious"]
    private let jokeIndicators = ["jk", "just kidding", "joking", "lol jk"]
    private let sarcasmIndicators = ["oh sure", "yeah right", "totally", "obviously", "of course"]
    private let teasingIndicators = ["dummy", "nerd", "weirdo", "dork", "goofball"]

    func analyze(_ messages: [ParsedMessage]) -> HumorAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourHumor = analyzePersonHumor(sent)
        let theirHumor = analyzePersonHumor(received)

        let sharedJokes = countSharedJokes(messages)
        let laughingTogether = countLaughingTogether(messages)

        let compatibility = calculateCompatibility(yourHumor, theirHumor, sharedJokes, laughingTogether)

        return HumorAnalysis(
            compatibility: compatibility,
            you: yourHumor,
            them: theirHumor,
            sharedJokes: sharedJokes,
            laughingTogether: laughingTogether,
            summary: "Humor compatibility: \(compatibility)/100. \(compatibility > 60 ? "You share a good sense of humor!" : "Humor styles may differ")"
        )
    }

    private func analyzePersonHumor(_ messages: [ParsedMessage]) -> HumorAnalysis.PersonHumor {
        var jokes = 0
        var sarcasm = 0
        var teasing = 0
        var laughing = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for indicator in humorIndicators where text.contains(indicator) { laughing += 1 }
            for indicator in jokeIndicators where text.contains(indicator) { jokes += 1 }
            for indicator in sarcasmIndicators where text.contains(indicator) { sarcasm += 1 }
            for indicator in teasingIndicators where text.contains(indicator) { teasing += 1 }
        }

        return HumorAnalysis.PersonHumor(
            humorScore: min(100, (jokes + sarcasm + teasing + laughing) * 5),
            jokesAttempted: jokes,
            sarcasmUsed: sarcasm,
            playfulTeasing: teasing,
            laughingResponses: laughing
        )
    }

    private func countSharedJokes(_ messages: [ParsedMessage]) -> Int {
        var sharedJokes = 0
        for i in 1..<messages.count {
            let prevText = messages[i-1].content.lowercased()
            let currText = messages[i].content.lowercased()
            let prevHasHumor = humorIndicators.contains { prevText.contains($0) }
            let currHasHumor = humorIndicators.contains { currText.contains($0) }
            if prevHasHumor && currHasHumor && messages[i].direction != messages[i-1].direction {
                sharedJokes += 1
            }
        }
        return sharedJokes
    }

    private func countLaughingTogether(_ messages: [ParsedMessage]) -> Int {
        return countSharedJokes(messages)
    }

    private func calculateCompatibility(_ yours: HumorAnalysis.PersonHumor, _ theirs: HumorAnalysis.PersonHumor, _ shared: Int, _ laughing: Int) -> Int {
        let baseScore = min(yours.humorScore, theirs.humorScore)
        let sharedBonus = shared * 5
        let laughingBonus = laughing * 3
        return min(100, baseScore + sharedBonus + laughingBonus)
    }
}

// MARK: - 14. Topic Diversity Analyzer

final class TopicDiversityAnalyzer {

    struct TopicAnalysis: Codable {
        let diversityScore: Int
        let topicsDiscussed: [TopicCategory]
        let mostCommonTopics: [String]
        let missingTopics: [String]
        let depthScore: Int
        let summary: String

        struct TopicCategory: Codable {
            let name: String
            let count: Int
            let percentage: Double
        }
    }

    private let topicKeywords: [String: [String]] = [
        "Emotions": ["feel", "happy", "sad", "angry", "excited", "worried", "love", "hate"],
        "Work/Career": ["work", "job", "boss", "meeting", "project", "career", "office", "salary"],
        "Family": ["mom", "dad", "parents", "sister", "brother", "family", "kids", "children"],
        "Friends": ["friend", "friends", "hangout", "party", "group"],
        "Future Plans": ["someday", "future", "plan", "want to", "going to", "will"],
        "Past/Memories": ["remember", "used to", "back then", "childhood", "when we"],
        "Hobbies": ["movie", "music", "game", "book", "show", "sport", "hobby"],
        "Daily Life": ["today", "morning", "tonight", "dinner", "lunch", "sleep"],
        "Intimacy": ["miss you", "love you", "kiss", "hug", "cuddle", "close to you"],
        "Conflict": ["argue", "fight", "disagree", "upset", "mad", "frustrated"]
    ]

    func analyze(_ messages: [ParsedMessage]) -> TopicAnalysis {
        var topicCounts: [String: Int] = [:]

        for msg in messages {
            let text = msg.content.lowercased()
            for (topic, keywords) in topicKeywords {
                for keyword in keywords {
                    if text.contains(keyword) {
                        topicCounts[topic, default: 0] += 1
                        break
                    }
                }
            }
        }

        let total = topicCounts.values.reduce(0, +)
        let categories = topicCounts.map { TopicAnalysis.TopicCategory(
            name: $0.key,
            count: $0.value,
            percentage: total > 0 ? Double($0.value) / Double(total) * 100 : 0
        )}.sorted { $0.count > $1.count }

        let diversityScore = min(100, topicCounts.count * 12)
        let mostCommon = Array(categories.prefix(5).map { $0.name })
        let missing = topicKeywords.keys.filter { topicCounts[$0] == nil }.map { String($0) }

        return TopicAnalysis(
            diversityScore: diversityScore,
            topicsDiscussed: categories,
            mostCommonTopics: mostCommon,
            missingTopics: Array(missing.prefix(3)),
            depthScore: calculateDepthScore(categories),
            summary: "Topic diversity: \(diversityScore)/100. \(topicCounts.count) different topics discussed."
        )
    }

    private func calculateDepthScore(_ categories: [TopicAnalysis.TopicCategory]) -> Int {
        let emotionalTopics = ["Emotions", "Intimacy", "Past/Memories", "Future Plans"]
        let emotionalCount = categories.filter { emotionalTopics.contains($0.name) }.reduce(0) { $0 + $1.count }
        return min(100, emotionalCount * 3)
    }
}

// MARK: - 15. Consistency Analyzer

final class ConsistencyAnalyzer {

    struct ConsistencyAnalysis: Codable {
        let overallScore: Int
        let you: PersonConsistency
        let them: PersonConsistency
        let patterns: [ConsistencyPattern]
        let summary: String

        struct PersonConsistency: Codable {
            let score: Int
            let messagingFrequencyConsistency: Int
            let responseTimeConsistency: Int
            let toneConsistency: Int
            let followThroughRate: Int
        }

        struct ConsistencyPattern: Codable {
            let type: String
            let description: String
            let positive: Bool
        }
    }

    func analyze(_ messages: [ParsedMessage]) -> ConsistencyAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourConsistency = analyzePersonConsistency(sent)
        let theirConsistency = analyzePersonConsistency(received)

        let patterns = identifyPatterns(yourConsistency, theirConsistency)
        let overallScore = (yourConsistency.score + theirConsistency.score) / 2

        return ConsistencyAnalysis(
            overallScore: overallScore,
            you: yourConsistency,
            them: theirConsistency,
            patterns: patterns,
            summary: "Behavior consistency: \(overallScore)/100. \(overallScore > 60 ? "Reliable communication patterns" : "Some inconsistency detected")"
        )
    }

    private func analyzePersonConsistency(_ messages: [ParsedMessage]) -> ConsistencyAnalysis.PersonConsistency {
        guard messages.count > 5 else {
            return ConsistencyAnalysis.PersonConsistency(score: 50, messagingFrequencyConsistency: 50, responseTimeConsistency: 50, toneConsistency: 50, followThroughRate: 50)
        }

        // Calculate message length consistency
        let lengths = messages.map { $0.length }
        let avgLength = lengths.reduce(0, +) / lengths.count
        let variance = lengths.map { abs($0 - avgLength) }.reduce(0, +) / lengths.count
        let lengthConsistency = max(0, 100 - variance)

        // Calculate response time consistency
        let responseTimes = messages.compactMap { $0.timeSinceLast }
        let responseConsistency = calculateResponseConsistency(responseTimes)

        let score = (lengthConsistency + responseConsistency) / 2

        return ConsistencyAnalysis.PersonConsistency(
            score: score,
            messagingFrequencyConsistency: lengthConsistency,
            responseTimeConsistency: responseConsistency,
            toneConsistency: 60,  // Simplified
            followThroughRate: 60  // Simplified
        )
    }

    private func calculateResponseConsistency(_ times: [TimeInterval]) -> Int {
        guard times.count > 2 else { return 50 }
        let avg = times.reduce(0, +) / Double(times.count)
        guard avg > 0 else { return 50 }
        let variance = times.map { abs($0 - avg) }.reduce(0, +) / Double(times.count)
        let cv = variance / avg
        return max(0, min(100, 100 - Int(cv * 50)))
    }

    private func identifyPatterns(_ yours: ConsistencyAnalysis.PersonConsistency, _ theirs: ConsistencyAnalysis.PersonConsistency) -> [ConsistencyAnalysis.ConsistencyPattern] {
        var patterns: [ConsistencyAnalysis.ConsistencyPattern] = []

        if yours.score > 70 {
            patterns.append(.init(type: "Your Consistency", description: "You maintain consistent communication", positive: true))
        }
        if theirs.score > 70 {
            patterns.append(.init(type: "Their Consistency", description: "They maintain consistent communication", positive: true))
        }
        if theirs.score < 40 {
            patterns.append(.init(type: "Inconsistency Warning", description: "Their communication is unpredictable", positive: false))
        }

        return patterns
    }
}

// MARK: - 16-28: More Specialized Classifiers

// MARK: - 16. Ghosting Risk Predictor

final class GhostingRiskPredictor {

    struct GhostingAnalysis: Codable {
        let riskScore: Int
        let riskLevel: RiskLevel
        let warningSignsFomYou: [String]
        let warningSignsFromThem: [String]
        let summary: String

        enum RiskLevel: String, Codable { case low, moderate, high, critical }
    }

    func analyze(_ messages: [ParsedMessage]) -> GhostingAnalysis {
        var yourSigns: [String] = []
        var theirSigns: [String] = []
        var riskScore = 0

        // Check for decreasing message frequency over time
        let received = messages.filter { $0.direction == .received }
        if received.count > 10 {
            let firstHalf = Array(received.prefix(received.count / 2))
            let secondHalf = Array(received.suffix(received.count / 2))

            let firstAvgLength = firstHalf.reduce(0) { $0 + $1.length } / max(1, firstHalf.count)
            let secondAvgLength = secondHalf.reduce(0) { $0 + $1.length } / max(1, secondHalf.count)

            if secondAvgLength < firstAvgLength / 2 {
                theirSigns.append("Message length decreasing significantly")
                riskScore += 25
            }
        }

        // Check for short responses
        let shortResponses = received.filter { $0.length < 10 }.count
        if shortResponses > received.count / 2 {
            theirSigns.append("Majority of responses are very short")
            riskScore += 20
        }

        // Check for delayed responses
        let longDelays = received.filter { ($0.timeSinceLast ?? 0) > 86400 }.count  // > 1 day
        if longDelays > 5 {
            theirSigns.append("Frequently takes over a day to respond")
            riskScore += 15
        }

        let riskLevel: GhostingAnalysis.RiskLevel
        if riskScore < 20 { riskLevel = .low }
        else if riskScore < 40 { riskLevel = .moderate }
        else if riskScore < 60 { riskLevel = .high }
        else { riskLevel = .critical }

        return GhostingAnalysis(
            riskScore: min(100, riskScore),
            riskLevel: riskLevel,
            warningSignsFomYou: yourSigns,
            warningSignsFromThem: theirSigns,
            summary: riskLevel == .low ? "Low ghosting risk" : "Ghosting risk: \(riskLevel.rawValue). \(theirSigns.joined(separator: ". "))"
        )
    }
}

// MARK: - 17. Emotional Availability Analyzer

final class EmotionalAvailabilityAnalyzer {

    struct AvailabilityAnalysis: Codable {
        let you: Int
        let them: Int
        let difference: Int
        let assessment: String
        let summary: String
    }

    private let availableIndicators = ["i'm here", "tell me", "what's wrong", "how do you feel", "i care", "i'm listening"]
    private let unavailableIndicators = ["not now", "i'm busy", "later", "don't have time", "whatever", "don't know"]

    func analyze(_ messages: [ParsedMessage]) -> AvailabilityAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourScore = calculateAvailability(sent)
        let theirScore = calculateAvailability(received)

        let assessment: String
        if yourScore > 60 && theirScore > 60 { assessment = "Both emotionally available" }
        else if yourScore > theirScore + 20 { assessment = "You are more emotionally available" }
        else if theirScore > yourScore + 20 { assessment = "They are more emotionally available" }
        else { assessment = "Similar availability levels" }

        return AvailabilityAnalysis(
            you: yourScore,
            them: theirScore,
            difference: abs(yourScore - theirScore),
            assessment: assessment,
            summary: "Your availability: \(yourScore)/100, Their availability: \(theirScore)/100"
        )
    }

    private func calculateAvailability(_ messages: [ParsedMessage]) -> Int {
        var available = 0
        var unavailable = 0

        for msg in messages {
            let text = msg.content.lowercased()
            for indicator in availableIndicators where text.contains(indicator) { available += 1 }
            for indicator in unavailableIndicators where text.contains(indicator) { unavailable += 1 }
        }

        return max(0, min(100, 50 + (available * 8) - (unavailable * 10)))
    }
}

// MARK: - 18. Conflict Style Analyzer

final class ConflictStyleAnalyzer {

    struct ConflictAnalysis: Codable {
        let yourStyle: ConflictStyle
        let theirStyle: ConflictStyle
        let compatibility: Int
        let healthyPatterns: [String]
        let unhealthyPatterns: [String]
        let summary: String

        enum ConflictStyle: String, Codable {
            case collaborative, competitive, avoiding, accommodating, compromising
        }
    }

    func analyze(_ messages: [ParsedMessage]) -> ConflictAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourStyle = detectStyle(sent)
        let theirStyle = detectStyle(received)
        let compatibility = calculateCompatibility(yourStyle, theirStyle)

        let healthy = identifyHealthyPatterns(sent + received)
        let unhealthy = identifyUnhealthyPatterns(sent + received)

        return ConflictAnalysis(
            yourStyle: yourStyle,
            theirStyle: theirStyle,
            compatibility: compatibility,
            healthyPatterns: healthy,
            unhealthyPatterns: unhealthy,
            summary: "Your conflict style: \(yourStyle.rawValue). Their style: \(theirStyle.rawValue). Compatibility: \(compatibility)/100"
        )
    }

    private func detectStyle(_ messages: [ParsedMessage]) -> ConflictAnalysis.ConflictStyle {
        var collaborative = 0
        var competitive = 0
        var avoiding = 0
        var accommodating = 0

        for msg in messages {
            let text = msg.content.lowercased()

            if text.contains("let's figure this out") || text.contains("we can work") { collaborative += 1 }
            if text.contains("i'm right") || text.contains("you're wrong") || text.contains("my way") { competitive += 1 }
            if text.contains("whatever") || text.contains("fine") || text.contains("don't care") { avoiding += 1 }
            if text.contains("you're right") || text.contains("sorry") || text.contains("my fault") { accommodating += 1 }
        }

        let scores = [
            ("collaborative", collaborative),
            ("competitive", competitive),
            ("avoiding", avoiding),
            ("accommodating", accommodating)
        ]

        let dominant = scores.max { $0.1 < $1.1 }?.0 ?? "compromising"

        switch dominant {
        case "collaborative": return .collaborative
        case "competitive": return .competitive
        case "avoiding": return .avoiding
        case "accommodating": return .accommodating
        default: return .compromising
        }
    }

    private func calculateCompatibility(_ yours: ConflictAnalysis.ConflictStyle, _ theirs: ConflictAnalysis.ConflictStyle) -> Int {
        if yours == .collaborative && theirs == .collaborative { return 95 }
        if yours == .competitive && theirs == .competitive { return 20 }
        if yours == .avoiding && theirs == .avoiding { return 40 }
        if (yours == .collaborative && theirs == .accommodating) || (yours == .accommodating && theirs == .collaborative) { return 80 }
        return 55
    }

    private func identifyHealthyPatterns(_ messages: [ParsedMessage]) -> [String] {
        var patterns: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("i understand") { patterns.append("Active listening") }
            if text.contains("let's calm down") { patterns.append("De-escalation") }
            if text.contains("i feel") { patterns.append("I-statements") }
        }
        return Array(Set(patterns))
    }

    private func identifyUnhealthyPatterns(_ messages: [ParsedMessage]) -> [String] {
        var patterns: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("you always") || text.contains("you never") { patterns.append("Absolute statements") }
            if text.contains("shut up") { patterns.append("Silencing") }
            if text.contains("bringing up") && text.contains("old") { patterns.append("Past-digging") }
        }
        return Array(Set(patterns))
    }
}

// MARK: - 19. Affection Expression Analyzer

final class AffectionExpressionAnalyzer {

    struct AffectionAnalysis: Codable {
        let you: PersonAffection
        let them: PersonAffection
        let balance: Int
        let reciprocity: Bool
        let summary: String

        struct PersonAffection: Codable {
            let score: Int
            let verbalAffection: Int
            let emoticonAffection: Int
            let petNames: Int
            let compliments: Int
        }
    }

    private let affectionWords = ["love you", "miss you", "adore you", "need you", "want you", "care about you"]
    private let affectionEmoji = ["❤️", "😍", "🥰", "💕", "💖", "😘", "💗", "💞"]
    private let petNames = ["babe", "baby", "honey", "sweetie", "darling", "love", "dear", "sweetheart"]
    private let compliments = ["beautiful", "handsome", "gorgeous", "amazing", "wonderful", "perfect", "incredible"]

    func analyze(_ messages: [ParsedMessage]) -> AffectionAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourAffection = analyzePersonAffection(sent)
        let theirAffection = analyzePersonAffection(received)

        let balance = 100 - abs(yourAffection.score - theirAffection.score)
        let reciprocity = abs(yourAffection.score - theirAffection.score) < 20

        return AffectionAnalysis(
            you: yourAffection,
            them: theirAffection,
            balance: balance,
            reciprocity: reciprocity,
            summary: reciprocity ? "Affection is reciprocal and balanced" : "Affection levels differ - \(yourAffection.score > theirAffection.score ? "you" : "they") express more"
        )
    }

    private func analyzePersonAffection(_ messages: [ParsedMessage]) -> AffectionAnalysis.PersonAffection {
        var verbal = 0
        var emoticons = 0
        var petNameCount = 0
        var complimentCount = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for word in affectionWords where text.contains(word) { verbal += 1 }
            for emoji in affectionEmoji where msg.content.contains(emoji) { emoticons += 1 }
            for name in petNames where text.contains(name) { petNameCount += 1 }
            for comp in compliments where text.contains(comp) { complimentCount += 1 }
        }

        let score = min(100, (verbal * 10) + (emoticons * 5) + (petNameCount * 8) + (complimentCount * 7))

        return AffectionAnalysis.PersonAffection(
            score: score,
            verbalAffection: verbal,
            emoticonAffection: emoticons,
            petNames: petNameCount,
            compliments: complimentCount
        )
    }
}

// MARK: - 20. Resentment Accumulator

final class ResentmentAccumulator {

    struct ResentmentAnalysis: Codable {
        let detected: Bool
        let you: Int
        let them: Int
        let signs: [String]
        let riskLevel: String
        let summary: String
    }

    private let resentmentSigns = [
        "you always", "you never", "here we go again", "of course you",
        "why do you always", "i'm sick of", "i'm tired of", "you don't even",
        "you don't care", "nothing i do is enough", "what's the point"
    ]

    func analyze(_ messages: [ParsedMessage]) -> ResentmentAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourResentment = calculateResentment(sent)
        let theirResentment = calculateResentment(received)

        let signs = findSigns(sent + received)
        let detected = yourResentment > 20 || theirResentment > 20

        let maxScore = max(yourResentment, theirResentment)
        let riskLevel = maxScore < 20 ? "Low" : maxScore < 40 ? "Moderate" : maxScore < 60 ? "High" : "Critical"

        return ResentmentAnalysis(
            detected: detected,
            you: yourResentment,
            them: theirResentment,
            signs: signs,
            riskLevel: riskLevel,
            summary: detected ? "Resentment detected. Risk level: \(riskLevel)" : "No significant resentment detected"
        )
    }

    private func calculateResentment(_ messages: [ParsedMessage]) -> Int {
        var score = 0
        for msg in messages {
            let text = msg.content.lowercased()
            for sign in resentmentSigns where text.contains(sign) {
                score += 10
            }
        }
        return min(100, score)
    }

    private func findSigns(_ messages: [ParsedMessage]) -> [String] {
        var signs: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            for sign in resentmentSigns where text.contains(sign) {
                signs.append(sign)
            }
        }
        return Array(Set(signs))
    }
}

// Additional classifiers (21-28) following similar patterns:
// 21. Boundary Respect Analyzer
// 22. Growth Mindset Detector
// 23. Listening Quality Scorer
// 24. Memory/Recall Analyzer
// 25. Initiation Balance Analyzer
// 26. Support Quality Analyzer
// 27. Validation Pattern Detector
// 28. Emotional Intelligence Scorer

// MARK: - 21. Boundary Respect Analyzer

final class BoundaryRespectAnalyzer {

    struct BoundaryAnalysis: Codable {
        let overallScore: Int
        let boundaryViolations: Int
        let boundaryRespect: Int
        let issues: [String]
        let summary: String
    }

    private let boundaryViolations = ["i said no", "stop asking", "leave me alone", "i already told you", "respect my", "don't push me"]
    private let boundaryRespect = ["i understand", "take your time", "when you're ready", "no pressure", "let me know"]

    func analyze(_ messages: [ParsedMessage]) -> BoundaryAnalysis {
        var violations = 0
        var respect = 0
        var issues: [String] = []

        for msg in messages {
            let text = msg.content.lowercased()
            for phrase in boundaryViolations where text.contains(phrase) {
                violations += 1
                issues.append(phrase)
            }
            for phrase in boundaryRespect where text.contains(phrase) { respect += 1 }
        }

        let score = max(0, min(100, 70 + (respect * 5) - (violations * 15)))

        return BoundaryAnalysis(
            overallScore: score,
            boundaryViolations: violations,
            boundaryRespect: respect,
            issues: Array(Set(issues)),
            summary: violations > 0 ? "Boundary issues detected (\(violations) instances)" : "Boundaries appear respected"
        )
    }
}

// MARK: - 22. Emotional Intelligence Scorer

final class EmotionalIntelligenceScorer {

    struct EQAnalysis: Codable {
        let you: Int
        let them: Int
        let components: EQComponents
        let summary: String

        struct EQComponents: Codable {
            let selfAwareness: Int
            let empathy: Int
            let emotionalRegulation: Int
            let socialSkills: Int
        }
    }

    private let empathyPhrases = ["i understand how you feel", "that must be", "i can see why", "i hear you", "makes sense you'd feel"]
    private let regulationPhrases = ["let me calm down", "i need a moment", "let's take a break", "i shouldn't have said"]
    private let awarenessPhrases = ["i'm feeling", "i realize i", "i notice that i", "when i feel"]

    func analyze(_ messages: [ParsedMessage]) -> EQAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourEQ = calculateEQ(sent)
        let theirEQ = calculateEQ(received)

        return EQAnalysis(
            you: yourEQ.total,
            them: theirEQ.total,
            components: yourEQ.components,
            summary: "Your EQ score: \(yourEQ.total)/100. Their EQ score: \(theirEQ.total)/100"
        )
    }

    private func calculateEQ(_ messages: [ParsedMessage]) -> (total: Int, components: EQAnalysis.EQComponents) {
        var empathy = 0
        var regulation = 0
        var awareness = 0
        var social = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in empathyPhrases where text.contains(phrase) { empathy += 10 }
            for phrase in regulationPhrases where text.contains(phrase) { regulation += 10 }
            for phrase in awarenessPhrases where text.contains(phrase) { awareness += 10 }

            if text.contains("how are you") || text.contains("?") { social += 2 }
        }

        let components = EQAnalysis.EQComponents(
            selfAwareness: min(100, awareness),
            empathy: min(100, empathy),
            emotionalRegulation: min(100, regulation),
            socialSkills: min(100, social)
        )

        let total = (components.selfAwareness + components.empathy + components.emotionalRegulation + components.socialSkills) / 4

        return (total, components)
    }
}

// MARK: - 23. Listening Quality Scorer

/// Analyzes how well each person listens and responds to what the other shares
final class ListeningQualityScorer {

    struct ListeningAnalysis: Codable {
        let you: PersonListening
        let them: PersonListening
        let conversationFlow: Int
        let summary: String

        struct PersonListening: Codable {
            let score: Int
            let questionAsking: Int
            let topicContinuation: Int
            let acknowledgments: Int
            let interruptions: Int
            let subjectChanges: Int
        }
    }

    private let acknowledgmentPhrases = [
        "i see", "that makes sense", "i hear you", "right", "okay", "got it",
        "i understand", "mhm", "yeah", "exactly", "absolutely", "totally"
    ]

    private let questionWords = ["what", "why", "how", "when", "where", "tell me more", "can you explain"]
    private let interruptionSigns = ["anyway", "but wait", "hold on", "let me tell you", "forget that"]

    func analyze(_ messages: [ParsedMessage]) -> ListeningAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourListening = analyzePersonListening(sent, otherMessages: received)
        let theirListening = analyzePersonListening(received, otherMessages: sent)

        let flowScore = calculateConversationFlow(messages)

        return ListeningAnalysis(
            you: yourListening,
            them: theirListening,
            conversationFlow: flowScore,
            summary: "Your listening score: \(yourListening.score)/100. Their listening score: \(theirListening.score)/100"
        )
    }

    private func analyzePersonListening(_ messages: [ParsedMessage], otherMessages: [ParsedMessage]) -> ListeningAnalysis.PersonListening {
        var questionAsking = 0
        var acknowledgments = 0
        var interruptions = 0
        var subjectChanges = 0
        var topicContinuation = 0

        for msg in messages {
            let text = msg.content.lowercased()

            // Count questions
            for word in questionWords where text.contains(word) { questionAsking += 1 }
            if text.contains("?") { questionAsking += 1 }

            // Count acknowledgments
            for phrase in acknowledgmentPhrases where text.contains(phrase) { acknowledgments += 1 }

            // Count interruptions/subject changes
            for sign in interruptionSigns where text.contains(sign) {
                interruptions += 1
                subjectChanges += 1
            }
        }

        // Topic continuation - check if words from previous message appear
        topicContinuation = calculateTopicContinuation(messages, otherMessages: otherMessages)

        let score = min(100, 40 + (questionAsking * 5) + (acknowledgments * 8) + (topicContinuation * 3) - (interruptions * 10) - (subjectChanges * 5))

        return ListeningAnalysis.PersonListening(
            score: max(0, score),
            questionAsking: questionAsking,
            topicContinuation: topicContinuation,
            acknowledgments: acknowledgments,
            interruptions: interruptions,
            subjectChanges: subjectChanges
        )
    }

    private func calculateTopicContinuation(_ messages: [ParsedMessage], otherMessages: [ParsedMessage]) -> Int {
        var continuations = 0
        let otherWords = Set(otherMessages.flatMap { $0.content.lowercased().split(separator: " ").map(String.init) })

        for msg in messages {
            let words = msg.content.lowercased().split(separator: " ").map(String.init)
            if words.contains(where: { otherWords.contains($0) && $0.count > 4 }) {
                continuations += 1
            }
        }
        return continuations
    }

    private func calculateConversationFlow(_ messages: [ParsedMessage]) -> Int {
        guard messages.count > 5 else { return 50 }

        var alternations = 0
        for i in 1..<messages.count {
            if messages[i].direction != messages[i-1].direction {
                alternations += 1
            }
        }

        let alternationRate = Double(alternations) / Double(messages.count - 1)
        return min(100, Int(alternationRate * 100))
    }
}

// MARK: - 24. Memory/Recall Analyzer

/// Detects how well each person remembers and references past conversations
final class MemoryRecallAnalyzer {

    struct MemoryAnalysis: Codable {
        let you: PersonMemory
        let them: PersonMemory
        let sharedMemories: Int
        let deepenedConnection: Bool
        let summary: String

        struct PersonMemory: Codable {
            let score: Int
            let pastReferences: Int
            let rememberedDetails: Int
            let anniversaryMentions: Int
            let insideJokes: Int
        }
    }

    private let memoryPhrases = [
        "remember when", "you told me", "last time", "you mentioned", "you said",
        "that time we", "like before", "you always say", "reminds me of"
    ]

    private let anniversaryPhrases = ["anniversary", "been together", "first date", "met you", "one year", "months ago"]
    private let insideJokeIndicators = ["our thing", "inside joke", "only we", "you know what i mean"]

    func analyze(_ messages: [ParsedMessage]) -> MemoryAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourMemory = analyzePersonMemory(sent)
        let theirMemory = analyzePersonMemory(received)

        let sharedMemories = countSharedMemories(messages)
        let deepened = sharedMemories > 3 && (yourMemory.score + theirMemory.score) > 60

        return MemoryAnalysis(
            you: yourMemory,
            them: theirMemory,
            sharedMemories: sharedMemories,
            deepenedConnection: deepened,
            summary: "Memory engagement: \(sharedMemories) shared memories referenced. \(deepened ? "Strong shared history." : "Building memories together.")"
        )
    }

    private func analyzePersonMemory(_ messages: [ParsedMessage]) -> MemoryAnalysis.PersonMemory {
        var pastRefs = 0
        var rememberedDetails = 0
        var anniversaries = 0
        var insideJokes = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in memoryPhrases where text.contains(phrase) {
                pastRefs += 1
                if text.contains("you said") || text.contains("you mentioned") || text.contains("you told me") {
                    rememberedDetails += 1
                }
            }

            for phrase in anniversaryPhrases where text.contains(phrase) { anniversaries += 1 }
            for indicator in insideJokeIndicators where text.contains(indicator) { insideJokes += 1 }
        }

        let score = min(100, (pastRefs * 10) + (rememberedDetails * 15) + (anniversaries * 12) + (insideJokes * 20))

        return MemoryAnalysis.PersonMemory(
            score: score,
            pastReferences: pastRefs,
            rememberedDetails: rememberedDetails,
            anniversaryMentions: anniversaries,
            insideJokes: insideJokes
        )
    }

    private func countSharedMemories(_ messages: [ParsedMessage]) -> Int {
        var count = 0
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("remember") || text.contains("that time") {
                count += 1
            }
        }
        return count
    }
}

// MARK: - 25. Initiation Balance Analyzer

/// Analyzes who starts conversations and who makes more effort
final class InitiationBalanceAnalyzer {

    struct InitiationAnalysis: Codable {
        let you: PersonInitiation
        let them: PersonInitiation
        let balance: Int  // 50 = perfect balance, 0 or 100 = very imbalanced
        let pattern: String
        let summary: String

        struct PersonInitiation: Codable {
            let score: Int
            let conversationStarts: Int
            let planMaking: Int
            let checkIns: Int
            let firstAfterSilence: Int
        }
    }

    private let planMakingPhrases = [
        "let's", "we should", "want to", "do you want to", "how about",
        "why don't we", "can we", "wanna", "shall we"
    ]

    private let checkInPhrases = [
        "how are you", "how was your", "what's up", "how did it go",
        "thinking of you", "checking in", "just wanted to say"
    ]

    func analyze(_ messages: [ParsedMessage]) -> InitiationAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourInitiation = analyzePersonInitiation(sent, allMessages: messages, isSent: true)
        let theirInitiation = analyzePersonInitiation(received, allMessages: messages, isSent: false)

        let totalInitiations = yourInitiation.conversationStarts + theirInitiation.conversationStarts
        let balance: Int
        if totalInitiations > 0 {
            let yourPercentage = Double(yourInitiation.conversationStarts) / Double(totalInitiations) * 100
            balance = 100 - Int(abs(yourPercentage - 50) * 2)
        } else {
            balance = 50
        }

        let pattern: String
        if balance > 70 { pattern = "Well-balanced initiation" }
        else if yourInitiation.score > theirInitiation.score + 20 { pattern = "You initiate more" }
        else if theirInitiation.score > yourInitiation.score + 20 { pattern = "They initiate more" }
        else { pattern = "Somewhat balanced" }

        return InitiationAnalysis(
            you: yourInitiation,
            them: theirInitiation,
            balance: balance,
            pattern: pattern,
            summary: "Initiation balance: \(balance)/100. \(pattern)"
        )
    }

    private func analyzePersonInitiation(_ messages: [ParsedMessage], allMessages: [ParsedMessage], isSent: Bool) -> InitiationAnalysis.PersonInitiation {
        var conversationStarts = 0
        var planMaking = 0
        var checkIns = 0
        var firstAfterSilence = 0

        // Count plan making and check-ins
        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in planMakingPhrases where text.contains(phrase) { planMaking += 1 }
            for phrase in checkInPhrases where text.contains(phrase) { checkIns += 1 }
        }

        // Detect conversation starts (first message after significant time gap)
        for (i, msg) in allMessages.enumerated() {
            let isThisPersonsMessage = isSent ? msg.direction == .sent : msg.direction == .received
            if isThisPersonsMessage {
                if let gap = msg.timeSinceLast, gap > 7200 {  // > 2 hours
                    conversationStarts += 1
                    firstAfterSilence += 1
                } else if i == 0 {
                    conversationStarts += 1
                }
            }
        }

        let score = min(100, (conversationStarts * 12) + (planMaking * 8) + (checkIns * 6) + (firstAfterSilence * 5))

        return InitiationAnalysis.PersonInitiation(
            score: score,
            conversationStarts: conversationStarts,
            planMaking: planMaking,
            checkIns: checkIns,
            firstAfterSilence: firstAfterSilence
        )
    }
}

// MARK: - 26. Support Quality Analyzer

/// Measures how well each person provides emotional support during difficult times
final class SupportQualityAnalyzer {

    struct SupportAnalysis: Codable {
        let you: PersonSupport
        let them: PersonSupport
        let mutualSupport: Bool
        let summary: String

        struct PersonSupport: Codable {
            let score: Int
            let validatingStatements: Int
            let problemSolving: Int
            let empathyShown: Int
            let availabilityOffered: Int
            let dismissiveStatements: Int
        }
    }

    private let validatingPhrases = [
        "that makes sense", "i understand", "your feelings are valid",
        "that's reasonable", "i get it", "i hear you", "you're right to feel"
    ]

    private let problemSolvingPhrases = [
        "have you tried", "maybe we could", "what if", "one option is",
        "let me help", "we can figure this out", "here's an idea"
    ]

    private let empathyPhrases = [
        "i'm sorry you're going through", "that must be hard", "i can imagine",
        "i feel for you", "that sounds really", "i'm here for you"
    ]

    private let availabilityPhrases = [
        "i'm here", "call me", "anytime", "whatever you need",
        "let me know", "i've got you", "you can count on me"
    ]

    private let dismissivePhrases = [
        "get over it", "it's not a big deal", "you're overreacting",
        "calm down", "you're being dramatic", "whatever"
    ]

    func analyze(_ messages: [ParsedMessage]) -> SupportAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourSupport = analyzePersonSupport(sent)
        let theirSupport = analyzePersonSupport(received)

        let mutualSupport = yourSupport.score > 40 && theirSupport.score > 40

        return SupportAnalysis(
            you: yourSupport,
            them: theirSupport,
            mutualSupport: mutualSupport,
            summary: mutualSupport ? "Strong mutual emotional support" : "Support score - You: \(yourSupport.score)/100, Them: \(theirSupport.score)/100"
        )
    }

    private func analyzePersonSupport(_ messages: [ParsedMessage]) -> SupportAnalysis.PersonSupport {
        var validating = 0
        var problemSolving = 0
        var empathy = 0
        var availability = 0
        var dismissive = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in validatingPhrases where text.contains(phrase) { validating += 1 }
            for phrase in problemSolvingPhrases where text.contains(phrase) { problemSolving += 1 }
            for phrase in empathyPhrases where text.contains(phrase) { empathy += 1 }
            for phrase in availabilityPhrases where text.contains(phrase) { availability += 1 }
            for phrase in dismissivePhrases where text.contains(phrase) { dismissive += 1 }
        }

        let score = max(0, min(100, (validating * 10) + (problemSolving * 8) + (empathy * 12) + (availability * 10) - (dismissive * 20)))

        return SupportAnalysis.PersonSupport(
            score: score,
            validatingStatements: validating,
            problemSolving: problemSolving,
            empathyShown: empathy,
            availabilityOffered: availability,
            dismissiveStatements: dismissive
        )
    }
}

// MARK: - 27. Validation Pattern Detector

/// Analyzes patterns of validation vs invalidation in the relationship
final class ValidationPatternDetector {

    struct ValidationAnalysis: Codable {
        let you: PersonValidation
        let them: PersonValidation
        let healthScore: Int
        let patterns: [ValidationPattern]
        let summary: String

        struct PersonValidation: Codable {
            let validationScore: Int
            let validations: Int
            let invalidations: Int
            let ratio: Double
        }

        struct ValidationPattern: Codable {
            let type: String
            let frequency: Int
            let isHealthy: Bool
        }
    }

    private let validationPhrases = [
        "you're right", "good point", "i agree", "that's true", "makes sense",
        "i appreciate", "thank you for", "you did great", "well done",
        "i'm proud of you", "you handled that well", "good job"
    ]

    private let invalidationPhrases = [
        "you're wrong", "that's stupid", "no you're not", "stop being",
        "you don't understand", "that's ridiculous", "you shouldn't feel",
        "you're too sensitive", "stop exaggerating", "you always"
    ]

    func analyze(_ messages: [ParsedMessage]) -> ValidationAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourValidation = analyzePersonValidation(sent)
        let theirValidation = analyzePersonValidation(received)

        let patterns = identifyPatterns(yourValidation, theirValidation)
        let healthScore = calculateHealthScore(yourValidation, theirValidation)

        return ValidationAnalysis(
            you: yourValidation,
            them: theirValidation,
            healthScore: healthScore,
            patterns: patterns,
            summary: "Validation health: \(healthScore)/100. \(healthScore > 60 ? "Healthy validation patterns" : "Consider more positive reinforcement")"
        )
    }

    private func analyzePersonValidation(_ messages: [ParsedMessage]) -> ValidationAnalysis.PersonValidation {
        var validations = 0
        var invalidations = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in validationPhrases where text.contains(phrase) { validations += 1 }
            for phrase in invalidationPhrases where text.contains(phrase) { invalidations += 1 }
        }

        let total = validations + invalidations
        let ratio = total > 0 ? Double(validations) / Double(total) : 0.5
        let score = Int(ratio * 100)

        return ValidationAnalysis.PersonValidation(
            validationScore: score,
            validations: validations,
            invalidations: invalidations,
            ratio: ratio
        )
    }

    private func identifyPatterns(_ yours: ValidationAnalysis.PersonValidation, _ theirs: ValidationAnalysis.PersonValidation) -> [ValidationAnalysis.ValidationPattern] {
        var patterns: [ValidationAnalysis.ValidationPattern] = []

        if yours.validations > 5 {
            patterns.append(.init(type: "You validate often", frequency: yours.validations, isHealthy: true))
        }
        if theirs.validations > 5 {
            patterns.append(.init(type: "They validate often", frequency: theirs.validations, isHealthy: true))
        }
        if yours.invalidations > 3 {
            patterns.append(.init(type: "You sometimes invalidate", frequency: yours.invalidations, isHealthy: false))
        }
        if theirs.invalidations > 3 {
            patterns.append(.init(type: "They sometimes invalidate", frequency: theirs.invalidations, isHealthy: false))
        }

        return patterns
    }

    private func calculateHealthScore(_ yours: ValidationAnalysis.PersonValidation, _ theirs: ValidationAnalysis.PersonValidation) -> Int {
        let avgRatio = (yours.ratio + theirs.ratio) / 2
        let totalInvalidations = yours.invalidations + theirs.invalidations
        let penalty = min(30, totalInvalidations * 5)
        return max(0, min(100, Int(avgRatio * 100) - penalty))
    }
}

// MARK: - 28. Growth Mindset Detector

/// Analyzes whether the relationship shows signs of growth and evolution
final class GrowthMindsetDetector {

    struct GrowthAnalysis: Codable {
        let overallGrowth: Int
        let you: PersonGrowth
        let them: PersonGrowth
        let growthAreas: [String]
        let stagnationAreas: [String]
        let summary: String

        struct PersonGrowth: Codable {
            let score: Int
            let learningStatements: Int
            let improvementAcknowledgments: Int
            let goalSetting: Int
            let feedbackAcceptance: Int
            let changeWillingness: Int
        }
    }

    private let learningPhrases = [
        "i learned", "now i understand", "i realize", "i've grown",
        "i'm working on", "i'm trying to", "i want to improve"
    ]

    private let improvementPhrases = [
        "we've gotten better", "look how far we've come", "we're improving",
        "better than before", "making progress", "we've grown"
    ]

    private let goalPhrases = [
        "let's work on", "our goal is", "we should try", "next time",
        "going forward", "i'll try to", "i promise to"
    ]

    private let feedbackPhrases = [
        "you're right, i should", "i appreciate the feedback", "i'll do better",
        "thanks for telling me", "i didn't realize", "point taken"
    ]

    private let changeWillingnessPhrases = [
        "i can change", "let me try", "i'm willing to", "for us i will",
        "i'll work on it", "i want to be better"
    ]

    func analyze(_ messages: [ParsedMessage]) -> GrowthAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourGrowth = analyzePersonGrowth(sent)
        let theirGrowth = analyzePersonGrowth(received)

        let growthAreas = identifyGrowthAreas(sent + received)
        let stagnationAreas = identifyStagnationAreas(sent + received)

        let overallGrowth = (yourGrowth.score + theirGrowth.score) / 2

        return GrowthAnalysis(
            overallGrowth: overallGrowth,
            you: yourGrowth,
            them: theirGrowth,
            growthAreas: growthAreas,
            stagnationAreas: stagnationAreas,
            summary: overallGrowth > 50 ? "Relationship shows growth mindset. Score: \(overallGrowth)/100" : "Growth potential exists. Score: \(overallGrowth)/100"
        )
    }

    private func analyzePersonGrowth(_ messages: [ParsedMessage]) -> GrowthAnalysis.PersonGrowth {
        var learning = 0
        var improvement = 0
        var goals = 0
        var feedback = 0
        var change = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in learningPhrases where text.contains(phrase) { learning += 1 }
            for phrase in improvementPhrases where text.contains(phrase) { improvement += 1 }
            for phrase in goalPhrases where text.contains(phrase) { goals += 1 }
            for phrase in feedbackPhrases where text.contains(phrase) { feedback += 1 }
            for phrase in changeWillingnessPhrases where text.contains(phrase) { change += 1 }
        }

        let score = min(100, (learning * 10) + (improvement * 12) + (goals * 8) + (feedback * 15) + (change * 12))

        return GrowthAnalysis.PersonGrowth(
            score: score,
            learningStatements: learning,
            improvementAcknowledgments: improvement,
            goalSetting: goals,
            feedbackAcceptance: feedback,
            changeWillingness: change
        )
    }

    private func identifyGrowthAreas(_ messages: [ParsedMessage]) -> [String] {
        var areas: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("communication") { areas.append("Communication") }
            if text.contains("trust") { areas.append("Trust") }
            if text.contains("listen") { areas.append("Listening") }
            if text.contains("patient") || text.contains("patience") { areas.append("Patience") }
            if text.contains("understanding") { areas.append("Understanding") }
        }
        return Array(Set(areas))
    }

    private func identifyStagnationAreas(_ messages: [ParsedMessage]) -> [String] {
        var areas: [String] = []
        for msg in messages {
            let text = msg.content.lowercased()
            if text.contains("same thing") || text.contains("always do this") { areas.append("Recurring patterns") }
            if text.contains("never changes") || text.contains("won't change") { areas.append("Resistance to change") }
            if text.contains("we've talked about this") { areas.append("Unresolved issues") }
        }
        return Array(Set(areas))
    }
}
