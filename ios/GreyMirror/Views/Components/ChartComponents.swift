// GreyMirror/Views/Components/ChartComponents.swift
// Swift Charts components for metrics visualization

import SwiftUI
import Charts

// MARK: - Comparison Chart Card

struct ComparisonChartCard: View {
    let title: String
    let youValue: Double
    let themValue: Double
    let personalization: GreyMirrorReport.Personalization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Chart {
                BarMark(
                    x: .value("Person", personalization.userName),
                    y: .value("Score", youValue)
                )
                .foregroundStyle(.cyan)
                .cornerRadius(6)

                BarMark(
                    x: .value("Person", personalization.contactName),
                    y: .value("Score", themValue)
                )
                .foregroundStyle(.pink)
                .cornerRadius(6)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(.gray)
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Sentiment Pie Chart

struct SentimentPieChart: View {
    let breakdown: SentimentAnalysis.SentimentBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sentiment Breakdown")
                .font(.headline)
                .foregroundColor(.white)

            Chart {
                SectorMark(
                    angle: .value("Count", breakdown.positive),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.green)
                .annotation(position: .overlay) {
                    if breakdown.positive > 0 {
                        Text("\(breakdown.positive)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }

                SectorMark(
                    angle: .value("Count", breakdown.negative),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.red)
                .annotation(position: .overlay) {
                    if breakdown.negative > 0 {
                        Text("\(breakdown.negative)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }

                SectorMark(
                    angle: .value("Count", breakdown.neutral),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.gray)
                .annotation(position: .overlay) {
                    if breakdown.neutral > 0 {
                        Text("\(breakdown.neutral)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(height: 200)

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .green, label: "Positive", value: "\(Int(breakdown.percentages.positive))%")
                LegendItem(color: .red, label: "Negative", value: "\(Int(breakdown.percentages.negative))%")
                LegendItem(color: .gray, label: "Neutral", value: "\(Int(breakdown.percentages.neutral))%")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Sentiment Comparison Bars

struct SentimentComparisonBars: View {
    let comparison: SentimentComparison
    let personalization: GreyMirrorReport.Personalization

    var body: some View {
        VStack(spacing: 16) {
            // You
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(personalization.userName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(comparison.youSentiment.sentiment.capitalized)
                        .font(.caption)
                        .foregroundColor(.cyan)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(sentimentColor(comparison.youSentiment.score))
                            .frame(width: max(0, geometry.size.width * normalizedScore(comparison.youSentiment.score)))
                    }
                }
                .frame(height: 8)
            }

            // Them
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(personalization.contactName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(comparison.themSentiment.sentiment.capitalized)
                        .font(.caption)
                        .foregroundColor(.pink)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(sentimentColor(comparison.themSentiment.score))
                            .frame(width: max(0, geometry.size.width * normalizedScore(comparison.themSentiment.score)))
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func normalizedScore(_ score: Double) -> Double {
        (score + 1) / 2  // Convert -1...1 to 0...1
    }

    private func sentimentColor(_ score: Double) -> Color {
        if score > 0.2 { return .green }
        if score < -0.2 { return .red }
        return .gray
    }
}

// MARK: - Engagement Circle

struct EngagementCircle: View {
    let score: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Engagement Drivers Chart

struct EngagementDriversChart: View {
    let engagement: EngagementAnalysis
    let personalization: GreyMirrorReport.Personalization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engagement Drivers")
                .font(.headline)
                .foregroundColor(.white)

            Chart {
                ForEach(engagement.you.drivers, id: \.name) { driver in
                    BarMark(
                        x: .value("Driver", driver.name),
                        y: .value("Score", driver.score)
                    )
                    .foregroundStyle(.cyan)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(.gray)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 180)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Double Texting Card

struct DoubleTextingCard: View {
    let analysis: DoubleTextingAnalysis
    let personalization: GreyMirrorReport.Personalization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.cyan)
                Text("Double Texting")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            HStack(spacing: 24) {
                VStack {
                    Text("\(analysis.you.doubleTexts)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text(personalization.userName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text("vs")
                    .foregroundColor(.gray)

                VStack {
                    Text("\(analysis.them.doubleTexts)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    Text(personalization.contactName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)

            Text(analysis.comparison.interpretation)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Response Time Card

struct ResponseTimeCard: View {
    let analysis: ResponseTimeAnalysis
    let personalization: GreyMirrorReport.Personalization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.cyan)
                Text("Response Times")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            HStack(spacing: 24) {
                VStack {
                    Text(analysis.you.average)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text(personalization.userName)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(analysis.you.averageReadiness.replacingOccurrences(of: "_", with: " "))
                        .font(.caption2)
                        .foregroundColor(.cyan.opacity(0.7))
                }

                VStack {
                    Text(analysis.them.average)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    Text(personalization.contactName)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(analysis.them.averageReadiness.replacingOccurrences(of: "_", with: " "))
                        .font(.caption2)
                        .foregroundColor(.pink.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)

            Text(analysis.comparison.interpretation)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Communication Patterns Card

struct CommunicationPatternsCard: View {
    let patterns: CommunicationPatterns
    let personalization: GreyMirrorReport.Personalization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(.cyan)
                Text("Communication Patterns")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Message count comparison
            HStack {
                VStack(alignment: .leading) {
                    Text("\(patterns.frequency.youInitiated)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text("from \(personalization.userName)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(patterns.frequency.theyResponded)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    Text("from \(personalization.contactName)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Avg message length
            HStack {
                Text("Avg Length")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(patterns.frequency.averageMessageLength.you) chars (\(personalization.userName))")
                    .font(.caption)
                    .foregroundColor(.cyan)
                Text("/")
                    .foregroundColor(.gray)
                Text("\(patterns.frequency.averageMessageLength.them) chars (\(personalization.contactName))")
                    .font(.caption)
                    .foregroundColor(.pink)
            }

            Text(patterns.frequency.balance.interpretation)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Apology Patterns Card

struct ApologyPatternsCard: View {
    let analysis: ApologyAnalysis
    let personalization: GreyMirrorReport.Personalization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.cyan)
                Text("Apology Patterns")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            HStack(spacing: 24) {
                VStack {
                    Text("\(analysis.you.totalApologies)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text(personalization.userName)
                        .font(.caption)
                        .foregroundColor(.gray)
                    if analysis.you.averageSincerity > 0 {
                        Text("Sincerity: \(analysis.you.averageSincerity)%")
                            .font(.caption2)
                            .foregroundColor(.cyan.opacity(0.7))
                    }
                }

                VStack {
                    Text("\(analysis.them.totalApologies)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    Text(personalization.contactName)
                        .font(.caption)
                        .foregroundColor(.gray)
                    if analysis.them.averageSincerity > 0 {
                        Text("Sincerity: \(analysis.them.averageSincerity)%")
                            .font(.caption2)
                            .foregroundColor(.pink.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Text(analysis.summary)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Toxicity Level Indicator

struct ToxicityLevelIndicator: View {
    let toxicity: ToxicityAnalysis

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(["none", "low", "moderate", "high", "severe"], id: \.self) { level in
                    VStack {
                        Circle()
                            .fill(toxicity.level.rawValue == level ? levelColor(level) : Color.white.opacity(0.1))
                            .frame(width: 16, height: 16)
                        Text(level.capitalized)
                            .font(.caption2)
                            .foregroundColor(toxicity.level.rawValue == level ? levelColor(level) : .gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if toxicity.hasToxicity {
                Text("\(toxicity.toxicMessages) toxic messages (\(String(format: "%.1f", toxicity.toxicityPercentage))%)")
                    .font(.caption)
                    .foregroundColor(levelColor(toxicity.level.rawValue))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "none": return .green
        case "low": return .yellow
        case "moderate": return .orange
        case "high": return .red
        case "severe": return .purple
        default: return .gray
        }
    }
}

// MARK: - Toxicity Comparison Card

struct ToxicityComparisonCard: View {
    let toxicity: ToxicityAnalysis
    let personalization: GreyMirrorReport.Personalization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Toxicity by Person")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 24) {
                VStack {
                    Text("\(Int(toxicity.you.toxicity * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text(personalization.userName)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(toxicity.you.toxicMessages) msgs")
                        .font(.caption2)
                        .foregroundColor(.cyan.opacity(0.7))
                }

                VStack {
                    Text("\(Int(toxicity.them.toxicity * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    Text(personalization.contactName)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(toxicity.them.toxicMessages) msgs")
                        .font(.caption2)
                        .foregroundColor(.pink.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Top Concerns Card

struct TopConcernsCard: View {
    let concerns: [ToxicityAnalysis.ToxicityConcern]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Concerns")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(concerns, id: \.concern) { concern in
                HStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text(concern.concern)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(concern.count)x")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}
