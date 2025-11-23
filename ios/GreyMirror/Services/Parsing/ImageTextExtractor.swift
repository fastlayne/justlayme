// GreyMirror/Services/Parsing/ImageTextExtractor.swift
// OCR text extraction from screenshots using Vision framework

import Foundation
import Vision
import UIKit

/// Extracts text from conversation screenshots using Apple's Vision framework
final class ImageTextExtractor {

    enum ExtractionError: Error, LocalizedError {
        case invalidImage
        case noTextFound
        case recognitionFailed(Error)
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Could not load the image file"
            case .noTextFound: return "No text was found in the image"
            case .recognitionFailed(let error): return "Text recognition failed: \(error.localizedDescription)"
            case .unsupportedFormat: return "Unsupported image format"
            }
        }
    }

    /// Extracted text block with position information
    struct TextBlock {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
        let isLeftAligned: Bool  // Helps determine message direction
    }

    /// Configuration for text extraction
    struct ExtractionConfig {
        var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
        var usesLanguageCorrection: Bool = true
        var customWords: [String] = []  // App-specific words to recognize
        var minimumConfidence: Float = 0.5

        static let `default` = ExtractionConfig()
        static let fast = ExtractionConfig(recognitionLevel: .fast, usesLanguageCorrection: false)
    }

    // MARK: - Public Methods

    /// Extract text from image data
    func extractText(from imageData: Data, config: ExtractionConfig = .default) async throws -> String {
        guard let image = UIImage(data: imageData) else {
            throw ExtractionError.invalidImage
        }
        return try await extractText(from: image, config: config)
    }

    /// Extract text from a UIImage
    func extractText(from image: UIImage, config: ExtractionConfig = .default) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ExtractionError.invalidImage
        }

        let textBlocks = try await performTextRecognition(on: cgImage, config: config)

        guard !textBlocks.isEmpty else {
            throw ExtractionError.noTextFound
        }

        return formatAsConversation(textBlocks, imageWidth: CGFloat(cgImage.width))
    }

    /// Extract text blocks with position info (for advanced processing)
    func extractTextBlocks(from image: UIImage, config: ExtractionConfig = .default) async throws -> [TextBlock] {
        guard let cgImage = image.cgImage else {
            throw ExtractionError.invalidImage
        }

        return try await performTextRecognition(on: cgImage, config: config)
    }

    /// Extract text from multiple images (conversation spanning multiple screenshots)
    func extractText(from images: [UIImage], config: ExtractionConfig = .default) async throws -> String {
        var allText: [String] = []

        for image in images {
            let text = try await extractText(from: image, config: config)
            allText.append(text)
        }

        return allText.joined(separator: "\n\n--- Next Screenshot ---\n\n")
    }

    /// Extract text from image at URL
    func extractText(from url: URL, config: ExtractionConfig = .default) async throws -> String {
        let data = try Data(contentsOf: url)
        return try await extractText(from: data, config: config)
    }

    // MARK: - Private Methods

    private func performTextRecognition(on cgImage: CGImage, config: ExtractionConfig) async throws -> [TextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ExtractionError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let textBlocks = observations.compactMap { observation -> TextBlock? in
                    guard let topCandidate = observation.topCandidates(1).first,
                          topCandidate.confidence >= config.minimumConfidence else {
                        return nil
                    }

                    // Determine if text is left or right aligned based on bounding box position
                    let boundingBox = observation.boundingBox
                    let isLeftAligned = boundingBox.midX < 0.5

                    return TextBlock(
                        text: topCandidate.string,
                        boundingBox: boundingBox,
                        confidence: topCandidate.confidence,
                        isLeftAligned: isLeftAligned
                    )
                }

                continuation.resume(returning: textBlocks)
            }

            // Configure the request
            request.recognitionLevel = config.recognitionLevel
            request.usesLanguageCorrection = config.usesLanguageCorrection

            if !config.customWords.isEmpty {
                request.customWords = config.customWords
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ExtractionError.recognitionFailed(error))
            }
        }
    }

    /// Format extracted text blocks into a conversation format
    private func formatAsConversation(_ blocks: [TextBlock], imageWidth: CGFloat) -> String {
        // Sort blocks by vertical position (top to bottom)
        let sortedBlocks = blocks.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        var lines: [String] = []
        var currentGroup: [TextBlock] = []
        var lastY: CGFloat = -1

        for block in sortedBlocks {
            // Group blocks that are on the same line (similar Y position)
            if lastY < 0 || abs(block.boundingBox.midY - lastY) < 0.05 {
                currentGroup.append(block)
            } else {
                // Process previous group
                if !currentGroup.isEmpty {
                    let line = processGroup(currentGroup, imageWidth: imageWidth)
                    lines.append(line)
                }
                currentGroup = [block]
            }
            lastY = block.boundingBox.midY
        }

        // Process last group
        if !currentGroup.isEmpty {
            let line = processGroup(currentGroup, imageWidth: imageWidth)
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func processGroup(_ blocks: [TextBlock], imageWidth: CGFloat) -> String {
        // Sort by X position (left to right)
        let sorted = blocks.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        let text = sorted.map { $0.text }.joined(separator: " ")

        // Determine if this is a sent or received message based on position
        let avgX = blocks.reduce(0.0) { $0 + $1.boundingBox.midX } / CGFloat(blocks.count)

        // Most messaging apps show sent messages on right, received on left
        if avgX > 0.6 {
            return "Me: \(text)"
        } else if avgX < 0.4 {
            return "Them: \(text)"
        } else {
            // Could be a timestamp or system message
            return text
        }
    }
}

// MARK: - Message Parsing Integration

extension ImageTextExtractor {

    /// Parse extracted text into ParsedMessages
    func parseMessages(from image: UIImage, userNames: (you: String, them: String) = ("Me", "Them")) async throws -> [ParsedMessage] {
        let textBlocks = try await extractTextBlocks(from: image)

        // Sort by vertical position
        let sortedBlocks = textBlocks.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        var messages: [ParsedMessage] = []
        var currentMessage: (text: String, direction: ParsedMessage.MessageDirection)? = nil
        var messageIndex = 0

        for block in sortedBlocks {
            let direction: ParsedMessage.MessageDirection = block.isLeftAligned ? .received : .sent

            if let current = currentMessage {
                // Check if this block continues the current message (close Y position)
                if current.direction == direction {
                    currentMessage = (current.text + " " + block.text, direction)
                } else {
                    // Save current message and start new one
                    messages.append(createMessage(
                        id: messageIndex,
                        content: current.text,
                        direction: current.direction,
                        userName: userNames.you,
                        contactName: userNames.them
                    ))
                    messageIndex += 1
                    currentMessage = (block.text, direction)
                }
            } else {
                currentMessage = (block.text, direction)
            }
        }

        // Add last message
        if let current = currentMessage {
            messages.append(createMessage(
                id: messageIndex,
                content: current.text,
                direction: current.direction,
                userName: userNames.you,
                contactName: userNames.them
            ))
        }

        return messages
    }

    private func createMessage(id: Int, content: String, direction: ParsedMessage.MessageDirection, userName: String, contactName: String) -> ParsedMessage {
        ParsedMessage(
            id: id,
            timestamp: Date(),  // Screenshots typically don't have parseable timestamps
            sender: direction == .sent ? userName : contactName,
            content: content,
            direction: direction,
            length: content.count,
            timeSinceLast: nil
        )
    }
}

// MARK: - Supported Image Types

extension ImageTextExtractor {

    static var supportedImageTypes: [String] {
        ["public.jpeg", "public.png", "public.heic", "public.heif", "public.tiff", "public.bmp", "public.gif"]
    }

    static var supportedExtensions: Set<String> {
        ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp", "gif"]
    }

    static func isSupported(fileExtension: String) -> Bool {
        supportedExtensions.contains(fileExtension.lowercased())
    }

    static func isSupported(url: URL) -> Bool {
        isSupported(fileExtension: url.pathExtension)
    }
}
