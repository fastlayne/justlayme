import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject private var viewModel: SubscriptionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection

                        // Current Status
                        if viewModel.isPremium {
                            currentStatusSection
                        }

                        // Plans
                        plansSection

                        // Features comparison
                        featuresSection

                        // Restore purchases
                        restoreButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .task {
                await viewModel.loadProducts()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    viewModel.successMessage = nil
                    if viewModel.isPremium {
                        dismiss()
                    }
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock Premium")
                .font(AppFonts.title)
                .foregroundColor(.white)

            Text("Get unlimited access to all AI models and features")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Current Status

    private var currentStatusSection: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(AppColors.success)

            VStack(alignment: .leading, spacing: 4) {
                Text("You're Premium!")
                    .font(AppFonts.medium(16))
                    .foregroundColor(.white)

                Text(viewModel.statusText)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppColors.success.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Plans Section

    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.plans) { plan in
                PlanCard(
                    plan: plan,
                    isSelected: viewModel.selectedPlan?.id == plan.id,
                    price: viewModel.formattedPrice(for: plan),
                    savings: viewModel.savings(for: plan)
                ) {
                    viewModel.selectPlan(plan)
                }
            }

            // Subscribe button
            Button {
                Task {
                    await viewModel.purchase()
                }
            } label: {
                HStack {
                    if viewModel.isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Subscribe Now")
                            .font(AppFonts.semibold(16))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    viewModel.selectedPlan != nil && !viewModel.isPremium
                        ? AppColors.primaryGradient
                        : LinearGradient(colors: [AppColors.textMuted], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(14)
            }
            .disabled(viewModel.selectedPlan == nil || viewModel.isPurchasing || viewModel.isPremium)
            .padding(.top, 8)
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What you get")
                .font(AppFonts.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(SubscriptionPlan.premiumFeatures, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)

                        Text(feature)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            Task {
                await viewModel.restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .font(AppFonts.medium(14))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let price: String
    let savings: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.name)
                            .font(AppFonts.medium(16))
                            .foregroundColor(.white)

                        if plan.isMostPopular {
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.success)
                                .cornerRadius(4)
                        }
                    }

                    Text(plan.duration.displayName)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(price)
                        .font(AppFonts.bold(18))
                        .foregroundColor(.white)

                    if let savings = savings {
                        Text(savings)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.success)
                    }
                }

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textMuted)
                    .padding(.leading, 8)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? AppColors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionViewModel())
}
