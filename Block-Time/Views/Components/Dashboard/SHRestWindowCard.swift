//
//  SHRestWindowCard.swift
//  Block-Time
//
//  Timeline card showing the minimum rest window and earliest sign-on
//  after the last completed duty, based on SH/LH FRMS rules.
//

import SwiftUI

struct SHRestWindowCard: View {
    var frmsViewModel: FRMSViewModel

    private var lastDuty: FRMSDuty? { frmsViewModel.lastDuty }
    private var nextDuty: FRMSMaximumNextDuty? { frmsViewModel.maximumNextDuty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "FRMS Rest", icon: "bed.double.fill")

            if frmsViewModel.isLoading {
                loadingView
            } else if let duty = lastDuty, let next = nextDuty {
                timelineView(duty: duty, next: next)
            } else {
                emptyView
            }
        }
        .padding(16)
        .appCardStyle()
        .task { await triggerFRMSLoadIfNeeded() }
    }

    // MARK: - States

    private var loadingView: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text("Loading FRMS…")
                .iPadScaledFont(.caption, phoneFont: .footnote).foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("No Recent Duties")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Timeline

    @ViewBuilder
    private func timelineView(duty: FRMSDuty, next: FRMSMaximumNextDuty) -> some View {
        let now = Date()
        let signOff = duty.signOff
        let restHours = next.minimumRest
        let restEnd = next.earliestSignOn ?? signOff.addingTimeInterval(restHours * 3600)
        let elapsed = now.timeIntervalSince(signOff)
        let totalRest = restEnd.timeIntervalSince(signOff)
        let progress = totalRest > 0 ? min(max(elapsed / totalRest, 0), 1) : 1
        let restComplete = now >= restEnd

        VStack(spacing: 12) {
            // ── Progress bar ──────────────────────────────────────────────
            restBar(progress: progress, restComplete: restComplete)

            // ── Sign-off / Sign-on row ────────────────────────────────────
            timepointsRow(
                signOff: signOff,
                restEnd: restEnd,
                restComplete: restComplete,
                restHours: restHours
            )

            // ── Status pill ───────────────────────────────────────────────
            statusPill(
                now: now,
                restEnd: restEnd,
                restComplete: restComplete,
                restHours: restHours
            )
        }
    }

    private func restBar(progress: Double, restComplete: Bool) -> some View {
        ProgressView(value: progress)
            .tint(restComplete ? .green : .orange)
            .frame(height: 6)
            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
    }

    private func timepointsRow(
        signOff: Date,
        restEnd: Date,
        restComplete: Bool,
        restHours: Double
    ) -> some View {
        HStack {
            // Sign-off
            VStack(alignment: .leading, spacing: 2) {
                Text("SIGN-OFF")
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(formattedTimeWithDay(signOff))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Min rest label centred
            VStack(spacing: 1) {
                Text(formattedHoursMinutes(restHours))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.indigo)
                Text("Min Rest")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Earliest sign-on
            VStack(alignment: .trailing, spacing: 2) {
                Text("SIGN-ON")
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(formattedTimeWithDay(restEnd))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(restComplete ? .green : .orange)
            }
        }
    }

    private func statusPill(
        now: Date,
        restEnd: Date,
        restComplete: Bool,
        restHours: Double
    ) -> some View {
        let remaining = restEnd.timeIntervalSince(now)

        return HStack(spacing: 6) {
            Spacer()
            if restComplete {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Rest Requirements Met")
                    .font(.footnote).fontWeight(.medium)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "hourglass").foregroundStyle(.gray)
                Text("\(formattedHoursMinutes(remaining / 3600)) Rest Remaining")
                    .font(.footnote).fontWeight(.medium)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(restComplete ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        )
    }

    // MARK: - Formatting

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE HH:mm"
        return f
    }()

    /// Timezone matching FRMSView.formatDateTime: destination airport local time, falling back to device timezone.
    private func timeZone(for date: Date) -> TimeZone {
        let toAirport = lastDuty?.toAirport ?? ""
        return AirportService.shared.getTimeZone(for: toAirport, on: date) ?? .current
    }

    private func formattedTimeWithDay(_ date: Date) -> String {
        let tz = timeZone(for: date)
        Self.timeFormatter.timeZone = tz
        Self.dayTimeFormatter.timeZone = tz
        var cal = Calendar.current
        cal.timeZone = tz
        if cal.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        }
        return Self.dayTimeFormatter.string(from: date)
    }

    private func formattedHoursMinutes(_ decimalHours: Double) -> String {
        guard decimalHours >= 0 else { return "0:00" }
        let total = Int(decimalHours * 60)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - FRMS Load

    @MainActor
    private func triggerFRMSLoadIfNeeded() async {
        guard frmsViewModel.lastDuty == nil, !frmsViewModel.isLoading else { return }
        let raw = UserDefaults.standard.string(forKey: "flightTimePosition") ?? ""
        let position = FlightTimePosition(rawValue: raw) ?? .captain
        frmsViewModel.loadFlightData(crewPosition: position)
    }
}
