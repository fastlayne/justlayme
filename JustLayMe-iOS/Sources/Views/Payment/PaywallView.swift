import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel = PaymentViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.yellow.gradient)

                        Text("Upgrade to Premium")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Unlock all AI models and unlimited messages")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Features
                    VStack(spacing: 16) {
                        ForEach(viewModel.premiumFeatures) { feature in
                            FeatureRow(feature: feature)
                        }
                    }
                    .padding(.horizontal)

                    // Plans
                    VStack(spacing: 12) {
                        ForEach(viewModel.allPlans) { plan in
                            PlanCard(
                                plan: plan,
                                isSelected: viewModel.selectedPlan == plan,
                                onSelect: { viewModel.selectPlan(plan) }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Subscribe Button
                    Button {
                        Task {
                            await viewModel.initiateCheckout()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Subscribe for \(viewModel.selectedPlan.priceString)\(viewModel.selectedPlan.billingPeriod)")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal)

                    // Terms
                    VStack(spacing: 8) {
                        Text("By subscribing, you agree to our Terms of Service and Privacy Policy.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Text("Subscription will be charged to your payment method. Cancel anytime.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Success!", isPresented: $viewModel.paymentSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Welcome to Premium! Enjoy unlimited access to all features.")
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: PremiumFeature

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .fontWeight(.medium)

                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.displayName)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if let savings = plan.savings {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }

                    Text(plan.priceString + plan.billingPeriod)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .purple : .gray)
            }
            .padding()
            .background(isSelected ? Color.purple.opacity(0.1) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Compact Paywall (for modals)
struct CompactPaywallView: View {
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)

            Text("Premium Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("You've used all your free messages for this model. Upgrade to Premium for unlimited access.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    onUpgrade()
                } label: {
                    Text("Upgrade to Premium")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Try Free Model Instead")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview {
    PaywallView()
}
