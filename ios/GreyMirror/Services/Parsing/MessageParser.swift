// GreyMirror/Services/Parsing/MessageParser.swift
// Parses and normalizes conversation data from various formats
// Matches the web messageParser.js implementation

import Foundation

final class MessageParser {

    // MARK: - Supported Formats

    enum ImportFormat {
        case paste       // Plain text paste
        case file        // File upload (txt, csv, json)
        case screenshot  // OCR from screenshot
    }

    // MARK: - Parse Methods

    /// Main entry point - parses raw conversation data
    func parseConversationData(_ data: String, format: ImportFormat = .paste) -> [ParsedMessage] {
        guard !data.isEmpty else { return [] }

        var messages: [ParsedMessage]

        switch format {
        case .paste:
            messages = parseTextFormat(data)
        case .file:
            messages = parseFileFormat(data)
        case .screenshot:
            messages = parseTextFormat(data)  // OCR output is text
        }

        return normalizeMessages(messages)
    }

    // MARK: - Text Format Parsing

    private func parseTextFormat(_ text: String) -> [ParsedMessage] {
        // Detect iMessage export format
        if text.contains(" from ") && text.contains(" to ") &&
            text.range(of: #"\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+(from|to)\s+"#, options: .regularExpression) != nil {
            return parseIMessageFormat(text)
        }

        // Default line-by-line parsing
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var messages: [ParsedMessage] = []

        for (index, line) in lines.enumerated() {
            if let message = parseMessageLine(line, lineIndex: index) {
                messages.append(message)
            }
        }

        return messages
    }

    // MARK: - iMessage Export Format

    /// Parses iMessage export format:
    /// "2018-11-18 23:14:08 from Amber (email) - Recently deleted"
    /// "2018-11-18 23:14:21 to Amber - Recently deleted"
    private func parseIMessageFormat(_ text: String) -> [ParsedMessage] {
        var messages: [ParsedMessage] = []

        // Split by separator lines (-----)
        let blocks = text.components(separatedBy: String(repeating: "-", count: 20))

        for block in blocks {
            let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBlock.isEmpty else { continue }

            // Pattern: "2018-11-18 23:14:08 from/to Name"
            let pattern = #"(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(from|to)\s+([^\n(]+?)(?:\s*\([^)]*\))?\s*(?:-[^\n]*)?\n?"#

            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: trimmedBlock, range: NSRange(trimmedBlock.startIndex..., in: trimmedBlock)) else {
                continue
            }

            guard let timestampRange = Range(match.range(at: 1), in: trimmedBlock),
                  let directionRange = Range(match.range(at: 2), in: trimmedBlock),
                  let senderRange = Range(match.range(at: 3), in: trimmedBlock) else {
                continue
            }

            let timestampStr = String(trimmedBlock[timestampRange])
            let direction = String(trimmedBlock[directionRange]).lowercased()
            let senderName = String(trimmedBlock[senderRange]).trimmingCharacters(in: .whitespaces)

            // Parse timestamp
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestamp = formatter.date(from: timestampStr) ?? Date()

            // Extract content after the header
            let fullMatchRange = Range(match.range, in: trimmedBlock)!
            var content = String(trimmedBlock[fullMatchRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !content.isEmpty else { continue }

            // Direction: "from" = received, "to" = sent
            let sender = direction == "to" ? "You" : senderName
            let msgDirection: ParsedMessage.MessageDirection = direction == "to" ? .sent : .received

            messages.append(ParsedMessage(
                id: messages.count,
                timestamp: timestamp,
                sender: sender,
                content: content,
                direction: msgDirection,
                length: content.count
            ))
        }

        return messages
    }

    // MARK: - File Format Parsing

    private func parseFileFormat(_ data: String) -> [ParsedMessage] {
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try JSON first
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if let messages = parseJSON(trimmed) {
                return messages
            }
        }

        // Fall back to text parsing
        return parseTextFormat(data)
    }

    private func parseJSON(_ json: String) -> [ParsedMessage]? {
        guard let data = json.data(using: .utf8) else { return nil }

        // Try array of messages
        if let messages = try? JSONDecoder().decode([JSONMessage].self, from: data) {
            return messages.enumerated().map { index, msg in
                ParsedMessage(
                    id: index,
                    timestamp: msg.timestamp ?? Date(),
                    sender: msg.sender ?? "unknown",
                    content: msg.content ?? msg.text ?? msg.message ?? "",
                    direction: (msg.direction ?? "sent") == "sent" ? .sent : .received,
                    length: (msg.content ?? msg.text ?? msg.message ?? "").count
                )
            }
        }

        // Try object with messages property
        if let container = try? JSONDecoder().decode(JSONMessageContainer.self, from: data) {
            return container.messages.enumerated().map { index, msg in
                ParsedMessage(
                    id: index,
                    timestamp: msg.timestamp ?? Date(),
                    sender: msg.sender ?? "unknown",
                    content: msg.content ?? msg.text ?? msg.message ?? "",
                    direction: (msg.direction ?? "sent") == "sent" ? .sent : .received,
                    length: (msg.content ?? msg.text ?? msg.message ?? "").count
                )
            }
        }

        return nil
    }

    // MARK: - Line Parsing

    /// Parse single message line with flexible format support
    private func parseMessageLine(_ line: String, lineIndex: Int) -> ParsedMessage? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var timestamp = Date()
        var content = trimmed
        var sender = "unknown"

        // Timestamp patterns
        let timestampPatterns = [
            #"^\d{1,2}/\d{1,2}/\d{2,4},?\s+\d{1,2}:\d{2}(?::\d{2})?\s?(?:AM|PM)?\s*[-–—]\s*"#,  // WhatsApp
            #"^\d{4}-\d{2}-\d{2}[T\s]\d{1,2}:\d{2}(?::\d{2})?.*?[-–—:]\s*"#,  // ISO
            #"^\[\d{1,2}:\d{2}(?:\s?(?:AM|PM))?\]\s*"#,  // Discord
            #"^\d{1,2}:\d{2}(?::\d{2})?\s?(?:AM|PM)?\s*[-–—]\s*"#,  // Slack
        ]

        for pattern in timestampPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
                if let range = Range(match.range, in: content) {
                    let timestampStr = String(content[range])
                    content = String(content[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    // Try to parse timestamp (simplified)
                    break
                }
            }
        }

        // Extract sender and message
        // Try "Person: message" format
        if let colonIndex = content.firstIndex(of: ":"),
           colonIndex != content.startIndex {
            let potentialSender = String(content[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let potentialMessage = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            if potentialSender.count < 50 && !potentialMessage.isEmpty {
                sender = potentialSender
                content = potentialMessage
            }
        } else {
            // Alternate between senders for plain text
            sender = lineIndex % 2 == 0 ? "person1" : "person2"
        }

        guard !content.isEmpty else { return nil }

        return ParsedMessage(
            id: lineIndex,
            timestamp: timestamp,
            sender: sender,
            content: content,
            direction: .sent,  // Will be normalized later
            length: content.count
        )
    }

    // MARK: - Normalization

    private func normalizeMessages(_ messages: [ParsedMessage]) -> [ParsedMessage] {
        guard messages.count >= 2 else {
            return messages.enumerated().map { index, msg in
                ParsedMessage(
                    id: index,
                    timestamp: msg.timestamp,
                    sender: msg.sender,
                    content: msg.content,
                    direction: .sent,
                    length: msg.length,
                    timeSinceLast: nil
                )
            }
        }

        // Identify unique senders
        let senders = Array(Set(messages.map { $0.sender })).sorted()
        let person1 = senders.first ?? "unknown"

        // Find which sender is "You" (from iMessage format)
        let userSender = messages.first(where: { $0.direction == .sent })?.sender ?? person1

        return messages.enumerated().map { index, msg in
            var timeSinceLast: TimeInterval? = nil
            if index > 0 {
                timeSinceLast = msg.timestamp.timeIntervalSince(messages[index - 1].timestamp)
            }

            let direction: ParsedMessage.MessageDirection
            if msg.sender == userSender || msg.sender == person1 || msg.sender == "You" {
                direction = .sent
            } else {
                direction = .received
            }

            return ParsedMessage(
                id: index,
                timestamp: msg.timestamp,
                sender: msg.sender,
                content: msg.content,
                direction: direction,
                length: msg.length,
                timeSinceLast: timeSinceLast
            )
        }
    }

    // MARK: - Stats

    func getConversationStats(_ messages: [ParsedMessage]) -> ConversationStats {
        guard !messages.isEmpty else {
            return ConversationStats(totalMessages: 0, uniqueSenders: 0, dateRange: nil, averageMessageLength: 0)
        }

        let uniqueSenders = Set(messages.map { $0.sender }).count
        let totalLength = messages.reduce(0) { $0 + $1.length }
        let avgLength = totalLength / messages.count

        let sorted = messages.sorted { $0.timestamp < $1.timestamp }

        return ConversationStats(
            totalMessages: messages.count,
            uniqueSenders: uniqueSenders,
            dateRange: ConversationStats.DateRange(start: sorted.first!.timestamp, end: sorted.last!.timestamp),
            averageMessageLength: avgLength
        )
    }
}

// MARK: - JSON Helpers

private struct JSONMessage: Codable {
    let timestamp: Date?
    let sender: String?
    let content: String?
    let text: String?
    let message: String?
    let direction: String?
}

private struct JSONMessageContainer: Codable {
    let messages: [JSONMessage]
}
