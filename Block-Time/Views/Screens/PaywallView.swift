//
//  PaywallView.swift
//  Block-Time
//
//  Shown when the 30-day trial has expired and the user hasn't purchased Pro.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    var isDismissible: Bool = false
    @Environment(PurchaseService.self) private var purchaseService
    @Environment(ThemeService.self) private var themeService
    @Environment(\.dismiss) private var dismiss

    private let skyBlue = Color(red: 0.18, green: 0.52, blue: 0.92)
    private let deepBlue = Color(red: 0.08, green: 0.25, blue: 0.60)
    private let accentBlue = Color(red: 0.38, green: 0.72, blue: 1.0)

    var body: some View {
        ZStack {
            // Deep blue gradient background
            LinearGradient(
                colors: [deepBlue, skyBlue, Color(red: 0.12, green: 0.38, blue: 0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle top glow
            VStack {
                Ellipse()
                    .fill(accentBlue.opacity(0.25))
                    .frame(width: 360, height: 200)
                    .blur(radius: 60)
                    .offset(y: -40)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if isDismissible {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 20)
                    }
                }

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        featuresSection
                        purchaseSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, isDismissible ? 8 : 28)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .task {
            await purchaseService.loadProducts()
        }
        .onChange(of: purchaseService.isPro) { _, isPro in
            if isPro {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    dismiss()
                }
            }
        }
        .alert("No Purchase Found", isPresented: Bindable(purchaseService).showRestoreNotFoundAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No previous Block-Time purchase found using this Apple ID.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accentBlue.opacity(0.2))
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(accentBlue.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image("SplashIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: deepBlue.opacity(0.5), radius: 10, x: 0, y: 4)
            }

            Text(purchaseService.isTrialActive ? "Unlock Block-Time" : "Your Trial Has Ended")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(purchaseService.isTrialActive
                 ? "Purchase Block-Time Now."
                 : "Purchase Block-Time to continue tracking your flights.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.80))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(proFeatures, id: \.title) { feature in
                featureRow(feature)
                if feature.title != proFeatures.last?.title {
                    Divider()
                        .overlay(.white.opacity(0.15))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.90))
                    .frame(width: 38, height: 38)
                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.accentOrange)
            }
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(feature.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white.opacity(0.80))
                .font(.system(size: 18))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            // Primary purchase button
            Button {
                Task { await purchaseService.purchase() }
            } label: {
                HStack {
                    if purchaseService.isLoading {
                        ProgressView()
                            .tint(deepBlue)
                    } else if purchaseService.products.isEmpty {
                        ProgressView()
                            .tint(.white)
                        Text("Loading…")
                            .fontWeight(.bold)
                    } else {
                        Image(systemName: "lock.open.fill")
                            .font(.subheadline)
                        Text(purchaseButtonTitle)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [accentBlue, skyBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: deepBlue.opacity(0.5), radius: 8, x: 0, y: 4)
            }
            .disabled(purchaseService.isLoading || purchaseService.products.isEmpty)

            Text("One-time purchase. No subscriptions.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
            
            // Restore purchases
            Button("Restore Purchase") {
                Task { await purchaseService.restorePurchases() }
            }
            .font(.headline)
            .foregroundStyle(.white.opacity(0.7))
            .disabled(purchaseService.isLoading)

            // Error message
            if let error = purchaseService.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

            
        }
    }

    // MARK: - Helpers

    private var purchaseButtonTitle: String {
        if let product = purchaseService.products.first {
            return "Purchase Now — \(product.displayPrice)"
        }
        return "Purchase Block-Time Pro"
    }

    // MARK: - Feature List

    private struct ProFeature {
        let icon: String
        let title: String
        let description: String
    }

    private let proFeatures: [ProFeature] = [
        ProFeature(icon: "airplane.departure", title: "Flight Logbook", description: "Log unlimited flights with all time fields"),
        ProFeature(icon: "chart.xyaxis.line", title: "Dashboard & Analytics", description: "Career milestones, charts, and heatmaps"),
        ProFeature(icon: "clock.badge.checkmark", title: "FRMS Limits", description: "Real-time fatigue risk monitoring"),
        ProFeature(icon: "square.and.arrow.up", title: "Export & Backup", description: "Export your logbook and schedule backups"),
        ProFeature(icon: "icloud", title: "iCloud Sync", description: "Sync settings across your devices"),
    ]
}

#Preview {
    PaywallView()
        .environment(PurchaseService.shared)
        .environment(ThemeService.shared)
}
