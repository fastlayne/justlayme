import SwiftUI

struct CharacterCreatorView: View {
    @EnvironmentObject private var viewModel: CharacterViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var newPattern = ""

    private let steps = ["Basic Info", "Personality", "Speech Style"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    stepIndicator

                    // Content
                    TabView(selection: $currentStep) {
                        basicInfoStep.tag(0)
                        personalityStep.tag(1)
                        speechStyleStep.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)

                    // Navigation buttons
                    navigationButtons
                }
            }
            .navigationTitle("Create Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.resetCreatorForm()
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 4) {
                    Circle()
                        .fill(index <= currentStep ? AppColors.primary : AppColors.textMuted.opacity(0.3))
                        .frame(width: 10, height: 10)

                    Text(steps[index])
                        .font(.system(size: 10))
                        .foregroundColor(index == currentStep ? AppColors.primary : AppColors.textMuted)
                }

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? AppColors.primary : AppColors.textMuted.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Basic Info Step

    private var basicInfoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Let's name your character")
                    .font(AppFonts.headline)
                    .foregroundColor(.white)

                CustomTextField(
                    placeholder: "Character Name",
                    text: $viewModel.creatorName,
                    icon: "person.fill"
                )

                CustomTextEditor(
                    placeholder: "Backstory (optional)\n\nDescribe your character's background, personality, and what makes them unique...",
                    text: $viewModel.creatorBackstory,
                    minHeight: 150
                )

                Toggle(isOn: $viewModel.creatorIsPublic) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Make Public")
                            .font(AppFonts.medium(16))
                            .foregroundColor(.white)

                        Text("Other users can chat with this character")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                .tint(AppColors.primary)
                .padding(16)
                .background(AppColors.cardBackground)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Personality Step

    private var personalityStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Define personality traits")
                    .font(AppFonts.headline)
                    .foregroundColor(.white)

                VStack(spacing: 20) {
                    PersonalitySlider(
                        name: "Friendliness",
                        description: "How warm and approachable",
                        value: viewModel.friendlinessBinding()
                    )

                    PersonalitySlider(
                        name: "Creativity",
                        description: "How imaginative and original",
                        value: viewModel.creativityBinding()
                    )

                    PersonalitySlider(
                        name: "Assertiveness",
                        description: "How confident and direct",
                        value: viewModel.assertivenessBinding()
                    )

                    PersonalitySlider(
                        name: "Humor",
                        description: "How playful and witty",
                        value: viewModel.humorBinding()
                    )

                    PersonalitySlider(
                        name: "Empathy",
                        description: "How understanding and caring",
                        value: viewModel.empathyBinding()
                    )

                    PersonalitySlider(
                        name: "Formality",
                        description: "How professional vs casual",
                        value: viewModel.formalityBinding()
                    )
                }
                .padding(20)
                .background(AppColors.cardBackground)
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Speech Style Step

    private var speechStyleStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Add speech patterns")
                    .font(AppFonts.headline)
                    .foregroundColor(.white)

                Text("Define how your character speaks")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)

                // Add pattern
                HStack(spacing: 12) {
                    CustomTextField(
                        placeholder: "e.g., uses slang, formal tone",
                        text: $newPattern
                    )

                    Button {
                        viewModel.addSpeechPattern(newPattern)
                        newPattern = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(newPattern.isEmpty ? AppColors.textMuted : AppColors.primary)
                    }
                    .disabled(newPattern.isEmpty)
                }

                // Patterns list
                if !viewModel.creatorSpeechPatterns.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.creatorSpeechPatterns, id: \.self) { pattern in
                            HStack(spacing: 6) {
                                Text(pattern)
                                    .font(AppFonts.caption)
                                    .foregroundColor(.white)

                                Button {
                                    viewModel.removeSpeechPattern(pattern)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textMuted)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.primary.opacity(0.3))
                            .cornerRadius(20)
                        }
                    }
                    .padding(16)
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)
                }

                // Suggestions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggestions")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textMuted)
                        .textCase(.uppercase)

                    FlowLayout(spacing: 8) {
                        ForEach(["Casual", "Formal", "Playful", "Mysterious", "Poetic", "Technical", "Witty", "Warm"], id: \.self) { suggestion in
                            if !viewModel.creatorSpeechPatterns.contains(suggestion) {
                                Button {
                                    viewModel.addSpeechPattern(suggestion)
                                } label: {
                                    Text(suggestion)
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppColors.inputBackground)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                } label: {
                    Text("Back")
                        .font(AppFonts.medium(16))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.cardBackground)
                        .cornerRadius(12)
                }
            }

            Button {
                if currentStep < steps.count - 1 {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    createCharacter()
                }
            } label: {
                HStack {
                    if viewModel.isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(currentStep < steps.count - 1 ? "Next" : "Create")
                            .font(AppFonts.semibold(16))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    (currentStep == 0 && !viewModel.isFormValid)
                        ? AppColors.textMuted
                        : AppColors.primary
                )
                .cornerRadius(12)
            }
            .disabled((currentStep == 0 && !viewModel.isFormValid) || viewModel.isCreating)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
    }

    // MARK: - Actions

    private func createCharacter() {
        Task {
            if let _ = await viewModel.createCharacter() {
                dismiss()
            }
        }
    }
}

// MARK: - Personality Slider

struct PersonalitySlider: View {
    let name: String
    let description: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppFonts.medium(16))
                        .foregroundColor(.white)

                    Text(description)
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(AppFonts.medium(14))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 50, alignment: .trailing)
            }

            Slider(value: $value, in: 0...1)
                .tint(AppColors.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    CharacterCreatorView()
        .environmentObject(CharacterViewModel())
}
