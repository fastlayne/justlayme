import SwiftUI

/// Launch screen view that matches the storyboard launch screen
/// This is shown briefly while the app loads
struct LaunchScreen: View {
    var body: some View {
        ZStack {
            // Background color matching LaunchScreenBackground
            Color(red: 15/255, green: 15/255, blue: 35/255) // #0F0F23
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // App Icon
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 139/255, green: 92/255, blue: 246/255), // #8B5CF6
                                Color(red: 167/255, green: 139/255, blue: 250/255) // #A78BFA
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // App Name
                Text("JustLayMe")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    LaunchScreen()
}
