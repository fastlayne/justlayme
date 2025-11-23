// StreamingTextView.swift
// JustLayMe iOS - Streaming Text Animation Component
// Animates text appearing word by word, matching web behavior

import SwiftUI
import Combine

// MARK: - Streaming Text View

struct StreamingTextView: View {
    let fullText: String
    let isStreaming: Bool
    var wordsPerSecond: Double = 15

    @State private var displayedText = ""
    @State private var wordIndex = 0
    @State private var timer: Timer?

    private var words: [String] {
        fullText.split(separator: " ").map(String.init)
    }

    var body: some View {
        Text(displayedText)
            .font(.body)
            .foregroundColor(.white)
            .onChange(of: fullText) { newValue in
                if isStreaming {
                    startStreaming()
                } else {
                    displayedText = newValue
                }
            }
            .onAppear {
                if isStreaming {
                    startStreaming()
                } else {
                    displayedText = fullText
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

    private func startStreaming() {
        displayedText = ""
        wordIndex = 0

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / wordsPerSecond, repeats: true) { _ in
            if wordIndex < words.count {
                if !displayedText.isEmpty {
                    displayedText += " "
                }
                displayedText += words[wordIndex]
                wordIndex += 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Typewriter Text View

struct TypewriterTextView: View {
    let text: String
    var charactersPerSecond: Double = 50
    var onComplete: (() -> Void)?

    @State private var displayedText = ""
    @State private var charIndex = 0
    @State private var timer: Timer?

    var body: some View {
        Text(displayedText)
            .font(.body)
            .foregroundColor(.white)
            .onAppear {
                startTyping()
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

    private func startTyping() {
        displayedText = ""
        charIndex = 0

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / charactersPerSecond, repeats: true) { _ in
            if charIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: charIndex)
                displayedText += String(text[index])
                charIndex += 1
            } else {
                timer?.invalidate()
                onComplete?()
            }
        }
    }
}

// MARK: - Animated Cursor

struct AnimatedCursor: View {
    @State private var isVisible = true

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: 18)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Markdown Text View

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdown(text), id: \.id) { block in
                renderBlock(block)
            }
        }
    }

    private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")

        var codeBlock: String?
        var codeLanguage: String?

        for line in lines {
            // Check for code block start/end
            if line.hasPrefix("```") {
                if codeBlock != nil {
                    // End code block
                    blocks.append(MarkdownBlock(type: .code(language: codeLanguage), content: codeBlock!))
                    codeBlock = nil
                    codeLanguage = nil
                } else {
                    // Start code block
                    codeBlock = ""
                    codeLanguage = line.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
                    if codeLanguage?.isEmpty == true { codeLanguage = nil }
                }
                continue
            }

            if codeBlock != nil {
                codeBlock! += (codeBlock!.isEmpty ? "" : "\n") + line
                continue
            }

            // Headers
            if line.hasPrefix("### ") {
                blocks.append(MarkdownBlock(type: .heading3, content: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                blocks.append(MarkdownBlock(type: .heading2, content: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                blocks.append(MarkdownBlock(type: .heading1, content: String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(MarkdownBlock(type: .listItem, content: String(line.dropFirst(2))))
            } else if line.hasPrefix("> ") {
                blocks.append(MarkdownBlock(type: .quote, content: String(line.dropFirst(2))))
            } else if !line.isEmpty {
                blocks.append(MarkdownBlock(type: .paragraph, content: line))
            }
        }

        return blocks
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block.type {
        case .heading1:
            Text(block.content)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

        case .heading2:
            Text(block.content)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

        case .heading3:
            Text(block.content)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)

        case .paragraph:
            Text(parseInlineFormatting(block.content))
                .foregroundColor(.white)

        case .code(let language):
            CodeBlockView(code: block.content, language: language)

        case .listItem:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundColor(Color(hex: "6b46ff"))
                Text(parseInlineFormatting(block.content))
                    .foregroundColor(.white)
            }

        case .quote:
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(hex: "6b46ff"))
                    .frame(width: 3)
                Text(block.content)
                    .font(.body.italic())
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
    }

    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Bold: **text**
        if let boldRange = result.range(of: "**") {
            // Simple implementation - would need more robust parsing for production
        }

        return result
    }
}

// MARK: - Markdown Block

struct MarkdownBlock: Identifiable {
    let id = UUID()
    let type: BlockType
    let content: String

    enum BlockType {
        case heading1
        case heading2
        case heading3
        case paragraph
        case code(language: String?)
        case listItem
        case quote
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let code: String
    let language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            if let language = language {
                HStack {
                    Text(language)
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Button(action: copyCode) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
            }

            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color(hex: "e6e6e6"))
                    .padding(12)
            }
        }
        .background(Color(hex: "1e1e1e"))
        .cornerRadius(8)
    }

    private func copyCode() {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #endif
    }
}

// MARK: - Preview

struct StreamingTextView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StreamingTextView(
                fullText: "This is a streaming text animation that shows words appearing one by one.",
                isStreaming: true
            )

            MarkdownTextView(text: """
            # Hello World

            This is a **bold** statement.

            ## Code Example

            ```swift
            let greeting = "Hello, World!"
            print(greeting)
            ```

            - First item
            - Second item
            - Third item

            > This is a quote
            """)
        }
        .padding()
        .background(Color(hex: "0a0a0f"))
        .preferredColorScheme(.dark)
    }
}
