// GreyMirror/Views/AnalysisProgress/AnalysisProgressView.swift
// Real-time analysis progress with classifier updates

import SwiftUI

struct AnalysisProgressView: View {
    @ObservedObject var viewModel: GreyMirrorViewModel
    @State private var pulseAnimation = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Animated Eye
            animatedEye

            // Progress Info
            progressInfo

            // Classifier List
            classifierList

            Spacer()

            // Cancel Button
            Button {
                viewModel.cancelAnalysis()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }

    // MARK: - Animated Eye

    private var animatedEye: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        Color.cyan.opacity(0.1 - Double(index) * 0.03),
                        lineWidth: 2
                    )
                    .frame(width: 180 + CGFloat(index * 30), height: 180 + CGFloat(index * 30))
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: pulseAnimation
                    )
            }

            // Rotating scan lines
            ForEach(0..<8) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .cyan.opacity(0.3), .clear],
                            startPoint: .center,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80, height: 2)
                    .offset(x: 40)
                    .rotationEffect(.degrees(Double(index) * 45 + rotationAngle))
            }

            // Eye circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "1a4a6e"), Color(hex: "0a1628")],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)

            // Inner iris
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.cyan.opacity(0.6), .cyan.opacity(0.2)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .scaleEffect(pulseAnimation ? 1.2 : 0.9)

            // Pupil
            Circle()
                .fill(Color.black)
                .frame(width: 24, height: 24)

            // Scanning line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .cyan.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 120, height: 2)
                .offset(y: pulseAnimation ? -50 : 50)
        }
        .shadow(color: .cyan.opacity(0.3), radius: 30)
    }

    // MARK: - Progress Info

    private var progressInfo: some View {
        VStack(spacing: 16) {
            Text("ANALYZING")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Current classifier
            Text(viewModel.currentClassifier)
                .font(.headline)
                .foregroundColor(.cyan)
                .transition(.opacity.combined(with: .scale))
                .id(viewModel.currentClassifier)
                .animation(.easeInOut, value: viewModel.currentClassifier)

            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))

                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, Color(hex: "00d4ff")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.progress)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                    }
                }
                .frame(height: 12)
                .frame(maxWidth: 280)

                // Percentage
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Estimated time
            if viewModel.progress > 0 && viewModel.progress < 1 {
                let remaining = estimatedTimeRemaining()
                Text("~\(remaining) remaining")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
    }

    // MARK: - Classifier List

    private var classifierList: some View {
        VStack(spacing: 8) {
            Text("CLASSIFIERS")
                .font(.caption)
                .foregroundColor(.gray)
                .tracking(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ClassifierInfo.allClassifiers) { classifier in
                        ClassifierPill(
                            classifier: classifier,
                            isActive: viewModel.currentClassifier.contains(classifier.name),
                            isComplete: isClassifierComplete(classifier)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private func isClassifierComplete(_ classifier: ClassifierInfo) -> Bool {
        let classifierOrder = ClassifierInfo.allClassifiers.map { $0.name }
        guard let currentIndex = classifierOrder.firstIndex(of: viewModel.currentClassifier),
              let classifierIndex = classifierOrder.firstIndex(of: classifier.name) else {
            return false
        }
        return classifierIndex < currentIndex
    }

    private func estimatedTimeRemaining() -> String {
        let totalEstimate: TimeInterval = 30 // Estimate 30 seconds total
        let remaining = totalEstimate * (1 - viewModel.progress)

        if remaining < 5 {
            return "a few seconds"
        } else if remaining < 60 {
            return "\(Int(remaining))s"
        } else {
            return "\(Int(remaining / 60))m"
        }
    }
}

// MARK: - Classifier Pill

struct ClassifierPill: View {
    let classifier: ClassifierInfo
    let isActive: Bool
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.caption2)
                .foregroundColor(statusColor)

            Text(classifier.name)
                .font(.caption)
                .foregroundColor(isActive ? .white : isComplete ? .cyan : .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isActive ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.cyan : Color.clear, lineWidth: 1)
                )
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private var statusIcon: String {
        if isActive { return "arrow.triangle.2.circlepath" }
        if isComplete { return "checkmark.circle.fill" }
        return "circle"
    }

    private var statusColor: Color {
        if isActive { return .cyan }
        if isComplete { return .green }
        return .gray.opacity(0.5)
    }
}

#Preview {
    AnalysisProgressView(viewModel: {
        let vm = GreyMirrorViewModel()
        return vm
    }())
    .background(Color.black)
    .preferredColorScheme(.dark)
}
