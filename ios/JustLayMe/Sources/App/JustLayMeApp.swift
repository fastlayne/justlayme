// JustLayMeApp.swift
// JustLayMe iOS - App Entry Point
// Main application structure

import SwiftUI

@main
struct JustLayMeApp: App {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environment(\.managedObjectContext, persistence.viewContext)
                .onAppear {
                    setupAppearance()
                }
        }
    }

    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "0a0a0f"))
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color(hex: "0a0a0f"))

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showingPaywall = false

    var body: some View {
        ZStack {
            // Main content
            if viewModel.currentConversation != nil {
                NavigationView {
                    ChatView(conversation: viewModel.currentConversation!)
                        .environmentObject(viewModel)
                }
            } else {
                ConversationListView()
                    .environmentObject(viewModel)
            }

            // Paywall overlay
            if viewModel.showPaywall {
                PaywallView(isPresented: $viewModel.showPaywall)
                    .environmentObject(viewModel)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool

    @State private var selectedPlan: PaymentPlan = .yearly

    enum PaymentPlan: String, CaseIterable {
        case monthly = "monthly"
        case yearly = "yearly"
        case lifetime = "lifetime"

        var price: String {
            switch self {
            case .monthly: return "$9.99"
            case .yearly: return "$79.99"
            case .lifetime: return "$199"
            }
        }

        var period: String {
            switch self {
            case .monthly: return "/month"
            case .yearly: return "/year"
            case .lifetime: return "once"
            }
        }

        var features: [String] {
            switch self {
            case .monthly:
                return ["Unlimited messages", "All AI personalities", "Priority responses", "Cancel anytime"]
            case .yearly:
                return ["Everything in monthly", "Save 33%", "Custom personalities", "Early access features"]
            case .lifetime:
                return ["Lifetime access", "All future updates", "VIP support", "API access"]
            }
        }

        var isRecommended: Bool {
            self == .yearly
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Paywall card
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Unlock Premium")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Get unlimited access to all AI companions")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Plans
                VStack(spacing: 12) {
                    ForEach(PaymentPlan.allCases, id: \.self) { plan in
                        PlanCard(
                            plan: plan,
                            isSelected: selectedPlan == plan
                        ) {
                            selectedPlan = plan
                        }
                    }
                }

                // Purchase button
                Button(action: proceedToPayment) {
                    Text("Continue to Payment")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "667eea"),
                                    Color(hex: "764ba2")
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }

                // Skip button
                Button("Try limited free version") {
                    isPresented = false
                }
                .font(.caption)
                .foregroundColor(.gray)

                // Privacy note
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("Your privacy is protected. No data is stored without consent.")
                        .font(.caption2)
                }
                .foregroundColor(.gray)
            }
            .padding(24)
            .background(Color(hex: "1a1a2e"))
            .cornerRadius(24)
            .padding(20)
        }
    }

    private func proceedToPayment() {
        // TODO: Implement Stripe payment
        print("Selected plan: \(selectedPlan.rawValue)")
        isPresented = false
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: PaywallView.PaymentPlan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.price)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text(plan.period)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        if plan.isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "6b46ff"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "6b46ff").opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? Color(hex: "6b46ff") : .gray)
                        .font(.title2)
                }

                // Features
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(Color(hex: "6b46ff"))

                            Text(feature)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color(hex: "6b46ff") : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ChatViewModel(persistence: PersistenceController.preview))
    }
}
