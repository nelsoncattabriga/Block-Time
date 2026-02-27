//
//  PaywallView.swift
//  Block-Time
//
//  Shown when the 30-day trial has expired and the user hasn't purchased Pro.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(PurchaseService.self) private var purchaseService
    @Environment(ThemeService.self) private var themeService

    var body: some View {
        ZStack {
            // Background gradient
            themeService.getGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    featuresSection
                    purchaseSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
            }
        }
        .task {
            await purchaseService.loadProducts()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            Text("Your Trial Has Ended")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Unlock Block Time Pro to continue tracking your flights, FRMS limits, and career insights.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
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
                        .overlay(Color.white.opacity(0.2))
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundStyle(AppColors.accentOrange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(feature.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        VStack(spacing: 16) {
            // Primary purchase button
            Button {
                Task { await purchaseService.purchase() }
            } label: {
                HStack {
                    if purchaseService.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text(purchaseButtonTitle)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(purchaseService.isLoading || purchaseService.products.isEmpty)

            // Restore purchases
            Button("Restore Purchase") {
                Task { await purchaseService.restorePurchases() }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.75))
            .disabled(purchaseService.isLoading)

            // Error message
            if let error = purchaseService.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

            Text("One-time purchase. No subscriptions.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Helpers

    private var purchaseButtonTitle: String {
        if let product = purchaseService.products.first {
            return "Unlock Block Time Pro — \(product.displayPrice)"
        }
        return "Unlock Block Time Pro"
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
