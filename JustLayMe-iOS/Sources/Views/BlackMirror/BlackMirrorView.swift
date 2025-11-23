import SwiftUI
import Charts

struct BlackMirrorView: View {
    @StateObject private var viewModel = BlackMirrorViewModel()
    @State private var showingFilePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.hasResults {
                        // Results View
                        ResultsSection(viewModel: viewModel)
                    } else {
                        // Upload Section
                        UploadSection(viewModel: viewModel, showingFilePicker: $showingFilePicker)
                    }
                }
                .padding()
            }
            .navigationTitle("Black Mirror")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.hasResults {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                viewModel.exportResults()
                            } label: {
                                Label("Export Results", systemImage: "square.and.arrow.up")
                            }

                            Button(role: .destructive) {
                                viewModel.clearResults()
                            } label: {
                                Label("New Analysis", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showExportOptions) {
                ExportSheet(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - Upload Section
struct UploadSection: View {
    @ObservedObject var viewModel: BlackMirrorViewModel
    @Binding var showingFilePicker: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 64))
                    .foregroundStyle(.purple.gradient)

                Text("Relationship Analyzer")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Paste your text messages to analyze communication patterns, sentiment, and relationship health.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Personalization
            VStack(alignment: .leading, spacing: 12) {
                Text("Personalization")
                    .font(.headline)

                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Your name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("You", text: $viewModel.userName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading) {
                        Text("Their name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Them", text: $viewModel.contactName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Text Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Paste Messages")
                        .font(.headline)

                    Spacer()

                    Text("\(viewModel.inputText.count) chars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                Text("Tip: Copy messages from iMessage, WhatsApp, or any chat app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Analyze Button
            Button {
                Task {
                    await viewModel.startAnalysis()
                }
            } label: {
                HStack {
                    if viewModel.isAnalyzing {
                        ProgressView()
                            .tint(.white)
                        Text("Analyzing... \(Int(viewModel.uploadProgress))%")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Analyze Conversation")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canAnalyze ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!viewModel.canAnalyze)

            // Progress Bar
            if viewModel.isAnalyzing {
                ProgressView(value: viewModel.uploadProgress, total: 100)
                    .tint(.purple)
            }
        }
    }
}

// MARK: - Results Section
struct ResultsSection: View {
    @ObservedObject var viewModel: BlackMirrorViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Health Score Header
            HealthScoreCard(
                score: viewModel.healthScore,
                label: viewModel.healthLabel
            )

            // Stats Overview
            if let stats = viewModel.analysisReport?.stats {
                StatsOverview(stats: stats)
            }

            // Summary
            if let summary = viewModel.analysisReport?.summary {
                SummaryCard(summary: summary)
            }

            // Metric Cards
            VStack(spacing: 12) {
                Text("Detailed Metrics")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(viewModel.metricCards) { card in
                    MetricCardView(
                        card: card,
                        isExpanded: viewModel.isMetricExpanded(card.metricId)
                    ) {
                        viewModel.toggleMetric(card.metricId)
                    }
                }
            }

            // Insights
            if let insights = viewModel.analysisReport?.insights, !insights.isEmpty {
                InsightsCard(insights: insights)
            }

            // Recommendations
            if let recommendations = viewModel.analysisReport?.recommendations, !recommendations.isEmpty {
                RecommendationsCard(recommendations: recommendations)
            }
        }
    }
}

// MARK: - Health Score Card
struct HealthScoreCard: View {
    let score: Int
    let label: String

    var color: Color {
        switch label.lowercased() {
        case "healthy": return .green
        case "moderate": return .yellow
        case "concerning": return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(color)

                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 4) {
                Text("Relationship Health")
                    .font(.headline)

                Text(label)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Stats Overview
struct StatsOverview: View {
    let stats: ConversationStats

    var body: some View {
        HStack(spacing: 16) {
            StatItem(
                value: "\(stats.totalMessages)",
                label: "Messages",
                icon: "bubble.left.and.bubble.right"
            )

            StatItem(
                value: "\(stats.yourMessages)",
                label: "You",
                icon: "person"
            )

            StatItem(
                value: "\(stats.theirMessages)",
                label: "Them",
                icon: "person.fill"
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Summary", systemImage: "doc.text")
                .font(.headline)

            Text(summary)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Metric Card View
struct MetricCardView: View {
    let card: MetricCard
    let isExpanded: Bool
    let onTap: () -> Void

    var iconColor: Color {
        switch card.color {
        case "green": return .green
        case "red": return .red
        case "yellow": return .yellow
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                HStack {
                    Image(systemName: card.icon)
                        .font(.title2)
                        .foregroundColor(iconColor)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let subtitle = card.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text(card.value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(iconColor)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isExpanded {
                Divider()

                Text(card.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .animation(.easeInOut, value: isExpanded)
    }
}

// MARK: - Insights Card
struct InsightsCard: View {
    let insights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Insights", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.yellow)

            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.yellow)
                        .padding(.top, 6)

                    Text(insight)
                        .font(.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Recommendations Card
struct RecommendationsCard: View {
    let recommendations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recommendations", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundColor(.green)

            ForEach(recommendations, id: \.self) { rec in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.green)

                    Text(rec)
                        .font(.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Export Sheet
struct ExportSheet: View {
    @ObservedObject var viewModel: BlackMirrorViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let json = viewModel.getExportJSON() {
                    Text("Analysis Report")
                        .font(.headline)

                    ScrollView {
                        Text(json)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }

                    ShareLink(
                        item: json,
                        subject: Text("Black Mirror Analysis"),
                        message: Text("My relationship analysis from JustLayMe")
                    ) {
                        Label("Share Results", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    BlackMirrorView()
}
