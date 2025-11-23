// GreyMirror/Services/Parsing/PDFTextExtractor.swift
// PDF text extraction using PDFKit

import Foundation
import PDFKit
import Vision
import UIKit

/// Extracts text content from PDF files
final class PDFTextExtractor {

    enum ExtractionError: Error, LocalizedError {
        case invalidPDF
        case noTextFound
        case passwordProtected
        case extractionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidPDF: return "Could not load the PDF file"
            case .noTextFound: return "No text was found in the PDF"
            case .passwordProtected: return "PDF is password protected"
            case .extractionFailed(let reason): return "Text extraction failed: \(reason)"
            }
        }
    }

    /// Configuration for PDF extraction
    struct ExtractionConfig {
        var useOCRForImages: Bool = true  // Use Vision OCR for image-based PDFs
        var pageRange: Range<Int>? = nil  // nil = all pages
        var preserveFormatting: Bool = true

        static let `default` = ExtractionConfig()
        static let fast = ExtractionConfig(useOCRForImages: false, preserveFormatting: false)
    }

    /// Metadata extracted from PDF
    struct PDFMetadata {
        let title: String?
        let author: String?
        let subject: String?
        let pageCount: Int
        let creationDate: Date?
        let modificationDate: Date?
    }

    private let imageExtractor = ImageTextExtractor()

    // MARK: - Public Methods

    /// Extract text from PDF data
    func extractText(from data: Data, config: ExtractionConfig = .default) async throws -> String {
        guard let document = PDFDocument(data: data) else {
            throw ExtractionError.invalidPDF
        }
        return try await extractText(from: document, config: config)
    }

    /// Extract text from PDF at URL
    func extractText(from url: URL, config: ExtractionConfig = .default) async throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw ExtractionError.extractionFailed("Cannot access file")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.invalidPDF
        }

        if document.isLocked {
            throw ExtractionError.passwordProtected
        }

        return try await extractText(from: document, config: config)
    }

    /// Extract text from PDFDocument
    func extractText(from document: PDFDocument, config: ExtractionConfig = .default) async throws -> String {
        if document.isLocked {
            throw ExtractionError.passwordProtected
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw ExtractionError.noTextFound
        }

        let startPage = config.pageRange?.lowerBound ?? 0
        let endPage = min(config.pageRange?.upperBound ?? pageCount, pageCount)

        var allText: [String] = []
        var pagesWithNoText: [Int] = []

        for pageIndex in startPage..<endPage {
            guard let page = document.page(at: pageIndex) else { continue }

            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if config.preserveFormatting {
                    allText.append(pageText)
                } else {
                    // Normalize whitespace
                    let normalized = pageText.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    allText.append(normalized)
                }
            } else {
                pagesWithNoText.append(pageIndex)
            }
        }

        // Try OCR on pages that had no text (might be scanned/image PDFs)
        if config.useOCRForImages && !pagesWithNoText.isEmpty {
            for pageIndex in pagesWithNoText {
                if let page = document.page(at: pageIndex) {
                    if let ocrText = try? await extractTextWithOCR(from: page) {
                        allText.append(ocrText)
                    }
                }
            }
        }

        let finalText = allText.joined(separator: "\n\n")

        guard !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.noTextFound
        }

        return finalText
    }

    /// Extract metadata from PDF
    func extractMetadata(from url: URL) throws -> PDFMetadata {
        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.invalidPDF
        }
        return extractMetadata(from: document)
    }

    func extractMetadata(from document: PDFDocument) -> PDFMetadata {
        let attributes = document.documentAttributes ?? [:]

        return PDFMetadata(
            title: attributes[PDFDocumentAttribute.titleAttribute] as? String,
            author: attributes[PDFDocumentAttribute.authorAttribute] as? String,
            subject: attributes[PDFDocumentAttribute.subjectAttribute] as? String,
            pageCount: document.pageCount,
            creationDate: attributes[PDFDocumentAttribute.creationDateAttribute] as? Date,
            modificationDate: attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date
        )
    }

    /// Extract text and try to parse it as a conversation
    func extractConversation(from url: URL, config: ExtractionConfig = .default) async throws -> String {
        let text = try await extractText(from: url, config: config)
        return parseConversationFormat(text)
    }

    // MARK: - Private Methods

    /// Use Vision OCR on a PDF page rendered as an image
    private func extractTextWithOCR(from page: PDFPage) async throws -> String {
        // Render PDF page to image
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0  // Higher resolution for better OCR

        let renderer = UIGraphicsImageRenderer(size: CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        ))

        let image = renderer.image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: CGSize(
                width: pageRect.width * scale,
                height: pageRect.height * scale
            )))

            context.cgContext.translateBy(x: 0, y: pageRect.height * scale)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        // Use Vision to extract text from the rendered image
        return try await imageExtractor.extractText(from: image)
    }

    /// Try to identify conversation patterns in extracted text
    private func parseConversationFormat(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var formattedLines: [String] = []

        // Common patterns in exported conversations
        let patterns: [(regex: String, senderGroup: Int, messageGroup: Int)] = [
            // Pattern: "Name: message"
            (#"^([A-Za-z\s]+):\s*(.+)$"#, 1, 2),
            // Pattern: "[timestamp] Name: message"
            (#"^\[.+\]\s*([A-Za-z\s]+):\s*(.+)$"#, 1, 2),
            // Pattern: "Name (timestamp): message"
            (#"^([A-Za-z\s]+)\s*\(.+\):\s*(.+)$"#, 1, 2),
            // Pattern: WhatsApp format "timestamp - Name: message"
            (#"^\d{1,2}/\d{1,2}/\d{2,4},?\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*-\s*([^:]+):\s*(.+)$"#, 1, 2),
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            var matched = false
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern.regex, options: []),
                   let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) {

                    if let senderRange = Range(match.range(at: pattern.senderGroup), in: trimmed),
                       let messageRange = Range(match.range(at: pattern.messageGroup), in: trimmed) {
                        let sender = String(trimmed[senderRange]).trimmingCharacters(in: .whitespaces)
                        let message = String(trimmed[messageRange])
                        formattedLines.append("\(sender): \(message)")
                        matched = true
                        break
                    }
                }
            }

            if !matched {
                formattedLines.append(trimmed)
            }
        }

        return formattedLines.joined(separator: "\n")
    }
}

// MARK: - Supported Types

extension PDFTextExtractor {

    static var supportedExtensions: Set<String> {
        ["pdf"]
    }

    static func isSupported(fileExtension: String) -> Bool {
        supportedExtensions.contains(fileExtension.lowercased())
    }

    static func isSupported(url: URL) -> Bool {
        isSupported(fileExtension: url.pathExtension)
    }
}

// MARK: - Message Parsing Integration

extension PDFTextExtractor {

    /// Extract and parse PDF content into messages
    func parseMessages(from url: URL, userNames: (you: String, them: String)) async throws -> [ParsedMessage] {
        let text = try await extractConversation(from: url)

        // Use the existing MessageParser to parse the extracted text
        let parser = MessageParser()
        return parser.parse(text: text, userName: userNames.you, contactName: userNames.them)
    }
}
