// GreyMirror/Views/Dashboard/MetricsDashboardView.swift
// Comprehensive metrics dashboard with Swift Charts

import SwiftUI
import Charts

struct MetricsDashboardView: View {
    @ObservedObject var viewModel: GreyMirrorViewModel
    let report: GreyMirrorReport
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Stats
                headerStats

                // Tab Selector
                tabSelector

                // Tab Content
                tabContent

                // Insights Section
                insightsSection

                // Recommendations Section
                recommendationsSection
            }
            .padding()
        }
    }

    // MARK: - Header Stats

    private var headerStats: some View {
        VStack(spacing: 16) {
            // Health Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(report.healthScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: healthGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(report.healthScore)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text("Health")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Status Badge
            Text(report.positivity?.health.rawValue.uppercased() ?? "UNKNOWN")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(healthColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(healthColor.opacity(0.15))
                .cornerRadius(20)

            // Quick Stats Row
            HStack(spacing: 24) {
                StatItem(
                    icon: "message.fill",
                    value: "\(report.messageCount)",
                    label: "Messages"
                )
                StatItem(
                    icon: "person.2.fill",
                    value: "\(report.stats.uniqueSenders)",
                    label: "Participants"
                )
                StatItem(
                    icon: "calendar",
                    value: formatDateRange(),
                    label: "Period"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var healthGradient: [Color] {
        if report.healthScore >= 70 { return [.green, .mint] }
        if report.healthScore >= 40 { return [.yellow, .orange] }
        return [.red, .pink]
    }

    private var healthColor: Color {
        if report.healthScore >= 70 { return .green }
        if report.healthScore >= 40 { return .yellow }
        return .red
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                TabButton(title: "Overview", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabButton(title: "Sentiment", isSelected: selectedTab == 1) { selectedTab = 1 }
                TabButton(title: "Engagement", isSelected: selectedTab == 2) { selectedTab = 2 }
                TabButton(title: "Patterns", isSelected: selectedTab == 3) { selectedTab = 3 }
                TabButton(title: "Toxicity", isSelected: selectedTab == 4) { selectedTab = 4 }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            overviewTab
        case 1:
            sentimentTab
        case 2:
            engagementTab
        case 3:
            patternsTab
        case 4:
            toxicityTab
        default:
            overviewTab
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 16) {
            // Comparison Chart
            if let positivity = report.positivity {
                ComparisonChartCard(
                    title: "Positivity Comparison",
                    youValue: Double(positivity.you.score),
                    themValue: Double(positivity.them.score),
                    personalization: report.personalization
                )
            }

            // Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Sentiment",
                    value: report.sentiment?.sentiment.rawValue.capitalized ?? "—",
                    icon: "face.smiling",
                    color: .cyan
                )
                MetricCard(
                    title: "Engagement",
                    value: report.engagement?.level.rawValue.replacingOccurrences(of: "_", with: " ").capitalized ?? "—",
                    icon: "heart.fill",
                    color: .pink
                )
                MetricCard(
                    title: "Toxicity",
                    value: report.toxicity?.level.rawValue.capitalized ?? "None",
                    icon: "exclamationmark.triangle",
                    color: report.toxicity?.hasToxicity == true ? .orange : .green
                )
                MetricCard(
                    title: "Trend",
                    value: report.positivity?.trend.capitalized ?? "—",
                    icon: trendIcon,
                    color: trendColor
                )
            }

            // Double Texting Summary
            if let dt = report.doubleTexting, dt.hasDoubleTexts {
                DoubleTextingCard(analysis: dt, personalization: report.personalization)
            }
        }
    }

    private var trendIcon: String {
        switch report.positivity?.trend {
        case "improving": return "chart.line.uptrend.xyaxis"
        case "declining": return "chart.line.downtrend.xyaxis"
        default: return "chart.line.flattrend.xyaxis"
        }
    }

    private var trendColor: Color {
        switch report.positivity?.trend {
        case "improving": return .green
        case "declining": return .red
        default: return .gray
        }
    }

    // MARK: - Sentiment Tab

    private var sentimentTab: some View {
        VStack(spacing: 16) {
            if let sentiment = report.sentiment {
                // Sentiment Breakdown Pie Chart
                SentimentPieChart(breakdown: sentiment.breakdown)

                // Per-Person Sentiment
                if let comparison = report.sentimentComparison {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sentiment by Person")
                            .font(.headline)
                            .foregroundColor(.white)

                        SentimentComparisonBars(
                            comparison: comparison,
                            personalization: report.personalization
                        )
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                }

                // Summary
                Text(sentiment.summary)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            }
        }
    }

    // MARK: - Engagement Tab

    private var engagementTab: some View {
        VStack(spacing: 16) {
            if let engagement = report.engagement {
                // Engagement Scores
                HStack(spacing: 16) {
                    EngagementCircle(
                        score: engagement.you.score,
                        label: report.personalization.userName,
                        color: .cyan
                    )
                    EngagementCircle(
                        score: engagement.them.score,
                        label: report.personalization.contactName,
                        color: .pink
                    )
                }

                // Drivers Chart
                if !engagement.you.drivers.isEmpty || !engagement.them.drivers.isEmpty {
                    EngagementDriversChart(engagement: engagement, personalization: report.personalization)
                }

                // Summary
                Text(engagement.summary)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            }
        }
    }

    // MARK: - Patterns Tab

    private var patternsTab: some View {
        VStack(spacing: 16) {
            // Response Times
            if let rt = report.responseTimes {
                ResponseTimeCard(analysis: rt, personalization: report.personalization)
            }

            // Communication Patterns
            if let patterns = report.communicationPatterns {
                CommunicationPatternsCard(patterns: patterns, personalization: report.personalization)
            }

            // Apology Patterns
            if let apologies = report.apologyPatterns, apologies.hasApologies {
                ApologyPatternsCard(analysis: apologies, personalization: report.personalization)
            }
        }
    }

    // MARK: - Toxicity Tab

    private var toxicityTab: some View {
        VStack(spacing: 16) {
            if let toxicity = report.toxicity {
                // Toxicity Level Indicator
                ToxicityLevelIndicator(toxicity: toxicity)

                // Per-Person Breakdown
                ToxicityComparisonCard(toxicity: toxicity, personalization: report.personalization)

                // Top Concerns
                if !toxicity.topConcerns.isEmpty {
                    TopConcernsCard(concerns: toxicity.topConcerns)
                }

                // Summary
                Text(toxicity.summary)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            }
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY INSIGHTS")
                .font(.caption)
                .foregroundColor(.gray)
                .tracking(2)

            ForEach(Array(report.insights.enumerated()), id: \.offset) { index, insight in
                InsightRow(insight: insight)
            }

            if report.insights.isEmpty {
                Text("No significant insights detected")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDATIONS")
                .font(.caption)
                .foregroundColor(.gray)
                .tracking(2)

            ForEach(Array(report.recommendations.enumerated()), id: \.offset) { index, rec in
                RecommendationRow(recommendation: rec)
            }

            if report.recommendations.isEmpty {
                Text("No recommendations at this time")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Helpers

    private func formatDateRange() -> String {
        guard let range = report.stats.dateRange else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        if days < 30 { return "\(days)d" }
        if days < 365 { return "\(days / 30)mo" }
        return "\(days / 365)yr"
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.cyan.opacity(0.2) : Color.clear)
                )
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }
}

struct InsightRow: View {
    let insight: GreyMirrorReport.KeyInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.category.uppercased())
                    .font(.caption2)
                    .foregroundColor(priorityColor)
                Text(insight.insight)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
    }

    private var priorityColor: Color {
        switch insight.importance {
        case "high": return .red
        case "medium": return .orange
        default: return .cyan
        }
    }
}

struct RecommendationRow: View {
    let recommendation: GreyMirrorReport.Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recommendation.action)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text(recommendation.priority.uppercased())
                    .font(.caption2)
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.15))
                    .cornerRadius(4)
            }
            Text(recommendation.details)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }

    private var priorityColor: Color {
        switch recommendation.priority {
        case "high": return .red
        case "medium": return .orange
        default: return .green
        }
    }
}

#Preview {
    MetricsDashboardView(
        viewModel: GreyMirrorViewModel(),
        report: GreyMirrorReport(
            id: UUID(),
            timestamp: Date(),
            success: true,
            error: nil,
            stats: ConversationStats(totalMessages: 150, uniqueSenders: 2, dateRange: nil, averageMessageLength: 45),
            healthScore: 72,
            messageCount: 150,
            sentiment: nil,
            sentimentComparison: nil,
            toxicity: nil,
            engagement: nil,
            doubleTexting: nil,
            responseTimes: nil,
            apologyPatterns: nil,
            positivity: nil,
            communicationPatterns: nil,
            summary: "Overall healthy relationship",
            insights: [],
            recommendations: [],
            personalization: .init(userName: "You", contactName: "Them", insightsGoal: "")
        )
    )
    .background(Color.black)
    .preferredColorScheme(.dark)
}
