import SwiftUI

// MARK: - Custom Text Field

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isFocused ? AppColors.primary : AppColors.textMuted)
                    .frame(width: 24)
            }

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(AppColors.textMuted))
                .font(AppFonts.body)
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(AppColors.inputBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? AppColors.primary : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Custom Secure Field

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?

    @State private var isSecure: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isFocused ? AppColors.primary : AppColors.textMuted)
                    .frame(width: 24)
            }

            Group {
                if isSecure {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(AppColors.textMuted))
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(AppColors.textMuted))
                }
            }
            .font(AppFonts.body)
            .foregroundColor(.white)
            .textContentType(.password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isFocused)

            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(AppColors.inputBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? AppColors.primary : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Custom Text Editor

struct CustomTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            TextEditor(text: $text)
                .font(AppFonts.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minHeight: minHeight)
        .background(AppColors.inputBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? AppColors.primary : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textMuted)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(AppColors.textMuted))
                .font(AppFonts.body)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(AppColors.inputBackground)
        .cornerRadius(22)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CustomTextField(
            placeholder: "Email",
            text: .constant(""),
            icon: "envelope.fill"
        )

        CustomSecureField(
            placeholder: "Password",
            text: .constant(""),
            icon: "lock.fill"
        )

        SearchBar(text: .constant(""))
    }
    .padding()
    .background(AppColors.darkBackground)
}
