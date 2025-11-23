// GreyMirror/Services/ML/AdvancedClassifiers.swift
// 28 Advanced Relationship Classifiers - Making Grey Mirror the ultimate relationship analyzer

import Foundation

// MARK: - 1. Attachment Style Detector
/// Detects anxious, avoidant, secure, or disorganized attachment patterns

final class AttachmentStyleDetector {

    struct AttachmentAnalysis: Codable {
        let you: PersonAttachment
        let them: PersonAttachment
        let compatibility: CompatibilityScore
        let summary: String

        struct PersonAttachment: Codable {
            let primaryStyle: AttachmentStyle
            let scores: [String: Int]  // Style -> score
            let indicators: [String]
            let confidence: Int
        }

        struct CompatibilityScore: Codable {
            let score: Int  // 0-100
            let dynamic: String  // "healthy", "anxious-avoidant trap", etc.
            let challenges: [String]
            let strengths: [String]
        }

        enum AttachmentStyle: String, Codable {
            case secure, anxious, avoidant, disorganized
        }
    }

    private let anxiousIndicators = [
        "why aren't you responding", "are you mad", "did i do something wrong",
        "please respond", "i'm worried", "are we okay", "do you still love me",
        "i miss you so much", "i need you", "don't leave me", "promise me",
        "you're not going to leave right", "i can't stop thinking about you",
        "i just need to know you're okay", "are you ignoring me"
    ]

    private let avoidantIndicators = [
        "i need space", "you're being too much", "stop texting so much",
        "i'm busy", "we don't need to talk every day", "relax", "chill",
        "you're overreacting", "it's not that serious", "i need alone time",
        "stop being so clingy", "i'll text you when i can", "whatever"
    ]

    private let secureIndicators = [
        "i understand", "let's talk about it", "i appreciate you",
        "i'm here for you", "we can work through this", "i respect that",
        "thank you for telling me", "i love spending time with you",
        "take your time", "i trust you", "we're a team"
    ]

    func analyze(_ messages: [ParsedMessage]) -> AttachmentAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourAttachment = analyzePersonAttachment(sent)
        let theirAttachment = analyzePersonAttachment(received)
        let compatibility = calculateCompatibility(yourAttachment, theirAttachment)

        return AttachmentAnalysis(
            you: yourAttachment,
            them: theirAttachment,
            compatibility: compatibility,
            summary: generateSummary(yourAttachment, theirAttachment, compatibility)
        )
    }

    private func analyzePersonAttachment(_ messages: [ParsedMessage]) -> AttachmentAnalysis.PersonAttachment {
        var anxiousScore = 0
        var avoidantScore = 0
        var secureScore = 0
        var indicators: [String] = []

        for msg in messages {
            let text = msg.content.lowercased()

            for indicator in anxiousIndicators {
                if text.contains(indicator) {
                    anxiousScore += 10
                    indicators.append("anxious: \(indicator)")
                }
            }
            for indicator in avoidantIndicators {
                if text.contains(indicator) {
                    avoidantScore += 10
                    indicators.append("avoidant: \(indicator)")
                }
            }
            for indicator in secureIndicators {
                if text.contains(indicator) {
                    secureScore += 10
                    indicators.append("secure: \(indicator)")
                }
            }

            // Response patterns
            if text.count < 5 && ["ok", "k", "fine", "sure", "whatever"].contains(text.trimmingCharacters(in: .whitespaces)) {
                avoidantScore += 5
            }

            // Multiple questions in one message
            let questionCount = text.filter { $0 == "?" }.count
            if questionCount >= 3 {
                anxiousScore += 8
            }
        }

        let total = max(1, anxiousScore + avoidantScore + secureScore)
        let primaryStyle: AttachmentAnalysis.AttachmentStyle

        if secureScore > anxiousScore && secureScore > avoidantScore {
            primaryStyle = .secure
        } else if anxiousScore > avoidantScore {
            primaryStyle = anxiousScore > secureScore * 2 ? .anxious : .secure
        } else {
            primaryStyle = avoidantScore > secureScore * 2 ? .avoidant : .secure
        }

        // Check for disorganized (high in both anxious AND avoidant)
        let finalStyle = (anxiousScore > 50 && avoidantScore > 50) ? .disorganized : primaryStyle

        return AttachmentAnalysis.PersonAttachment(
            primaryStyle: finalStyle,
            scores: ["secure": secureScore, "anxious": anxiousScore, "avoidant": avoidantScore],
            indicators: Array(indicators.prefix(10)),
            confidence: min(100, total / 3)
        )
    }

    private func calculateCompatibility(_ yours: AttachmentAnalysis.PersonAttachment, _ theirs: AttachmentAnalysis.PersonAttachment) -> AttachmentAnalysis.CompatibilityScore {
        var score = 50
        var dynamic = "balanced"
        var challenges: [String] = []
        var strengths: [String] = []

        // Secure + Secure = Best
        if yours.primaryStyle == .secure && theirs.primaryStyle == .secure {
            score = 95
            dynamic = "healthy"
            strengths = ["Strong communication", "Mutual trust", "Emotional availability"]
        }
        // Secure + Anxious = Good with effort
        else if (yours.primaryStyle == .secure && theirs.primaryStyle == .anxious) ||
                (yours.primaryStyle == .anxious && theirs.primaryStyle == .secure) {
            score = 75
            dynamic = "stable with support"
            strengths = ["One partner provides stability"]
            challenges = ["Anxious partner may need extra reassurance"]
        }
        // Secure + Avoidant = Moderate
        else if (yours.primaryStyle == .secure && theirs.primaryStyle == .avoidant) ||
                (yours.primaryStyle == .avoidant && theirs.primaryStyle == .secure) {
            score = 70
            dynamic = "patient growth"
            strengths = ["Secure partner doesn't chase"]
            challenges = ["Avoidant partner may struggle with intimacy"]
        }
        // Anxious + Avoidant = The Trap
        else if (yours.primaryStyle == .anxious && theirs.primaryStyle == .avoidant) ||
                (yours.primaryStyle == .avoidant && theirs.primaryStyle == .anxious) {
            score = 30
            dynamic = "anxious-avoidant trap"
            challenges = ["Push-pull dynamic", "Constant conflict cycle", "Neither feels secure"]
        }
        // Anxious + Anxious = High emotion
        else if yours.primaryStyle == .anxious && theirs.primaryStyle == .anxious {
            score = 45
            dynamic = "high emotion"
            challenges = ["Both need constant reassurance", "Co-dependency risk"]
            strengths = ["Both understand need for connection"]
        }
        // Avoidant + Avoidant = Distant
        else if yours.primaryStyle == .avoidant && theirs.primaryStyle == .avoidant {
            score = 40
            dynamic = "distant"
            challenges = ["Lack of emotional intimacy", "Neither initiates closeness"]
        }

        return AttachmentAnalysis.CompatibilityScore(
            score: score,
            dynamic: dynamic,
            challenges: challenges,
            strengths: strengths
        )
    }

    private func generateSummary(_ yours: AttachmentAnalysis.PersonAttachment, _ theirs: AttachmentAnalysis.PersonAttachment, _ compat: AttachmentAnalysis.CompatibilityScore) -> String {
        "You show \(yours.primaryStyle.rawValue) attachment, they show \(theirs.primaryStyle.rawValue). Compatibility: \(compat.score)/100 (\(compat.dynamic))."
    }
}

// MARK: - 2. Love Language Analyzer
/// Identifies primary love languages for each person

final class LoveLanguageAnalyzer {

    struct LoveLanguageAnalysis: Codable {
        let you: PersonLoveLanguage
        let them: PersonLoveLanguage
        let compatibility: Int
        let mismatches: [String]
        let summary: String

        struct PersonLoveLanguage: Codable {
            let primary: LoveLanguage
            let secondary: LoveLanguage
            let scores: [String: Int]
            let examples: [String]
        }

        enum LoveLanguage: String, Codable {
            case wordsOfAffirmation = "Words of Affirmation"
            case actsOfService = "Acts of Service"
            case receivingGifts = "Receiving Gifts"
            case qualityTime = "Quality Time"
            case physicalTouch = "Physical Touch"
        }
    }

    private let wordsIndicators = [
        "i love you", "you're amazing", "i'm proud of you", "you mean everything",
        "you're beautiful", "i appreciate you", "thank you for", "you're the best",
        "i adore you", "you make me happy", "i'm so lucky", "you're incredible"
    ]

    private let actsIndicators = [
        "let me help", "i'll do it", "i made you", "i picked up", "i cleaned",
        "i cooked", "i fixed", "i'll take care of", "don't worry i got it",
        "i ran errands", "i scheduled", "i organized"
    ]

    private let giftsIndicators = [
        "got you something", "bought you", "surprise for you", "gift for you",
        "picked this up", "saw this and thought of you", "present", "treat for you"
    ]

    private let timeIndicators = [
        "spend time", "hang out", "let's do something", "miss being with you",
        "can't wait to see you", "our date", "together time", "quality time",
        "just us", "let's go somewhere", "weekend together", "movie night"
    ]

    private let touchIndicators = [
        "hug", "kiss", "cuddle", "hold you", "touch you", "miss your touch",
        "want to be close", "in your arms", "snuggle", "embrace", "hold hands"
    ]

    func analyze(_ messages: [ParsedMessage]) -> LoveLanguageAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourLanguage = analyzePersonLanguage(sent)
        let theirLanguage = analyzePersonLanguage(received)

        let compatibility = calculateCompatibility(yourLanguage, theirLanguage)
        let mismatches = findMismatches(yourLanguage, theirLanguage)

        return LoveLanguageAnalysis(
            you: yourLanguage,
            them: theirLanguage,
            compatibility: compatibility,
            mismatches: mismatches,
            summary: "Your primary love language is \(yourLanguage.primary.rawValue). Theirs is \(theirLanguage.primary.rawValue). Compatibility: \(compatibility)%"
        )
    }

    private func analyzePersonLanguage(_ messages: [ParsedMessage]) -> LoveLanguageAnalysis.PersonLoveLanguage {
        var scores: [LoveLanguageAnalysis.LoveLanguage: Int] = [
            .wordsOfAffirmation: 0,
            .actsOfService: 0,
            .receivingGifts: 0,
            .qualityTime: 0,
            .physicalTouch: 0
        ]
        var examples: [String] = []

        for msg in messages {
            let text = msg.content.lowercased()

            for indicator in wordsIndicators {
                if text.contains(indicator) {
                    scores[.wordsOfAffirmation, default: 0] += 10
                    if examples.count < 5 { examples.append("Words: \"\(indicator)\"") }
                }
            }
            for indicator in actsIndicators {
                if text.contains(indicator) {
                    scores[.actsOfService, default: 0] += 10
                    if examples.count < 5 { examples.append("Acts: \"\(indicator)\"") }
                }
            }
            for indicator in giftsIndicators {
                if text.contains(indicator) {
                    scores[.receivingGifts, default: 0] += 10
                    if examples.count < 5 { examples.append("Gifts: \"\(indicator)\"") }
                }
            }
            for indicator in timeIndicators {
                if text.contains(indicator) {
                    scores[.qualityTime, default: 0] += 10
                    if examples.count < 5 { examples.append("Time: \"\(indicator)\"") }
                }
            }
            for indicator in touchIndicators {
                if text.contains(indicator) {
                    scores[.physicalTouch, default: 0] += 10
                    if examples.count < 5 { examples.append("Touch: \"\(indicator)\"") }
                }
            }
        }

        let sorted = scores.sorted { $0.value > $1.value }
        let primary = sorted.first?.key ?? .wordsOfAffirmation
        let secondary = sorted.dropFirst().first?.key ?? .qualityTime

        return LoveLanguageAnalysis.PersonLoveLanguage(
            primary: primary,
            secondary: secondary,
            scores: Dictionary(uniqueKeysWithValues: scores.map { ($0.key.rawValue, $0.value) }),
            examples: examples
        )
    }

    private func calculateCompatibility(_ yours: LoveLanguageAnalysis.PersonLoveLanguage, _ theirs: LoveLanguageAnalysis.PersonLoveLanguage) -> Int {
        if yours.primary == theirs.primary { return 95 }
        if yours.primary == theirs.secondary || yours.secondary == theirs.primary { return 75 }
        if yours.secondary == theirs.secondary { return 60 }
        return 45
    }

    private func findMismatches(_ yours: LoveLanguageAnalysis.PersonLoveLanguage, _ theirs: LoveLanguageAnalysis.PersonLoveLanguage) -> [String] {
        var mismatches: [String] = []
        if yours.primary != theirs.primary {
            mismatches.append("You express love through \(yours.primary.rawValue), but they prefer \(theirs.primary.rawValue)")
        }
        return mismatches
    }
}

// MARK: - 3. Power Dynamics Detector
/// Analyzes who has more control/influence in the relationship

final class PowerDynamicsDetector {

    struct PowerAnalysis: Codable {
        let balance: PowerBalance
        let you: PersonPower
        let them: PersonPower
        let dynamics: [PowerDynamic]
        let healthScore: Int
        let summary: String

        enum PowerBalance: String, Codable {
            case balanced, youDominant, themDominant, unstable
        }

        struct PersonPower: Codable {
            let score: Int  // 0-100
            let controlIndicators: Int
            let submissionIndicators: Int
            let decisionMaking: Int
            let emotionalLeverage: Int
        }

        struct PowerDynamic: Codable {
            let type: String
            let description: String
            let concern: Bool
        }
    }

    private let controlIndicators = [
        "you need to", "you should", "you have to", "i told you to",
        "why didn't you", "you better", "i don't want you to", "don't talk to",
        "where are you", "who are you with", "send me a picture", "prove it",
        "because i said so", "end of discussion", "my way or", "i decide"
    ]

    private let submissionIndicators = [
        "i'm sorry", "you're right", "whatever you want", "if you say so",
        "i'll do whatever", "please don't be mad", "i'll change", "my fault",
        "i was wrong", "you know best", "i'll try harder", "please forgive"
    ]

    func analyze(_ messages: [ParsedMessage]) -> PowerAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourPower = analyzePersonPower(sent)
        let theirPower = analyzePersonPower(received)

        let balance: PowerAnalysis.PowerBalance
        let diff = yourPower.score - theirPower.score

        if abs(diff) < 15 { balance = .balanced }
        else if diff > 15 { balance = .youDominant }
        else { balance = .themDominant }

        let dynamics = identifyDynamics(yourPower, theirPower, sent, received)
        let healthScore = calculateHealthScore(balance, dynamics)

        return PowerAnalysis(
            balance: balance,
            you: yourPower,
            them: theirPower,
            dynamics: dynamics,
            healthScore: healthScore,
            summary: generateSummary(balance, healthScore)
        )
    }

    private func analyzePersonPower(_ messages: [ParsedMessage]) -> PowerAnalysis.PersonPower {
        var controlCount = 0
        var submissionCount = 0
        var decisionCount = 0
        var emotionalLeverage = 0

        for msg in messages {
            let text = msg.content.lowercased()

            for indicator in controlIndicators {
                if text.contains(indicator) { controlCount += 1 }
            }
            for indicator in submissionIndicators {
                if text.contains(indicator) { submissionCount += 1 }
            }

            // Decision making
            if text.contains("let's") || text.contains("we should") || text.contains("how about") {
                decisionCount += 1
            }

            // Emotional leverage
            if text.contains("if you loved me") || text.contains("after everything i") {
                emotionalLeverage += 5
            }
        }

        let powerScore = 50 + (controlCount * 5) - (submissionCount * 5)

        return PowerAnalysis.PersonPower(
            score: max(0, min(100, powerScore)),
            controlIndicators: controlCount,
            submissionIndicators: submissionCount,
            decisionMaking: decisionCount,
            emotionalLeverage: emotionalLeverage
        )
    }

    private func identifyDynamics(_ yours: PowerAnalysis.PersonPower, _ theirs: PowerAnalysis.PersonPower, _ sent: [ParsedMessage], _ received: [ParsedMessage]) -> [PowerAnalysis.PowerDynamic] {
        var dynamics: [PowerAnalysis.PowerDynamic] = []

        if yours.controlIndicators > 10 {
            dynamics.append(.init(type: "Controlling Language", description: "You use controlling language frequently", concern: true))
        }
        if theirs.controlIndicators > 10 {
            dynamics.append(.init(type: "Partner Control", description: "They use controlling language frequently", concern: true))
        }
        if yours.submissionIndicators > theirs.submissionIndicators * 2 {
            dynamics.append(.init(type: "Imbalanced Submission", description: "You apologize/submit significantly more", concern: true))
        }
        if yours.emotionalLeverage > 0 || theirs.emotionalLeverage > 0 {
            dynamics.append(.init(type: "Emotional Manipulation", description: "Signs of emotional leverage detected", concern: true))
        }

        return dynamics
    }

    private func calculateHealthScore(_ balance: PowerAnalysis.PowerBalance, _ dynamics: [PowerAnalysis.PowerDynamic]) -> Int {
        var score = balance == .balanced ? 80 : 50
        score -= dynamics.filter { $0.concern }.count * 15
        return max(0, min(100, score))
    }

    private func generateSummary(_ balance: PowerAnalysis.PowerBalance, _ health: Int) -> String {
        switch balance {
        case .balanced: return "Power dynamics appear balanced (\(health)/100 health)"
        case .youDominant: return "You appear to have more control in the relationship"
        case .themDominant: return "They appear to have more control in the relationship"
        case .unstable: return "Power dynamics appear unstable and shifting"
        }
    }
}

// MARK: - 4. Emotional Labor Tracker
/// Tracks who does more emotional work in the relationship

final class EmotionalLaborTracker {

    struct EmotionalLaborAnalysis: Codable {
        let you: PersonLabor
        let them: PersonLabor
        let balance: LaborBalance
        let burnoutRisk: BurnoutRisk
        let summary: String

        struct PersonLabor: Codable {
            let score: Int
            let initiatingConversations: Int
            let askingAboutDay: Int
            let offeringSupport: Int
            let rememberingDetails: Int
            let planningDates: Int
            let managingConflict: Int
        }

        enum LaborBalance: String, Codable {
            case balanced, youCarryMore, theyCarryMore, bothLow
        }

        enum BurnoutRisk: String, Codable {
            case low, moderate, high, critical
        }
    }

    private let supportPhrases = [
        "how are you", "how was your day", "are you okay", "what's wrong",
        "i'm here for you", "do you need anything", "let me help",
        "that must be hard", "i understand", "tell me about it"
    ]

    private let planningPhrases = [
        "let's plan", "we should do", "i made reservations", "i booked",
        "i scheduled", "how about we", "want to go to", "i found a place"
    ]

    func analyze(_ messages: [ParsedMessage]) -> EmotionalLaborAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourLabor = analyzePersonLabor(sent, all: messages)
        let theirLabor = analyzePersonLabor(received, all: messages)

        let balance: EmotionalLaborAnalysis.LaborBalance
        let diff = yourLabor.score - theirLabor.score

        if abs(diff) < 15 { balance = .balanced }
        else if diff > 15 { balance = .youCarryMore }
        else { balance = .theyCarryMore }

        let burnoutRisk = calculateBurnoutRisk(yourLabor, theirLabor, balance)

        return EmotionalLaborAnalysis(
            you: yourLabor,
            them: theirLabor,
            balance: balance,
            burnoutRisk: burnoutRisk,
            summary: generateSummary(balance, burnoutRisk)
        )
    }

    private func analyzePersonLabor(_ messages: [ParsedMessage], all: [ParsedMessage]) -> EmotionalLaborAnalysis.PersonLabor {
        var initiating = 0
        var askingAboutDay = 0
        var offeringSupport = 0
        var rememberingDetails = 0
        var planningDates = 0
        var managingConflict = 0

        // Count conversation initiations (first message after >1 hour gap)
        for (i, msg) in all.enumerated() where msg.direction == messages.first?.direction {
            if i == 0 || (msg.timeSinceLast ?? 0) > 3600 {
                initiating += 1
            }
        }

        for msg in messages {
            let text = msg.content.lowercased()

            if text.contains("how are you") || text.contains("how was your") {
                askingAboutDay += 1
            }

            for phrase in supportPhrases {
                if text.contains(phrase) { offeringSupport += 1 }
            }

            for phrase in planningPhrases {
                if text.contains(phrase) { planningDates += 1 }
            }

            // Remembering details
            if text.contains("you mentioned") || text.contains("you said") || text.contains("remember when") {
                rememberingDetails += 1
            }

            // Managing conflict
            if text.contains("let's calm down") || text.contains("can we talk about") || text.contains("i think we should discuss") {
                managingConflict += 1
            }
        }

        let score = (initiating * 3) + (askingAboutDay * 5) + (offeringSupport * 4) +
                    (rememberingDetails * 6) + (planningDates * 5) + (managingConflict * 4)

        return EmotionalLaborAnalysis.PersonLabor(
            score: min(100, score),
            initiatingConversations: initiating,
            askingAboutDay: askingAboutDay,
            offeringSupport: offeringSupport,
            rememberingDetails: rememberingDetails,
            planningDates: planningDates,
            managingConflict: managingConflict
        )
    }

    private func calculateBurnoutRisk(_ yours: EmotionalLaborAnalysis.PersonLabor, _ theirs: EmotionalLaborAnalysis.PersonLabor, _ balance: EmotionalLaborAnalysis.LaborBalance) -> EmotionalLaborAnalysis.BurnoutRisk {
        if balance == .balanced { return .low }
        let diff = abs(yours.score - theirs.score)
        if diff > 60 { return .critical }
        if diff > 40 { return .high }
        if diff > 20 { return .moderate }
        return .low
    }

    private func generateSummary(_ balance: EmotionalLaborAnalysis.LaborBalance, _ risk: EmotionalLaborAnalysis.BurnoutRisk) -> String {
        switch balance {
        case .balanced: return "Emotional labor is well-distributed. Burnout risk: \(risk.rawValue)"
        case .youCarryMore: return "You carry significantly more emotional labor. Burnout risk: \(risk.rawValue)"
        case .theyCarryMore: return "They carry more emotional labor. Burnout risk: \(risk.rawValue)"
        case .bothLow: return "Both show low emotional labor investment"
        }
    }
}

// MARK: - 5. Breadcrumbing Detector
/// Detects minimal-effort communication to keep someone interested

final class BreadcrumbingDetector {

    struct BreadcrumbingAnalysis: Codable {
        let detected: Bool
        let you: PersonBreadcrumbing
        let them: PersonBreadcrumbing
        let severity: Severity
        let patterns: [String]
        let summary: String

        struct PersonBreadcrumbing: Codable {
            let score: Int  // 0-100, higher = more breadcrumbing
            let shortResponses: Int
            let vaguePlans: Int
            let lateNightOnly: Int
            let inconsistentTiming: Bool
            let ghostingThenReturning: Int
        }

        enum Severity: String, Codable {
            case none, mild, moderate, severe
        }
    }

    private let vaguePlanPhrases = [
        "we should hang out sometime", "let's do something soon", "maybe next week",
        "i'll let you know", "we'll see", "sounds good", "definitely", "for sure",
        "one of these days", "when i'm free"
    ]

    func analyze(_ messages: [ParsedMessage]) -> BreadcrumbingAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourBreadcrumbing = analyzePersonBreadcrumbing(sent, all: messages)
        let theirBreadcrumbing = analyzePersonBreadcrumbing(received, all: messages)

        let detected = theirBreadcrumbing.score > 40 || yourBreadcrumbing.score > 40
        let severity: BreadcrumbingAnalysis.Severity

        let maxScore = max(yourBreadcrumbing.score, theirBreadcrumbing.score)
        if maxScore < 20 { severity = .none }
        else if maxScore < 40 { severity = .mild }
        else if maxScore < 60 { severity = .moderate }
        else { severity = .severe }

        let patterns = identifyPatterns(yourBreadcrumbing, theirBreadcrumbing)

        return BreadcrumbingAnalysis(
            detected: detected,
            you: yourBreadcrumbing,
            them: theirBreadcrumbing,
            severity: severity,
            patterns: patterns,
            summary: detected ? "Breadcrumbing patterns detected (\(severity.rawValue))" : "No significant breadcrumbing detected"
        )
    }

    private func analyzePersonBreadcrumbing(_ messages: [ParsedMessage], all: [ParsedMessage]) -> BreadcrumbingAnalysis.PersonBreadcrumbing {
        var shortResponses = 0
        var vaguePlans = 0
        var lateNightOnly = 0
        var ghostingThenReturning = 0

        for msg in messages {
            // Short responses
            if msg.content.count < 10 {
                shortResponses += 1
            }

            // Vague plans
            let text = msg.content.lowercased()
            for phrase in vaguePlanPhrases {
                if text.contains(phrase) { vaguePlans += 1 }
            }

            // Late night messaging (10pm - 3am)
            let hour = Calendar.current.component(.hour, from: msg.timestamp)
            if hour >= 22 || hour < 3 {
                lateNightOnly += 1
            }
        }

        // Detect ghosting then returning
        var lastMessageTime: Date?
        for msg in all {
            if let last = lastMessageTime {
                let gap = msg.timestamp.timeIntervalSince(last)
                if gap > 86400 * 3 { // 3+ days
                    ghostingThenReturning += 1
                }
            }
            lastMessageTime = msg.timestamp
        }

        let shortPercent = messages.isEmpty ? 0 : (shortResponses * 100) / messages.count
        let latePercent = messages.isEmpty ? 0 : (lateNightOnly * 100) / messages.count

        let score = min(100, shortPercent + (vaguePlans * 5) + (ghostingThenReturning * 15) + (latePercent > 50 ? 20 : 0))

        return BreadcrumbingAnalysis.PersonBreadcrumbing(
            score: score,
            shortResponses: shortResponses,
            vaguePlans: vaguePlans,
            lateNightOnly: lateNightOnly,
            inconsistentTiming: latePercent > 50,
            ghostingThenReturning: ghostingThenReturning
        )
    }

    private func identifyPatterns(_ yours: BreadcrumbingAnalysis.PersonBreadcrumbing, _ theirs: BreadcrumbingAnalysis.PersonBreadcrumbing) -> [String] {
        var patterns: [String] = []

        if theirs.shortResponses > 10 {
            patterns.append("They frequently give very short responses")
        }
        if theirs.vaguePlans > 5 {
            patterns.append("They make vague plans that never materialize")
        }
        if theirs.inconsistentTiming {
            patterns.append("They only message late at night")
        }
        if theirs.ghostingThenReturning > 2 {
            patterns.append("They ghost then return repeatedly")
        }

        return patterns
    }
}

// MARK: - 6. Interest Level Scorer
/// Calculates who is more interested in the relationship

final class InterestLevelScorer {

    struct InterestAnalysis: Codable {
        let you: PersonInterest
        let them: PersonInterest
        let gap: InterestGap
        let prediction: String
        let summary: String

        struct PersonInterest: Codable {
            let score: Int  // 0-100
            let initiationRate: Double
            let responseSpeed: String
            let messageLength: Int
            let questionAsking: Int
            let futureReferences: Int
            let enthusiasmLevel: String
        }

        struct InterestGap: Codable {
            let difference: Int
            let moreInterested: String
            let sustainable: Bool
        }
    }

    func analyze(_ messages: [ParsedMessage]) -> InterestAnalysis {
        let sent = messages.filter { $0.direction == .sent }
        let received = messages.filter { $0.direction == .received }

        let yourInterest = analyzePersonInterest(sent, all: messages, direction: .sent)
        let theirInterest = analyzePersonInterest(received, all: messages, direction: .received)

        let diff = yourInterest.score - theirInterest.score
        let moreInterested = diff > 10 ? "you" : diff < -10 ? "them" : "equal"
        let sustainable = abs(diff) < 25

        let prediction = generatePrediction(yourInterest, theirInterest, diff)

        return InterestAnalysis(
            you: yourInterest,
            them: theirInterest,
            gap: InterestAnalysis.InterestGap(
                difference: abs(diff),
                moreInterested: moreInterested,
                sustainable: sustainable
            ),
            prediction: prediction,
            summary: "Interest gap: \(abs(diff)) points. \(moreInterested == "equal" ? "Both equally interested" : "\(moreInterested == "you" ? "You" : "They") show more interest")"
        )
    }

    private func analyzePersonInterest(_ messages: [ParsedMessage], all: [ParsedMessage], direction: ParsedMessage.MessageDirection) -> InterestAnalysis.PersonInterest {
        guard !messages.isEmpty else {
            return InterestAnalysis.PersonInterest(score: 0, initiationRate: 0, responseSpeed: "N/A", messageLength: 0, questionAsking: 0, futureReferences: 0, enthusiasmLevel: "none")
        }

        // Initiation rate
        var initiations = 0
        for (i, msg) in all.enumerated() where msg.direction == direction {
            if i == 0 || (msg.timeSinceLast ?? 0) > 3600 { initiations += 1 }
        }
        let initiationRate = Double(initiations) / Double(all.filter { $0.direction == direction }.count + 1)

        // Message length
        let avgLength = messages.reduce(0) { $0 + $1.length } / messages.count

        // Questions
        let questions = messages.filter { $0.content.contains("?") }.count

        // Future references
        let futureWords = ["tomorrow", "next week", "weekend", "later", "future", "someday", "planning"]
        var futureRefs = 0
        for msg in messages {
            let text = msg.content.lowercased()
            for word in futureWords {
                if text.contains(word) { futureRefs += 1; break }
            }
        }

        // Enthusiasm
        let exclamations = messages.reduce(0) { $0 + $1.content.filter { $0 == "!" }.count }
        let enthusiasmLevel = exclamations > messages.count ? "high" : exclamations > messages.count / 2 ? "moderate" : "low"

        // Calculate score
        var score = 50
        score += Int(initiationRate * 20)
        score += min(avgLength / 10, 15)
        score += min(questions * 2, 15)
        score += min(futureRefs * 5, 15)
        if enthusiasmLevel == "high" { score += 10 }
        else if enthusiasmLevel == "moderate" { score += 5 }

        return InterestAnalysis.PersonInterest(
            score: min(100, score),
            initiationRate: initiationRate,
            responseSpeed: "varies",
            messageLength: avgLength,
            questionAsking: questions,
            futureReferences: futureRefs,
            enthusiasmLevel: enthusiasmLevel
        )
    }

    private func generatePrediction(_ yours: InterestAnalysis.PersonInterest, _ theirs: InterestAnalysis.PersonInterest, _ diff: Int) -> String {
        if abs(diff) < 10 {
            return "Both parties show similar interest levels - healthy dynamic"
        } else if abs(diff) < 25 {
            return "Slight interest imbalance - monitor for changes"
        } else if abs(diff) < 40 {
            return "Noticeable interest gap - may cause friction"
        } else {
            return "Significant interest imbalance - relationship at risk"
        }
    }
}

// MARK: - 7. Red Flag Detector
/// Identifies warning signs in relationship communication

final class RedFlagDetector {

    struct RedFlagAnalysis: Codable {
        let flagsDetected: Int
        let severity: Severity
        let flags: [RedFlag]
        let riskScore: Int
        let summary: String

        struct RedFlag: Codable {
            let category: Category
            let description: String
            let examples: [String]
            let severity: Severity
        }

        enum Category: String, Codable {
            case manipulation, control, disrespect, dishonesty, aggression, isolation
        }

        enum Severity: String, Codable {
            case low, moderate, high, critical
        }
    }

    private let manipulationPhrases = [
        "if you really loved me", "after everything i've done", "you owe me",
        "no one else would put up with you", "you're lucky i'm with you",
        "you made me do this", "it's your fault", "you're the reason"
    ]

    private let controlPhrases = [
        "where are you", "who are you with", "send me a picture",
        "i don't want you talking to", "you can't go", "you're not allowed",
        "check in with me", "i need to know where you are at all times"
    ]

    private let disrespectPhrases = [
        "you're stupid", "you're an idiot", "you're worthless", "you're pathetic",
        "no one likes you", "you're embarrassing", "shut up", "you're crazy"
    ]

    private let isolationPhrases = [
        "your friends don't like me", "your family is against us",
        "you spend too much time with", "it's them or me", "they're a bad influence"
    ]

    func analyze(_ messages: [ParsedMessage]) -> RedFlagAnalysis {
        var flags: [RedFlagAnalysis.RedFlag] = []
        var examples: [String: [String]] = [:]

        for msg in messages {
            let text = msg.content.lowercased()
            let who = msg.direction == .sent ? "You" : "They"

            for phrase in manipulationPhrases {
                if text.contains(phrase) {
                    examples["manipulation", default: []].append("\(who): \"\(phrase)\"")
                }
            }
            for phrase in controlPhrases {
                if text.contains(phrase) {
                    examples["control", default: []].append("\(who): \"\(phrase)\"")
                }
            }
            for phrase in disrespectPhrases {
                if text.contains(phrase) {
                    examples["disrespect", default: []].append("\(who): \"\(phrase)\"")
                }
            }
            for phrase in isolationPhrases {
                if text.contains(phrase) {
                    examples["isolation", default: []].append("\(who): \"\(phrase)\"")
                }
            }
        }

        // Create flags
        if !examples["manipulation", default: []].isEmpty {
            flags.append(.init(category: .manipulation, description: "Emotional manipulation detected", examples: Array(examples["manipulation"]!.prefix(3)), severity: .high))
        }
        if !examples["control", default: []].isEmpty {
            flags.append(.init(category: .control, description: "Controlling behavior detected", examples: Array(examples["control"]!.prefix(3)), severity: .high))
        }
        if !examples["disrespect", default: []].isEmpty {
            flags.append(.init(category: .disrespect, description: "Disrespectful language detected", examples: Array(examples["disrespect"]!.prefix(3)), severity: .moderate))
        }
        if !examples["isolation", default: []].isEmpty {
            flags.append(.init(category: .isolation, description: "Isolation attempts detected", examples: Array(examples["isolation"]!.prefix(3)), severity: .critical))
        }

        let riskScore = calculateRiskScore(flags)
        let severity = flags.contains { $0.severity == .critical } ? .critical :
                       flags.contains { $0.severity == .high } ? .high :
                       flags.isEmpty ? .low : .moderate

        return RedFlagAnalysis(
            flagsDetected: flags.count,
            severity: severity,
            flags: flags,
            riskScore: riskScore,
            summary: flags.isEmpty ? "No significant red flags detected" : "\(flags.count) red flags detected. Risk score: \(riskScore)/100"
        )
    }

    private func calculateRiskScore(_ flags: [RedFlagAnalysis.RedFlag]) -> Int {
        var score = 0
        for flag in flags {
            switch flag.severity {
            case .critical: score += 40
            case .high: score += 25
            case .moderate: score += 15
            case .low: score += 5
            }
        }
        return min(100, score)
    }
}

// MARK: - 8. Green Flag Detector
/// Identifies positive signs in relationship communication

final class GreenFlagDetector {

    struct GreenFlagAnalysis: Codable {
        let flagsDetected: Int
        let healthScore: Int
        let flags: [GreenFlag]
        let strengths: [String]
        let summary: String

        struct GreenFlag: Codable {
            let category: Category
            let description: String
            let examples: [String]
            let strength: Int
        }

        enum Category: String, Codable {
            case respect, communication, support, growth, trust, affection
        }
    }

    private let respectPhrases = [
        "i respect your", "your opinion matters", "i value you",
        "that's a great point", "i appreciate your perspective", "you're right"
    ]

    private let supportPhrases = [
        "i'm here for you", "how can i help", "i support you",
        "i believe in you", "you've got this", "i'm proud of you"
    ]

    private let growthPhrases = [
        "we can work on this", "let's improve", "i want to be better",
        "let's grow together", "what can we do differently", "i'm learning"
    ]

    private let trustPhrases = [
        "i trust you", "i know you", "i believe you",
        "take your time", "do what you need to do", "i have faith in us"
    ]

    private let affectionPhrases = [
        "i love you", "i care about you", "you mean so much",
        "i'm grateful for you", "you make me happy", "i adore you"
    ]

    func analyze(_ messages: [ParsedMessage]) -> GreenFlagAnalysis {
        var flags: [GreenFlagAnalysis.GreenFlag] = []
        var examples: [String: [String]] = [:]

        for msg in messages {
            let text = msg.content.lowercased()

            for phrase in respectPhrases where text.contains(phrase) {
                examples["respect", default: []].append(phrase)
            }
            for phrase in supportPhrases where text.contains(phrase) {
                examples["support", default: []].append(phrase)
            }
            for phrase in growthPhrases where text.contains(phrase) {
                examples["growth", default: []].append(phrase)
            }
            for phrase in trustPhrases where text.contains(phrase) {
                examples["trust", default: []].append(phrase)
            }
            for phrase in affectionPhrases where text.contains(phrase) {
                examples["affection", default: []].append(phrase)
            }
        }

        // Create flags
        if !examples["respect", default: []].isEmpty {
            flags.append(.init(category: .respect, description: "Mutual respect shown", examples: Array(Set(examples["respect"]!)).prefix(3).map { String($0) }, strength: examples["respect"]!.count * 5))
        }
        if !examples["support", default: []].isEmpty {
            flags.append(.init(category: .support, description: "Emotional support present", examples: Array(Set(examples["support"]!)).prefix(3).map { String($0) }, strength: examples["support"]!.count * 5))
        }
        if !examples["growth", default: []].isEmpty {
            flags.append(.init(category: .growth, description: "Growth mindset present", examples: Array(Set(examples["growth"]!)).prefix(3).map { String($0) }, strength: examples["growth"]!.count * 5))
        }
        if !examples["trust", default: []].isEmpty {
            flags.append(.init(category: .trust, description: "Trust indicators present", examples: Array(Set(examples["trust"]!)).prefix(3).map { String($0) }, strength: examples["trust"]!.count * 5))
        }
        if !examples["affection", default: []].isEmpty {
            flags.append(.init(category: .affection, description: "Affection expressed", examples: Array(Set(examples["affection"]!)).prefix(3).map { String($0) }, strength: examples["affection"]!.count * 5))
        }

        let healthScore = min(100, flags.reduce(0) { $0 + $1.strength })
        let strengths = flags.map { $0.category.rawValue.capitalized }

        return GreenFlagAnalysis(
            flagsDetected: flags.count,
            healthScore: healthScore,
            flags: flags,
            strengths: strengths,
            summary: flags.isEmpty ? "Few positive indicators detected" : "\(flags.count) green flags detected. Relationship health: \(healthScore)/100"
        )
    }
}

// MARK: - Continue with more classifiers...
// (Adding remaining 20 classifiers in the next file due to length)
