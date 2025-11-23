import SwiftUI

struct CharactersView: View {
    @EnvironmentObject private var viewModel: CharacterViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var showCreator = false
    @State private var searchText = ""

    var filteredCharacters: [Character] {
        if searchText.isEmpty {
            return viewModel.characters
        }
        return viewModel.characters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            AppColors.darkBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search
                SearchBar(text: $searchText, placeholder: "Search characters...")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // System Characters
                            characterSection(
                                title: "AI Models",
                                characters: filteredCharacters.filter { $0.isSystemCharacter }
                            )

                            // User Characters
                            if !viewModel.userCharacters.isEmpty {
                                characterSection(
                                    title: "Your Characters",
                                    characters: filteredCharacters.filter { !$0.isSystemCharacter }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if viewModel.canCreateCharacter {
                        showCreator = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(viewModel.canCreateCharacter ? AppColors.primary : AppColors.textMuted)
                }
                .disabled(!viewModel.canCreateCharacter)
            }
        }
        .sheet(isPresented: $showCreator) {
            CharacterCreatorView()
                .environmentObject(viewModel)
        }
        .task {
            await viewModel.loadCharacters()
        }
    }

    private func characterSection(title: String, characters: [Character]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textMuted)
                .textCase(.uppercase)

            ForEach(characters) { character in
                CharacterCard(character: character)
            }
        }
    }
}

// MARK: - Character Card

struct CharacterCard: View {
    let character: Character

    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 16) {
                // Avatar
                Image(systemName: character.displayAvatar)
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 60, height: 60)
                    .background(AppColors.primary.opacity(0.2))
                    .clipShape(Circle())

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(character.name)
                            .font(AppFonts.medium(18))
                            .foregroundColor(.white)

                        Spacer()

                        statusBadge
                    }

                    if let backstory = character.backstory {
                        Text(backstory)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Personality traits preview
                    if let traits = character.personalityTraits {
                        personalityPreview(traits)
                    }
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .cornerRadius(16)
        }
        .sheet(isPresented: $showDetail) {
            CharacterDetailView(character: character)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if character.id == 1 {
            Text("FREE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.success)
                .cornerRadius(6)
        } else if character.isSystemCharacter {
            Text("PREMIUM")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.primary)
                .cornerRadius(6)
        } else if character.isPublic {
            Text("PUBLIC")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.info)
                .cornerRadius(6)
        }
    }

    private func personalityPreview(_ traits: PersonalityTraits) -> some View {
        HStack(spacing: 8) {
            if let friendliness = traits.friendliness {
                TraitBadge(name: "Friendly", value: friendliness)
            }
            if let creativity = traits.creativity {
                TraitBadge(name: "Creative", value: creativity)
            }
            if let humor = traits.humor {
                TraitBadge(name: "Humor", value: humor)
            }
        }
    }
}

// MARK: - Trait Badge

struct TraitBadge: View {
    let name: String
    let value: Double

    var body: some View {
        Text("\(name) \(Int(value * 100))%")
            .font(.system(size: 10))
            .foregroundColor(AppColors.textMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColors.inputBackground)
            .cornerRadius(4)
    }
}

// MARK: - Character Detail View

struct CharacterDetailView: View {
    let character: Character

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: character.displayAvatar)
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 120, height: 120)
                                .background(AppColors.primary.opacity(0.2))
                                .clipShape(Circle())

                            Text(character.name)
                                .font(AppFonts.title)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)

                        // Backstory
                        if let backstory = character.backstory {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("About")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textMuted)
                                    .textCase(.uppercase)

                                Text(backstory)
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                        }

                        // Personality
                        if let traits = character.personalityTraits {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Personality")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textMuted)
                                    .textCase(.uppercase)

                                if let value = traits.friendliness {
                                    TraitSlider(name: "Friendliness", value: value)
                                }
                                if let value = traits.creativity {
                                    TraitSlider(name: "Creativity", value: value)
                                }
                                if let value = traits.assertiveness {
                                    TraitSlider(name: "Assertiveness", value: value)
                                }
                                if let value = traits.humor {
                                    TraitSlider(name: "Humor", value: value)
                                }
                                if let value = traits.empathy {
                                    TraitSlider(name: "Empathy", value: value)
                                }
                                if let value = traits.formality {
                                    TraitSlider(name: "Formality", value: value)
                                }
                            }
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                        }

                        // Speech Patterns
                        if let patterns = character.speechPatterns, !patterns.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Speech Patterns")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textMuted)
                                    .textCase(.uppercase)

                                FlowLayout(spacing: 8) {
                                    ForEach(patterns, id: \.self) { pattern in
                                        Text(pattern)
                                            .font(AppFonts.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.primary.opacity(0.3))
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
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
    }
}

// MARK: - Trait Slider

struct TraitSlider: View {
    let name: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.inputBackground)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.primaryGradient)
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if rowWidth + size.width > containerWidth {
                height += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }

        height += rowHeight
        return CGSize(width: containerWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CharactersView()
            .environmentObject(CharacterViewModel())
            .environmentObject(AuthViewModel())
    }
    .preferredColorScheme(.dark)
}
