//
//  UnifiedRosterPreviewView.swift
//  Block-Time
//
//  Created by Nelson on 03/11/2025.
//

import SwiftUI

/// Unified view for previewing and selecting flights before importing from any roster type
struct UnifiedRosterPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let parsedFlights: [UnifiedParsedFlight]
    let pilotInfo: UnifiedParseResult
    let onImport: ([UnifiedParsedFlight]) -> Void

    @State private var selectedFlights: Set<UUID> = []
    @State private var flightIDs: [UUID] = []
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with summary
                headerSection
                    .padding()
                    .background(Color(.systemGray6).opacity(0.75))

                // Flight list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(parsedFlights.enumerated()), id: \.offset) { index, flight in
                            let flightID = flightIDs[index]
                            UnifiedFlightPreviewRow(
                                flight: flight,
                                isSelected: selectedFlights.contains(flightID)
                            ) {
                                if selectedFlights.contains(flightID) {
                                    selectedFlights.remove(flightID)
                                } else {
                                    selectedFlights.insert(flightID)
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Bottom toolbar with actions
                bottomToolbar
            }
            .navigationTitle("Review Flights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleSelectAll()
                    } label: {
                        Text(allSelected ? "Deselect All" : "Select All")
                            .font(.subheadline)
                            .animation(nil, value: allSelected)
                    }
                }
            }
        }
        .onAppear {
            // Generate unique IDs for each flight
            flightIDs = (0..<parsedFlights.count).map { _ in UUID() }
            // Select all by default
            selectedFlights = Set(flightIDs)
        }
    }

    // MARK: - Computed Properties

    private var allSelected: Bool {
        selectedFlights.count == parsedFlights.count
    }

    private var selectedCount: Int {
        selectedFlights.count
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Roster Preview")
                        .font(.headline)
                    Text("\(parsedFlights.count) flight\(parsedFlights.count == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(pilotInfo.pilotName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack(spacing: 4) {
//                        Text(pilotInfo.rosterType.displayName)
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundStyle(.white)
//                            .padding(.horizontal, 6)
//                            .padding(.vertical, 2)
//                            .background(pilotInfo.rosterType == .shortHaul ? Color.blue : Color.purple)
//                            .clipShape(.rect(cornerRadius: 4))
                        Text("BP \(pilotInfo.bidPeriod)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !allSelected {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)

                    Text("\(selectedCount) of \(parsedFlights.count) flight\(selectedCount == 1 ? "" : "s") selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 16) {
                Button(action: importSelectedFlights) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        Text(isImporting ? "Importing..." : "Import \(selectedCount)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedCount > 0 ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .disabled(selectedCount == 0 || isImporting)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Helper Functions

    private func toggleSelectAll() {
        if allSelected {
            selectedFlights.removeAll()
        } else {
            selectedFlights = Set(flightIDs)
        }
    }

    private func importSelectedFlights() {
        isImporting = true

        // Filter to only selected flights
        let flightsToImport = parsedFlights.enumerated().compactMap { index, flight in
            selectedFlights.contains(flightIDs[index]) ? flight : nil
        }

        // Call the import callback
        onImport(flightsToImport)
    }
}

// MARK: - Unified Flight Preview Row

private struct UnifiedFlightPreviewRow: View {
    let flight: UnifiedParsedFlight
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .frame(width: 24)

                // Flight details
                VStack(alignment: .leading, spacing: 8) {
                    // Top row: Flight number, date
                    HStack {
                        Text("QF\(flight.flightNumber)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(formatDate(flight.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Middle row: Route and times
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(flight.departureAirport)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(formatTime(flight.departureTime))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(flight.arrivalAirport)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(formatTime(flight.arrivalTime))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    // Bottom row: badges
                    if flight.isPositioning {
                        HStack(spacing: 8) {
                            Text("PAX")
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(.rect(cornerRadius: 4))

                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ time: String) -> String {
        guard time.count == 4 else { return time }
        let hours = time.prefix(2)
        let minutes = time.suffix(2)
        return "\(hours):\(minutes)"
    }
}

#Preview {
    // Create sample flights for preview
    let sampleFlights = [
        UnifiedParsedFlight(
            date: Date(),
            flightNumber: "613",
            departureAirport: "BNE",
            arrivalAirport: "MEL",
            departureTime: "0800",
            arrivalTime: "1125",
            aircraftType: "B738",
            role: "Captain",
            isPositioning: false,
            bidPeriod: "3711",
            dutyCode: nil,
            rosterType: .shortHaul
        ),
        UnifiedParsedFlight(
            date: Date().addingTimeInterval(86400),
            flightNumber: "11",
            departureAirport: "SYD",
            arrivalAirport: "LAX",
            departureTime: "1030",
            arrivalTime: "0650",
            aircraftType: "B789",
            role: "First Officer",
            isPositioning: false,
            bidPeriod: "356",
            dutyCode: "EN04X011",
            rosterType: .longHaul
        )
    ]

    let sampleInfo = UnifiedParseResult(
        flights: sampleFlights,
        pilotName: "John Smith",
        staffNumber: "12345",
        bidPeriod: "3711",
        base: "BNE",
        category: "CPT-B737",
        rosterType: .shortHaul
    )

    UnifiedRosterPreviewView(
        parsedFlights: sampleFlights,
        pilotInfo: sampleInfo,
        onImport: { _ in }
    )
}
