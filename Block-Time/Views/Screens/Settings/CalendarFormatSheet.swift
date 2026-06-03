//
//  CalendarFormatSheet.swift
//  Block-Time
//

import SwiftUI

struct CalendarFormatSheet: View {

    @Bindable var settings: CalendarExportSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeService.self) private var themeService

    // MARK: - Placeholder Data

    private static let placeholderSector = FlightSector(
        date: "03/06/2026",
        flightNumber: "QF123",
        aircraftReg: "",
        aircraftType: "",
        fromAirport: "BNE",
        toAirport: "SYD",
        captainName: "",
        foName: "",
        blockTime: "0.0",
        nightTime: "0.0",
        p1Time: "0.0",
        p1usTime: "0.0",
        instrumentTime: "0.0",
        simTime: "0.0",
        isPilotFlying: false,
        isPositioning: false,
        scheduledDeparture: "0900",
        scheduledArrival: "1130"
    )

    private static let placeholderDuty: [FlightSector] = [
        FlightSector(
            date: "03/06/2026",
            flightNumber: "QF101",
            aircraftReg: "",
            aircraftType: "",
            fromAirport: "BNE",
            toAirport: "SYD",
            captainName: "",
            foName: "",
            blockTime: "0.0",
            nightTime: "0.0",
            p1Time: "0.0",
            p1usTime: "0.0",
            instrumentTime: "0.0",
            simTime: "0.0",
            isPilotFlying: false,
            isPositioning: true,
            scheduledDeparture: "0900"
        ),
        FlightSector(
            date: "03/06/2026",
            flightNumber: "QF203",
            aircraftReg: "",
            aircraftType: "",
            fromAirport: "SYD",
            toAirport: "MEL",
            captainName: "",
            foName: "",
            blockTime: "0.0",
            nightTime: "0.0",
            p1Time: "0.0",
            p1usTime: "0.0",
            instrumentTime: "0.0",
            simTime: "0.0",
            isPilotFlying: false,
            isPositioning: false,
            scheduledDeparture: "1200",
            scheduledArrival: "1700"
        ),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                modeSection
                allDaySection
                if settings.mode != .allDayOnly {
                    sectorSection
                }
            }
            .navigationTitle("Event Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var modeSection: some View {
        Section {
            Picker("Export Mode", selection: $settings.mode) {
                ForEach(CalendarExportMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } header: {
            Text("Export Mode")
        }
    }

    private var allDaySection: some View {
        Section {
            previewPill(
                CalendarExportService.shared.buildDailyTitle(
                    for: Self.placeholderDuty,
                    settings: settings
                )
            )

            ForEach($settings.allDayComponents) { $component in
                Toggle(isOn: $component.enabled) {
                    Text(AllDayComponent(rawValue: component.rawValue)?.displayName ?? component.rawValue)
                        .font(.subheadline)
                }
                .tint(.purple)
            }
            .onMove { from, to in
                settings.allDayComponents.move(fromOffsets: from, toOffset: to)
            }
        } header: {
            Text("All-day event format")
        }
    }

    private var sectorSection: some View {
        Section {
            previewPill(
                CalendarExportService.shared.buildSectorTitle(
                    for: Self.placeholderSector,
                    settings: settings
                )
            )

            ForEach($settings.sectorComponents) { $component in
                Toggle(isOn: $component.enabled) {
                    Text(SectorComponent(rawValue: component.rawValue)?.displayName ?? component.rawValue)
                        .font(.subheadline)
                }
                .tint(.purple)
            }
            .onMove { from, to in
                settings.sectorComponents.move(fromOffsets: from, toOffset: to)
            }
        } header: {
            Text("Individual sector format")
        }
    }

    // MARK: - Preview Pill

    @ViewBuilder
    private func previewPill(_ text: String) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

// MARK: - Preview

#Preview {
    CalendarFormatSheet(settings: CalendarExportSettings.shared)
        .environment(ThemeService.shared)
}
