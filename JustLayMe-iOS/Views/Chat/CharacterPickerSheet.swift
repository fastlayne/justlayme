import SwiftUI

struct CharacterPickerSheet: View {
    @Binding var selectedCharacter: Character?
    @StateObject private var viewModel = CharacterViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBackground
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        // System Characters Section
                        Section {
                            ForEach(Character.presetCharacters) { character in
                                CharacterRow(
                                    character: character,
                                    isSelected: selectedCharacter?.id == character.id
                                ) {
                                    selectedCharacter = character
                                    dismiss()
                                }
                            }
                        } header: {
                            sectionHeader("AI Models")
                        }

                        // User Characters Section
                        if !viewModel.userCharacters.isEmpty {
                            Section {
                                ForEach(viewModel.userCharacters) { character in
                                    CharacterRow(
                                        character: character,
                                        isSelected: selectedCharacter?.id == character.id
                                    ) {
                                        selectedCharacter = character
                                        dismiss()
                                    }
                                }
                            } header: {
                                sectionHeader("Your Characters")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Choose Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.loadCharacters()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textMuted)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Character Row

struct CharacterRow: View {
    let character: Character
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Avatar
                Image(systemName: character.displayAvatar)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : AppColors.primary)
                    .frame(width: 50, height: 50)
                    .background(
                        isSelected
                            ? AppColors.primary
                            : AppColors.primary.opacity(0.2)
                    )
                    .clipShape(Circle())

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(character.name)
                            .font(AppFonts.medium(16))
                            .foregroundColor(.white)

                        if character.id == 1 {
                            Text("FREE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.success)
                                .cornerRadius(4)
                        } else if character.isSystemCharacter {
                            Text("PREMIUM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.primary)
                                .cornerRadius(4)
                        }
                    }

                    if let backstory = character.backstory {
                        Text(backstory)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Model Picker Sheet

struct ModelPickerSheet: View {
    @Binding var selectedModel: AIModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBackground
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Free Models
                        Section {
                            ForEach(AIModel.freeModels) { model in
                                ModelRow(
                                    model: model,
                                    isSelected: selectedModel?.id == model.id
                                ) {
                                    selectedModel = model
                                    dismiss()
                                }
                            }
                        } header: {
                            sectionHeader("Free Models")
                        }

                        // Premium Models
                        Section {
                            ForEach(AIModel.premiumModels) { model in
                                ModelRow(
                                    model: model,
                                    isSelected: selectedModel?.id == model.id
                                ) {
                                    selectedModel = model
                                    dismiss()
                                }
                            }
                        } header: {
                            sectionHeader("Premium Models")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Choose Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textMuted)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: AIModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "cpu")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : AppColors.primary)
                    .frame(width: 50, height: 50)
                    .background(
                        isSelected
                            ? AppColors.primary
                            : AppColors.primary.opacity(0.2)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(AppFonts.medium(16))
                            .foregroundColor(.white)

                        if !model.isPremium {
                            Text("FREE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.success)
                                .cornerRadius(4)
                        }
                    }

                    if let description = model.description {
                        Text(description)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    CharacterPickerSheet(selectedCharacter: .constant(.laymeV1))
}
