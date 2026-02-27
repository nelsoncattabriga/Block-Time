//
//  TrialStatusCard.swift
//  Block-Time
//
//  Shows trial days remaining or Pro status at the top of Settings.
//

import SwiftUI
import StoreKit

struct TrialStatusCard: View {
    @Environment(PurchaseService.self) private var purchaseService
    @State private var showingPaywall = false

    var body: some View {
        if purchaseService.isPro {
            proCard
        } else {
            trialCard
        }
    }

    // MARK: - Pro Card

    private var proCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Block-Time")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Full access unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("PRO")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue, in: Capsule())
        }
        .padding(16)
        .appCardStyle()
    }

    // MARK: - Trial Card

    private var trialCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(badgeColor.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: badgeIcon)
                        .font(.title2)
                        .foregroundStyle(badgeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Trial")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(trialSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(badgeLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeColor, in: Capsule())
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(badgeColor)
                        .frame(width: geo.size.width * trialProgress, height: 6)
                }
            }
            .frame(height: 6)

            Button {
                showingPaywall = true
            } label: {
                Text("Unlock Block-Time — \(upgradePrice)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .appCardStyle()
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView(isDismissible: true)
        }
    }

    // MARK: - Helpers

    private var trialProgress: CGFloat {
        CGFloat(purchaseService.trialDaysRemaining) / 30.0
    }

    private var trialSubtitle: String {
        let days = purchaseService.trialDaysRemaining
        if days == 0 { return "Your trial has expired" }
        if days == 1 { return "1 day remaining" }
        return "\(days) days remaining"
    }

    private var badgeLabel: String {
        let days = purchaseService.trialDaysRemaining
        if days == 0 { return "EXPIRED" }
        return "\(days)d LEFT"
    }

    private var badgeIcon: String {
        if purchaseService.trialDaysRemaining <= 3 { return "exclamationmark.circle.fill" }
        if purchaseService.trialDaysRemaining <= 7 { return "clock.badge.exclamationmark" }
        return "clock.fill"
    }

    private var badgeColor: Color {
        let days = purchaseService.trialDaysRemaining
        if days == 0 { return .red }
        if days <= 3 { return .red }
        if days <= 7 { return .orange }
        return .blue
    }

    private var upgradePrice: String {
        purchaseService.products.first?.displayPrice ?? "$29.99"
    }
}
