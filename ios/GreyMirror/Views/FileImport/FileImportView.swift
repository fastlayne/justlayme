// GreyMirror/Views/FileImport/FileImportView.swift
// File picker with validation, preview, and metadata collection

import SwiftUI
import UniformTypeIdentifiers

struct FileImportView: View {
    @ObservedObject var viewModel: GreyMirrorViewModel
    @State private var showingPasteSheet = false
    @State private var pasteText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Personalization Fields
                personalizationSection

                // File Drop Zone / Upload
                uploadSection

                // File Preview (if loaded)
                if !viewModel.fileContent.isEmpty {
                    filePreviewSection
                }

                // Error Display
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                // Analyze Button
                if !viewModel.fileContent.isEmpty {
                    analyzeButton
                }

                // Footer
                footerSection
            }
            .padding()
        }
        .fileImporter(
            isPresented: $viewModel.showingFilePicker,
            allowedContentTypes: GreyMirrorViewModel.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.loadFile(from: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingPasteSheet) {
            PasteTextSheet(text: $pasteText) {
                viewModel.loadPastedText(pasteText)
                showingPasteSheet = false
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Eye Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "1a4a6e"), Color(hex: "0a1628")],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 50, height: 50)

                Circle()
                    .fill(Color.black)
                    .frame(width: 20, height: 20)
            }
            .shadow(color: .cyan.opacity(0.3), radius: 20)

            Text("THE GREY MIRROR")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Upload your conversations to reveal the truth")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Personalization

    private var personalizationSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Your Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Name")
                        .font(.caption)
                        .foregroundColor(.cyan)
                    TextField("You", text: $viewModel.userName)
                        .textFieldStyle(GlassTextFieldStyle())
                }

                // Their Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Their Name")
                        .font(.caption)
                        .foregroundColor(.cyan)
                    TextField("Them", text: $viewModel.contactName)
                        .textFieldStyle(GlassTextFieldStyle())
                }
            }

            // Insights Goal
            VStack(alignment: .leading, spacing: 6) {
                Text("What insights are you looking for?")
                    .font(.caption)
                    .foregroundColor(.cyan)
                TextField("e.g., 'Are they interested in me?', 'Is this healthy?'", text: $viewModel.insightsGoal, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(GlassTextFieldStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        VStack(spacing: 16) {
            // File Upload Zone
            Button {
                viewModel.showingFilePicker = true
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.cyan)

                    Text(viewModel.fileContent.isEmpty ? "Tap to Select File" : "Tap to Change File")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(".txt, .csv, .json, .chat")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.cyan.opacity(0.5), .cyan.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2, dash: [10])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.cyan.opacity(0.05))
                        )
                )
            }

            // Or Divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundColor(.gray)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }

            // Paste Text Button
            Button {
                showingPasteSheet = true
            } label: {
                Label("Paste Conversation Text", systemImage: "doc.on.clipboard")
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - File Preview

    private var filePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.cyan)
                Text(viewModel.fileName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(viewModel.fileSize)
                    .font(.caption)
                    .foregroundColor(.gray)
                Button {
                    viewModel.clearFile()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }

            // Preview content
            let lines = viewModel.fileContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            Text("\(lines.count) lines detected")
                .font(.caption)
                .foregroundColor(.cyan)

            // Show first few lines
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.prefix(5).enumerated()), id: \.offset) { index, line in
                    Text(line.prefix(80) + (line.count > 80 ? "..." : ""))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                if lines.count > 5 {
                    Text("... and \(lines.count - 5) more lines")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                        .italic()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Analyze Button

    private var analyzeButton: some View {
        Button {
            Task {
                await viewModel.startAnalysis()
            }
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("ANALYZE NOW")
                    .fontWeight(.bold)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.cyan, Color(hex: "00d4ff")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .cyan.opacity(0.4), radius: 10, y: 5)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("BE CAREFUL WHAT YOU WISH FOR")
                .font(.caption)
                .foregroundColor(.gray)
            Text("YOU MIGHT NOT LIKE HOW THE MIRROR LOOKS BACK AT YOU")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.6))
        }
        .multilineTextAlignment(.center)
        .padding(.top, 20)
    }
}

// MARK: - Paste Text Sheet

struct PasteTextSheet: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                    .padding()

                Text("Paste your conversation text above")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .background(Color(hex: "0a1628"))
            .navigationTitle("Paste Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        onSubmit()
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Glass TextField Style

struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}

#Preview {
    FileImportView(viewModel: GreyMirrorViewModel())
        .background(Color.black)
        .preferredColorScheme(.dark)
}
