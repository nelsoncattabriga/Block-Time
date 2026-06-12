//
//  SummaryRow.swift
//  Block-Time
//
//  Special row component for displaying aircraft hour summaries
//

import SwiftUI
import BlockTimeKit

struct SummaryRow: View, Equatable {
    let sector: FlightSector
    var showTimesInHoursMinutes: Bool = false
    @Environment(\.colorScheme) var colorScheme

    // Equatable conformance
    static func == (lhs: SummaryRow, rhs: SummaryRow) -> Bool {
        return lhs.sector.id == rhs.sector.id &&
               lhs.sector.date == rhs.sector.date &&
               lhs.sector.aircraftType == rhs.sector.aircraftType &&
               lhs.sector.blockTime == rhs.sector.blockTime &&
               lhs.sector.nightTime == rhs.sector.nightTime &&
               lhs.sector.p1Time == rhs.sector.p1Time &&
               lhs.sector.p1usTime == rhs.sector.p1usTime &&
               lhs.sector.p2Time == rhs.sector.p2Time &&
               lhs.sector.instrumentTime == rhs.sector.instrumentTime &&
               lhs.sector.simTime == rhs.sector.simTime &&
               lhs.sector.spInsTime == rhs.sector.spInsTime &&
               lhs.sector.remarks == rhs.sector.remarks &&
               lhs.showTimesInHoursMinutes == rhs.showTimesInHoursMinutes
    }

    // Cached date formatter
    private static let cachedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    private static let cachedMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // Computed properties for date display
    private var dayOfMonth: String {
        let components = sector.date.split(separator: "/")
        return components.first.map(String.init) ?? ""
    }

    private var formattedDate: String {
        if let date = Self.cachedDateFormatter.date(from: sector.date) {
            return Self.cachedMonthYearFormatter.string(from: date).uppercased()
        }
        return sector.date
    }

    // Fixed 8-slot grid: row 1 = Total | P1 | ICUS | P2, row 2 = Night | SIM | INST | Sp/INS
    private var timeGrid: [(label: String, value: Double?)] {
        let simValue = sector.simTimeValue > 0 && !sector.isSpInsOnly ? sector.simTimeValue : nil
        return [
            ("Total",  sector.blockTimeValue > 0      ? sector.blockTimeValue      : nil),
            ("P1",     sector.p1TimeValue > 0          ? sector.p1TimeValue          : nil),
            ("ICUS",   sector.p1usTimeValue > 0        ? sector.p1usTimeValue        : nil),
            ("P2",     sector.p2TimeValue > 0          ? sector.p2TimeValue          : nil),
            ("Night",  sector.nightTimeValue > 0       ? sector.nightTimeValue       : nil),
            ("SIM",    simValue),
            ("INST",   sector.instrumentTimeValue > 0  ? sector.instrumentTimeValue  : nil),
            ("Sp/INS", sector.spInsTimeValue > 0       ? sector.spInsTimeValue       : nil),
        ]
    }

    // Format time value
    private func formatTime(_ value: Double) -> String {
        if showTimesInHoursMinutes {
            return FlightSector.decimalToHHMM(value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Day and Date Column
            VStack(spacing: 0) {
                Text(dayOfMonth)
                    .font(.title.bold())
                    .foregroundColor(.teal.opacity(0.9))

                Text(formattedDate)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 50)
            .padding(.leading, 10)

            // Vertical divider
            Rectangle()
                .fill(Color.teal.opacity(0.8))
                .frame(width: 2)
                .padding(.vertical, 8)
                .padding(.leading, 8)

            // Summary Details Column
            VStack(alignment: .leading, spacing: 8) {
                // Header: Aircraft Type Summary
                HStack {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.headline)
                        .foregroundColor(.teal)

                    Text(sector.aircraftType)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Summary badge
                    Text("SUMMARY")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.teal)
                        .cornerRadius(4)
                }

                // Time entries grid — single row if ≤4 populated, fixed 2×4 otherwise
                let populated = timeGrid.filter { $0.value != nil }
                let useFixedGrid = populated.count > 4
                let displayEntries = useFixedGrid ? timeGrid : populated.map { ($0.label, Optional($0.value!)) }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(displayEntries, id: \.label) { entry in
                        if let value = entry.value {
                            VStack(spacing: 4) {
                                Text(entry.label)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatTime(value))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.teal.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(spacing: 4) {
                                Text(entry.label)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary.opacity(0.25))
                                Text("—")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary.opacity(0.25))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                // Remarks if present
                if !sector.remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(sector.remarks)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.vertical, 12)
        .appCardStyle()
    }
}

#Preview("SummaryRow") {
    VStack(spacing: 16) {
        SummaryRow(
            sector: FlightSector(
                date: "15/01/2026",
                flightNumber: "SUMMARY",
                aircraftReg: "",
                aircraftType: "B77X",
                fromAirport: "",
                toAirport: "",
                captainName: "",
                foName: "",
                blockTime: "1250.5",
                nightTime: "320.0",
                p1Time: "800.0",
                p1usTime: "150.0",
                p2Time: "450.5",
                instrumentTime: "0.0",
                simTime: "45.0",
                isPilotFlying: false,
                remarks: "Previous hours from airline XYZ"
            ),
            showTimesInHoursMinutes: false
        )
        .padding(.horizontal)

        SummaryRow(
            sector: FlightSector(
                date: "10/01/2026",
                flightNumber: "SUMMARY",
                aircraftReg: "",
                aircraftType: "A320",
                fromAirport: "",
                toAirport: "",
                captainName: "",
                foName: "",
                blockTime: "500.0",
                nightTime: "0.0",
                p1Time: "500.0",
                p1usTime: "0.0",
                p2Time: "0.0",
                instrumentTime: "0.0",
                simTime: "0.0",
                isPilotFlying: false,
                remarks: ""
            ),
            showTimesInHoursMinutes: true
        )
        .padding(.horizontal)
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
