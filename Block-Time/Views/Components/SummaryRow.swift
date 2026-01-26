//
//  SummaryRow.swift
//  Block-Time
//
//  Special row component for displaying aircraft hour summaries
//

import SwiftUI

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
               lhs.sector.simTime == rhs.sector.simTime &&
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

    // Get time fields that have values
    private var timeEntries: [(label: String, value: Double)] {
        var entries: [(String, Double)] = []

        if sector.blockTimeValue > 0 {
            entries.append(("Total", sector.blockTimeValue))
        }
        if sector.nightTimeValue > 0 {
            entries.append(("Night", sector.nightTimeValue))
        }
        if sector.simTimeValue > 0 {
            entries.append(("SIM", sector.simTimeValue))
        }
        if sector.p1TimeValue > 0 {
            entries.append(("P1", sector.p1TimeValue))
        }
        if sector.p1usTimeValue > 0 {
            entries.append(("P1US", sector.p1usTimeValue))
        }
        if sector.p2TimeValue > 0 {
            entries.append(("P2", sector.p2TimeValue))
        }
//        if sector.simTimeValue > 0 {
//            entries.append(("SIM", sector.simTimeValue))
//        }

        return entries
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

                // Time entries grid
                if !timeEntries.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(timeEntries, id: \.label) { entry in
                            HStack(spacing: 4) {
                                Text(entry.label)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(formatTime(entry.value))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.teal.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.teal.opacity(0.3), lineWidth: 1.5)
        )
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
