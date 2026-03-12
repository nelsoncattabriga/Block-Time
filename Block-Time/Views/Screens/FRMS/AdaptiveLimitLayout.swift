//
//  AdaptiveLimitLayout.swift
//  Block-Time
//
//  Adaptive sign-on time range layout for FRMS duty limit cards.
//  Extracted from FRMSView.swift.
//

import SwiftUI

struct AdaptiveLimitLayout: View {
    let range: SignOnTimeRange
    let limitType: FRMSLimitType
    let showTimesInHoursMinutes: Bool

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private func formatTime(_ hours: Double) -> String {
        if showTimesInHoursMinutes {
            return hours.toHoursMinutesString
        } else {
            return "\(hours.formatted(.number.precision(.fractionLength(1)))) hrs"
        }
    }

    private var flightTimeDisplay: String {
        return range.notes ?? formatTime(range.getMaxFlight(for: limitType))
    }

    var body: some View {
        if horizontalSizeClass == .compact {
            // iPhone layout
            VStack(alignment: .leading, spacing: 10) {
                LimitInfoView(
                    icon: "clock",
                    label: "Max Duty",
                    value: formatTime(range.getMaxDuty(for: limitType)),
                    valueColor: AppColors.accentOrange
                )

                LimitInfoView(
                    icon: "airplane",
                    label: "Max Flight Time",
                    value: flightTimeDisplay,
                    valueColor: AppColors.accentBlue
                )

                if let sectorLimit = range.sectorLimit {
                    LimitInfoView(
                        icon: "airplane",
                        label: "Sectors",
                        value: sectorLimit,
                        valueColor: .secondary
                    )
                }
            }
        } else {
            // iPad layout
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Max Duty", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(formatTime(range.getMaxDuty(for: limitType)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.accentOrange)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Label("Max Flight Time", systemImage: "airplane")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(flightTimeDisplay)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.accentBlue)
                }

                if let sectorLimit = range.sectorLimit {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Sectors", systemImage: "airplane")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(sectorLimit)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// Helper view for iPhone layout
struct LimitInfoView: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
