// GreyMirror/ViewModels/GreyMirrorViewModel.swift
// Main ViewModel with Combine for Grey Mirror feature
// Handles all states, analysis execution, and history management

import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers
import UIKit

@MainActor
final class GreyMirrorViewModel: ObservableObject {

    // MARK: - Published State

    // Analysis state
    @Published var analysisState: AnalysisState = .idle
    @Published var currentClassifier: String = ""
    @Published var progress: Double = 0.0

    // File handling
    @Published var selectedFileURL: URL?
    @Published var fileContent: String = ""
    @Published var fileName: String = ""
    @Published var fileSize: String = ""
    @Published var fileType: FileType = .text

    // Personalization
    @Published var userName: String = ""
    @Published var contactName: String = ""
    @Published var insightsGoal: String = ""

    // Current report
    @Published var currentReport: GreyMirrorReport?

    // History
    @Published var analysisHistory: [GreyMirrorReport] = []

    // UI state
    @Published var showingFilePicker = false
    @Published var showingResults = false
    @Published var expandedMetrics: Set<String> = []
    @Published var errorMessage: String?

    // MARK: - Private

    private let orchestrator = MLOrchestrator()
    private let imageExtractor = ImageTextExtractor()
    private let pdfExtractor = PDFTextExtractor()
    private var cancellables = Set<AnyCancellable>()

    // Maximum file size (50MB)
    private let maxFileSize: Int = 50 * 1024 * 1024

    // MARK: - File Types

    enum FileType {
        case text       // .txt, .csv, .json, .chat
        case pdf        // .pdf
        case image      // .png, .jpg, .heic, etc.

        static func from(extension ext: String) -> FileType {
            let lowerExt = ext.lowercased()
            if ImageTextExtractor.supportedExtensions.contains(lowerExt) {
                return .image
            } else if PDFTextExtractor.supportedExtensions.contains(lowerExt) {
                return .pdf
            }
            return .text
        }
    }

    // MARK: - Supported File Types

    static let supportedTypes: [UTType] = [
        // Text formats
        .plainText,
        .commaSeparatedText,
        .json,
        UTType(filenameExtension: "chat") ?? .plainText,
        // PDF
        .pdf,
        // Image formats
        .png,
        .jpeg,
        .heic,
        .heif,
        .tiff,
        .bmp,
        .gif
    ]

    // MARK: - Initialization

    init() {
        setupBindings()
        loadHistory()
    }

    private func setupBindings() {
        // Observe orchestrator progress
        orchestrator.$currentClassifier
            .receive(on: DispatchQueue.main)
            .sink { [weak self] classifier in
                self?.currentClassifier = classifier
            }
            .store(in: &cancellables)

        orchestrator.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.progress = progress
                if progress > 0 && progress < 1 {
                    self?.analysisState = .analyzing(currentClassifier: self?.currentClassifier ?? "", progress: progress)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - File Handling

    func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            loadFile(from: url)
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }

    func loadFile(from url: URL) {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access file. Please try again."
            return
        }

        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // Check file size
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int ?? 0

            if size > maxFileSize {
                errorMessage = "File exceeds 50MB limit (\(formatFileSize(size))). Please upload a smaller file."
                return
            }

            // Determine file type
            let detectedType = FileType.from(extension: url.pathExtension)
            self.fileType = detectedType

            selectedFileURL = url
            fileName = url.lastPathComponent
            fileSize = formatFileSize(size)
            errorMessage = nil

            // Handle based on file type
            switch detectedType {
            case .text:
                // Read text content directly
                let content = try String(contentsOf: url, encoding: .utf8)
                fileContent = content
                let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                print("Loaded text file with \(lines.count) lines")

            case .pdf:
                // Queue PDF extraction for analysis time - set placeholder
                fileContent = "[PDF - will be extracted during analysis]"
                print("Loaded PDF file: \(url.lastPathComponent)")

            case .image:
                // Queue image OCR for analysis time - set placeholder
                fileContent = "[Image - will be extracted during analysis]"
                print("Loaded image file: \(url.lastPathComponent)")
            }

        } catch {
            errorMessage = "Failed to read file: \(error.localizedDescription)"
        }
    }

    /// Extracts text from PDF or image files asynchronously
    func extractTextFromFile() async throws -> String {
        guard let url = selectedFileURL else {
            return fileContent
        }

        // Access security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "GreyMirror", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access file"])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        switch fileType {
        case .text:
            return fileContent

        case .pdf:
            return try await pdfExtractor.extractText(from: url)

        case .image:
            let imageData = try Data(contentsOf: url)
            return try await imageExtractor.extractText(from: imageData)
        }
    }

    func loadPastedText(_ text: String) {
        guard !text.isEmpty else {
            errorMessage = "Please paste some conversation text"
            return
        }

        fileContent = text
        fileName = "Pasted Text"
        fileSize = formatFileSize(text.utf8.count)
        selectedFileURL = nil
        errorMessage = nil
    }

    func clearFile() {
        selectedFileURL = nil
        fileContent = ""
        fileName = ""
        fileSize = ""
        errorMessage = nil
    }

    // MARK: - Analysis

    func startAnalysis() async {
        guard !fileContent.isEmpty else {
            errorMessage = "No file loaded. Please select a file first."
            return
        }

        analysisState = .parsing
        errorMessage = nil

        // Extract text from PDF/Image if needed
        var contentToAnalyze = fileContent
        if fileType == .pdf || fileType == .image {
            do {
                analysisState = .uploading(progress: 0.3)
                currentClassifier = fileType == .pdf ? "Extracting PDF text..." : "Running OCR on image..."
                contentToAnalyze = try await extractTextFromFile()

                guard !contentToAnalyze.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    analysisState = .failed(error: "No text could be extracted from the file")
                    errorMessage = "No text found in file. Please try a different file."
                    return
                }
            } catch {
                analysisState = .failed(error: "Failed to extract text: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                return
            }
        }

        let personalization = GreyMirrorReport.Personalization(
            userName: userName.isEmpty ? "You" : userName,
            contactName: contactName.isEmpty ? "Them" : contactName,
            insightsGoal: insightsGoal
        )

        let format: MessageParser.ImportFormat
        switch fileType {
        case .text:
            format = selectedFileURL != nil ? .file : .paste
        case .pdf, .image:
            format = .screenshot  // Treat extracted text as OCR output
        }

        let report = await orchestrator.runCompleteAnalysis(
            data: contentToAnalyze,
            format: format,
            personalization: personalization
        )

        if report.success {
            currentReport = report
            analysisState = .completed(report: report)
            showingResults = true

            // Save to history
            saveToHistory(report)
        } else {
            analysisState = .failed(error: report.error ?? "Unknown error")
            errorMessage = report.error
        }
    }

    func cancelAnalysis() {
        analysisState = .idle
        progress = 0
        currentClassifier = ""
    }

    // MARK: - Metrics

    func toggleMetricExpanded(_ metricId: String) {
        if expandedMetrics.contains(metricId) {
            expandedMetrics.remove(metricId)
        } else {
            expandedMetrics.insert(metricId)
        }
    }

    func collapseAllMetrics() {
        expandedMetrics.removeAll()
    }

    // MARK: - History

    private func loadHistory() {
        // Load from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "analysisHistory"),
           let history = try? JSONDecoder().decode([GreyMirrorReport].self, from: data) {
            analysisHistory = history
        }
    }

    private func saveToHistory(_ report: GreyMirrorReport) {
        analysisHistory.insert(report, at: 0)

        // Keep only last 20 analyses
        if analysisHistory.count > 20 {
            analysisHistory = Array(analysisHistory.prefix(20))
        }

        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(analysisHistory) {
            UserDefaults.standard.set(data, forKey: "analysisHistory")
        }
    }

    func deleteFromHistory(_ report: GreyMirrorReport) {
        analysisHistory.removeAll { $0.id == report.id }
        if let data = try? JSONEncoder().encode(analysisHistory) {
            UserDefaults.standard.set(data, forKey: "analysisHistory")
        }
    }

    func loadHistoryReport(_ report: GreyMirrorReport) {
        currentReport = report
        analysisState = .completed(report: report)
        showingResults = true
    }

    // MARK: - Export

    func exportReport(format: ExportFormat) -> URL? {
        guard let report = currentReport else { return nil }

        let content: String
        let filename: String

        switch format {
        case .json:
            content = exportAsJSON(report)
            filename = "grey-mirror-analysis.json"
        case .csv:
            content = exportAsCSV(report)
            filename = "grey-mirror-analysis.csv"
        case .text:
            content = exportAsText(report)
            filename = "grey-mirror-analysis.txt"
        }

        // Save to temp directory
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: tempURL, atomically: true, encoding: .utf8)

        return tempURL
    }

    private func exportAsJSON(_ report: GreyMirrorReport) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(report),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }

    private func exportAsCSV(_ report: GreyMirrorReport) -> String {
        var rows: [(String, String)] = [
            ("Metric", "Value"),
            ("Overall Health", report.positivity?.health.rawValue ?? "Unknown"),
            ("Health Score", "\(report.healthScore)"),
            ("Messages Analyzed", "\(report.messageCount)"),
            ("Sentiment", report.sentiment?.sentiment.rawValue ?? "Unknown"),
            ("Toxicity Level", report.toxicity?.level.rawValue ?? "None"),
            ("Engagement Level", report.engagement?.level.rawValue ?? "Unknown"),
            ("Double Texting", report.doubleTexting?.hasDoubleTexts == true ? "Yes" : "No"),
        ]

        if let pos = report.positivity {
            rows.append(("Your Positivity Score", "\(pos.you.score)"))
            rows.append(("Their Positivity Score", "\(pos.them.score)"))
        }

        return rows.map { "\($0.0),\($0.1)" }.joined(separator: "\n")
    }

    private func exportAsText(_ report: GreyMirrorReport) -> String {
        var text = """
        GREY MIRROR ANALYSIS REPORT
        Generated: \(DateFormatter.localizedString(from: report.timestamp, dateStyle: .long, timeStyle: .short))

        === SUMMARY ===
        \(report.summary)

        === KEY METRICS ===
        Health Score: \(report.healthScore)/100
        Messages Analyzed: \(report.messageCount)

        """

        if let pos = report.positivity {
            text += """

            === POSITIVITY INDEX ===
            Overall: \(pos.health.rawValue.uppercased()) (\(pos.score)/100)
            You: \(pos.you.score)/100
            Them: \(pos.them.score)/100
            Trend: \(pos.trend)

            """
        }

        if !report.insights.isEmpty {
            text += "\n=== KEY INSIGHTS ===\n"
            for insight in report.insights {
                text += "[\(insight.importance.uppercased())] \(insight.category): \(insight.insight)\n"
            }
        }

        if !report.recommendations.isEmpty {
            text += "\n=== RECOMMENDATIONS ===\n"
            for rec in report.recommendations {
                text += "[\(rec.priority.uppercased())] \(rec.action)\n\(rec.details)\n\n"
            }
        }

        return text
    }

    enum ExportFormat {
        case json, csv, text
    }

    // MARK: - Reset

    func reset() {
        analysisState = .idle
        currentReport = nil
        showingResults = false
        expandedMetrics.removeAll()
        clearFile()
        userName = ""
        contactName = ""
        insightsGoal = ""
    }

    // MARK: - Helpers

    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}
