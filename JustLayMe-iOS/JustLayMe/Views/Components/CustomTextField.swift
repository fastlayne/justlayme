import SwiftUI

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .foregroundColor(.appTextPrimary)
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button(action: { isVisible.toggle() }) {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .foregroundColor(.appTextPrimary)
    }
}

struct PremiumButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    var style: Style = .primary
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.body.weight(.semibold))
                }
            }
            .foregroundColor(style == .primary ? .white : .appTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                style == .primary ?
                AnyView(Color.premiumGradient) :
                AnyView(Color.appCardBg)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style == .secondary ? Color.appBorder : Color.clear, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

struct UserAvatarView: View {
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.premiumGradient)

            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 16) {
        CustomTextField(placeholder: "Email", text: .constant(""))
        CustomSecureField(placeholder: "Password", text: .constant(""))
        PremiumButton(title: "Continue") {}
        PremiumButton(title: "Cancel", style: .secondary) {}
        UserAvatarView(name: "John", size: 48)
    }
    .padding()
    .background(Color.appDarkBg)
}
