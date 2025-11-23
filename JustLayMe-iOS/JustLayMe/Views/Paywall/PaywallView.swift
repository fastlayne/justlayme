import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: SubscriptionPlan = SubscriptionPlan.plans[1]
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.appDarkBg
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Unlock Premium")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.premiumGradient)

                        Text("Get unlimited access to all AI companions")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, 40)

                    // Pricing Cards
                    VStack(spacing: 12) {
                        ForEach(SubscriptionPlan.plans) { plan in
                            PricingCard(
                                plan: plan,
                                isSelected: selectedPlan.id == plan.id
                            ) {
                                selectedPlan = plan
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Continue Button
                    PremiumButton(
                        title: "Continue to Payment",
                        isLoading: isLoading
                    ) {
                        proceedToPayment()
                    }
                    .padding(.horizontal, 20)

                    // Skip Link
                    Button(action: { dismiss() }) {
                        Text("Try limited free version")
                            .font(.footnote)
                            .foregroundColor(.appTextSecondary)
                            .underline()
                    }

                    // Privacy Note
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Your privacy is protected. No data is stored without consent.")
                            .font(.caption2)
                    }
                    .foregroundColor(.appTextSecondary)
                    .padding(.bottom, 30)
                }
            }

            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.appCardBg)
                            .cornerRadius(16)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }

    private func proceedToPayment() {
        isLoading = true
        // Handle Stripe payment
        Task {
            do {
                let authManager = AuthManager.shared
                let response = try await APIService.shared.createCheckoutSession(
                    plan: selectedPlan.id,
                    userId: authManager.currentUser?.id ?? "guest_\(Date().timeIntervalSince1970)",
                    email: authManager.currentUser?.email ?? "guest@payment.com"
                )
                // Open Stripe checkout URL
                // In a real app, use ASWebAuthenticationSession or SFSafariViewController
                print("Checkout session: \(response.sessionId)")
            } catch {
                print("Payment error: \(error)")
            }
            isLoading = false
        }
    }
}

struct PricingCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Price Header
                HStack {
                    Text(plan.formattedPrice)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(plan.period)
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)

                    Spacer()

                    if plan.isRecommended {
                        Text("BEST VALUE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appGold)
                            .cornerRadius(8)
                    }
                }

                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.appSuccess)

                            Text(feature)
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                plan.isRecommended ?
                Color.appGold.opacity(0.05) :
                Color.white.opacity(0.05)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.appPrimary :
                        (plan.isRecommended ? Color.appGold : Color.appBorder),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

#Preview {
    PaywallView()
}
