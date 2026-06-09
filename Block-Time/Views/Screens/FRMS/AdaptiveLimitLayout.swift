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
    /// Pass `true` from LH callers to rename "Max Flight Time" → "Inflight Management".
    /// When `false` (default, SH) and `flightTimeDisplay` would be "—", the flight-time
    /// row is hidden entirely (SH has no flight time limit in Rev5).
    var isLongHaul: Bool = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private func formatTime(_ hours: Double) -> String {
        if showTimesInHoursMinutes {
            return hours.toHoursMinutesString
        } else {
            return String(format: "%.1f hrs", hours)
        }
    }

    private var flightTimeDisplay: String {
        if let notes = range.notes { return notes }
        if let ft = range.getMaxFlight(for: limitType) { return formatTime(ft) }
        return "—"
    }

    /// True when the flight-time row should be shown.
    /// LH always shows it. SH hides it when the value would be "—" (no limit defined in Rev5).
    private var showFlightTimeRow: Bool {
        isLongHaul || flightTimeDisplay != "—"
    }

    private var flightTimeLabel: String {
        isLongHaul ? "Inflight Management" : "Max Flight Time"
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

                if showFlightTimeRow {
                    LimitInfoView(
                        icon: "airplane",
                        label: flightTimeLabel,
                        value: flightTimeDisplay,
                        valueColor: AppColors.accentBlue
                    )
                }

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

                if showFlightTimeRow {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Label(flightTimeLabel, systemImage: "airplane")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(flightTimeDisplay)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.accentBlue)
                    }
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
