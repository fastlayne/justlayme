// GreyMirror/Views/GreyMirrorView.swift
// Main container view for Grey Mirror feature

import SwiftUI

struct GreyMirrorView: View {
    @StateObject private var viewModel = GreyMirrorViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color(hex: "0a1628"), Color(hex: "0f2847")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Content based on state
                Group {
                    switch viewModel.analysisState {
                    case .idle:
                        FileImportView(viewModel: viewModel)

                    case .uploading, .parsing, .analyzing:
                        AnalysisProgressView(viewModel: viewModel)

                    case .completed:
                        if viewModel.showingResults, let report = viewModel.currentReport {
                            MetricsDashboardView(viewModel: viewModel, report: report)
                        } else {
                            FileImportView(viewModel: viewModel)
                        }

                    case .failed(let error):
                        ErrorView(error: error) {
                            viewModel.reset()
                        }
                    }
                }
            }
            .navigationTitle("Grey Mirror")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.showingResults {
                        Button("New Analysis") {
                            viewModel.reset()
                        }
                        .foregroundColor(.cyan)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !viewModel.analysisHistory.isEmpty {
                            Menu("History") {
                                ForEach(viewModel.analysisHistory.prefix(5)) { report in
                                    Button {
                                        viewModel.loadHistoryReport(report)
                                    } label: {
                                        Label(
                                            DateFormatter.localizedString(from: report.timestamp, dateStyle: .short, timeStyle: .short),
                                            systemImage: "clock"
                                        )
                                    }
                                }
                            }
                        }

                        if viewModel.currentReport != nil {
                            Divider()
                            Menu("Export") {
                                Button {
                                    exportReport(.json)
                                } label: {
                                    Label("Export JSON", systemImage: "doc.text")
                                }
                                Button {
                                    exportReport(.csv)
                                } label: {
                                    Label("Export CSV", systemImage: "tablecells")
                                }
                                Button {
                                    exportReport(.text)
                                } label: {
                                    Label("Export Text", systemImage: "doc.plaintext")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func exportReport(_ format: GreyMirrorViewModel.ExportFormat) {
        if let url = viewModel.exportReport(format: format) {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Analysis Failed")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(error)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.cyan)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    GreyMirrorView()
}
