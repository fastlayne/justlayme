import SwiftUI

struct CharacterSelectorView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.characters) { character in
                    CharacterCard(
                        character: character,
                        isSelected: viewModel.selectedCharacter.id == character.id
                    ) {
                        viewModel.selectCharacter(character)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 70)
        .background(
            Color.black.opacity(0.95)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct CharacterCard: View {
    let character: AICharacter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CharacterAvatar(character: character, size: 32)

                Text(character.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                AnyView(Color.appPrimary.opacity(0.15)) :
                AnyView(Color.white.opacity(0.12))
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.appPrimary : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? Color.appPrimary.opacity(0.3) : Color.clear,
                radius: isSelected ? 8 : 0
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct CharacterAvatar: View {
    let character: AICharacter
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: character.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if character.isFree {
                Text("free")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text(character.avatarLetter)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
    }
}

#Preview {
    VStack {
        CharacterSelectorView(viewModel: ChatViewModel())
        Spacer()
    }
    .background(Color.appDarkBg)
}
