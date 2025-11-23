import SwiftUI

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
        }
    }
}

// MARK: - Icon Badge
struct IconBadge: View {
    let systemName: String
    let color: Color
    let size: CGFloat

    init(_ systemName: String, color: Color = .purple, size: CGFloat = 50) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .font(.system(size: size * 0.4))
                .foregroundColor(color)
        }
    }
}

// MARK: - Avatar View
struct AvatarView: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat = 50) {
        self.name = name
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.purple.gradient)
                .frame(width: size, height: size)

            Text(name.prefix(1).uppercased())
                .font(.system(size: size * 0.4))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text(title)
                .font(.title2)
                .fontWeight(.medium)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.medium)
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }
}

// MARK: - Loading State View
struct LoadingStateView: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let message: String
    let retryAction: (() -> Void)?

    init(_ message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let retryAction = retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Divider with Text
struct DividerWithText: View {
    let text: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
    }
}

// MARK: - Pill Tag
struct PillTag: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = .purple) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(20)
    }
}

// MARK: - Previews
#Preview("Buttons") {
    VStack(spacing: 20) {
        PrimaryButton("Primary Button") {}
        PrimaryButton("Loading", isLoading: true) {}
        SecondaryButton("Secondary Button") {}
    }
    .padding()
}

#Preview("Badges") {
    HStack(spacing: 20) {
        IconBadge("star.fill", color: .yellow)
        AvatarView("John Doe")
        StatusBadge(text: "FREE", color: .green)
        PillTag("Premium", color: .purple)
    }
}

#Preview("States") {
    VStack(spacing: 40) {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No Conversations",
            message: "Start chatting to see your history",
            actionTitle: "Start Chat"
        ) {}

        LoadingStateView("Loading messages...")

        ErrorStateView("Failed to load data") {}
    }
}
