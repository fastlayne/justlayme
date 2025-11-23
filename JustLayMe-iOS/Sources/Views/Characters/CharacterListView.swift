import SwiftUI

struct CharacterListView: View {
    @StateObject private var viewModel = CharacterListViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    @State private var showCreateCharacter = false

    var body: some View {
        NavigationStack(path: $navigationCoordinator.characterPath) {
            List {
                // Predefined Characters Section
                Section {
                    ForEach(viewModel.predefinedCharacters) { character in
                        PredefinedCharacterRow(character: character)
                    }
                } header: {
                    Text("AI Characters")
                }

                // Custom Characters Section
                if !viewModel.customCharacters.isEmpty {
                    Section {
                        ForEach(viewModel.customCharacters) { character in
                            CustomCharacterRow(
                                character: character,
                                onTap: {
                                    navigationCoordinator.navigateToCharacterDetail(character)
                                }
                            )
                        }
                    } header: {
                        Text("Your Characters")
                    }
                }

                // Create Character Button
                if authViewModel.isPremium {
                    Section {
                        Button {
                            showCreateCharacter = true
                        } label: {
                            Label("Create New Character", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Characters")
            .toolbar {
                if viewModel.isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                    }
                }
            }
            .refreshable {
                await viewModel.loadCharacters()
            }
            .sheet(isPresented: $showCreateCharacter) {
                CreateCharacterView(viewModel: viewModel)
            }
            .navigationDestination(for: CharacterDestination.self) { destination in
                switch destination {
                case .detail(let character):
                    CharacterDetailView(character: character)
                case .customize(let character):
                    CharacterCustomizeView(character: character)
                case .create:
                    CreateCharacterView(viewModel: viewModel)
                }
            }
            .task {
                if authViewModel.authState == .authenticated {
                    await viewModel.loadCharacters()
                }
            }
        }
    }
}

// MARK: - Predefined Character Row
struct PredefinedCharacterRow: View {
    let character: PredefinedCharacter

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(characterColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: character.icon)
                    .font(.title2)
                    .foregroundColor(characterColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(character.displayName)
                        .fontWeight(.medium)

                    if character.isFree {
                        Text("FREE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    } else {
                        Text("PREMIUM")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }

                Text(character.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var characterColor: Color {
        switch character.color {
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "blue": return .blue
        default: return .purple
        }
    }
}

// MARK: - Custom Character Row
struct CustomCharacterRow: View {
    let character: AICharacter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Text(character.name.prefix(1).uppercased())
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if let backstory = character.backstory {
                        Text(backstory)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    if let traits = character.personalityTraits, !traits.isEmpty {
                        Text(traits.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Character Detail View
struct CharacterDetailView: View {
    let character: AICharacter
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Text(character.name.prefix(1).uppercased())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }

                // Name
                Text(character.name)
                    .font(.title)
                    .fontWeight(.bold)

                // Info Cards
                VStack(spacing: 16) {
                    if let backstory = character.backstory, !backstory.isEmpty {
                        InfoCard(title: "Backstory", content: backstory)
                    }

                    if let traits = character.personalityTraits, !traits.isEmpty {
                        InfoCard(title: "Personality", content: traits.joined(separator: ", "))
                    }

                    if let patterns = character.speechPatterns, !patterns.isEmpty {
                        InfoCard(title: "Speech Style", content: patterns.joined(separator: ", "))
                    }
                }
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        navigationCoordinator.navigateToCharacterCustomization(character)
                    } label: {
                        Text("Customize")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button {
                        // Start chat with this character
                        dismiss()
                    } label: {
                        Text("Start Chat")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Character Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InfoCard: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text(content)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Character Customize View
struct CharacterCustomizeView: View {
    let character: AICharacter
    @State private var name: String
    @State private var backstory: String
    @State private var traits: String
    @Environment(\.dismiss) var dismiss

    init(character: AICharacter) {
        self.character = character
        _name = State(initialValue: character.name)
        _backstory = State(initialValue: character.backstory ?? "")
        _traits = State(initialValue: character.personalityTraits?.joined(separator: ", ") ?? "")
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
            }

            Section("Backstory") {
                TextEditor(text: $backstory)
                    .frame(minHeight: 100)
            }

            Section("Personality Traits") {
                TextField("Traits (comma separated)", text: $traits)
            }
        }
        .navigationTitle("Customize")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    // Save customization
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Create Character View
struct CreateCharacterView: View {
    @ObservedObject var viewModel: CharacterListViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var backstory = ""
    @State private var traits = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Character Name", text: $name)
                }

                Section("Backstory") {
                    TextEditor(text: $backstory)
                        .frame(minHeight: 100)
                }

                Section("Personality") {
                    TextField("Traits (comma separated)", text: $traits)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Create Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        createCharacter()
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }

    private func createCharacter() {
        isCreating = true
        let traitsArray = traits.isEmpty ? nil : traits.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }

        Task {
            do {
                _ = try await viewModel.createCharacter(
                    name: name,
                    backstory: backstory.isEmpty ? nil : backstory,
                    traits: traitsArray
                )
                dismiss()
            } catch {
                // Handle error
            }
            isCreating = false
        }
    }
}

#Preview {
    CharacterListView()
        .environmentObject(AuthViewModel())
        .environmentObject(NavigationCoordinator())
}
