//
//  AircraftSummarySheet.swift
//  Block-Time
//
//  Created for adding and editing historical aircraft time summaries
//

import SwiftUI

struct AircraftSummarySheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeService = ThemeService.shared

    // MARK: - Properties

    let editingSector: FlightSector?
    let onSave: (FlightSector) -> Void
    let onDelete: ((FlightSector) -> Void)?

    @State private var date: Date = Date()
    @State private var aircraftType: String = ""
    @State private var blockTime: String = ""
    @State private var nightTime: String = ""
    @State private var p1Time: String = ""
    @State private var p1usTime: String = ""
    @State private var p2Time: String = ""
    @State private var instrumentTime: String = ""
    @State private var simTime: String = ""
    @State private var remarks: String = ""

    @State private var showingDiscardAlert = false
    @State private var showingDeleteAlert = false
    @State private var hasLoadedEditingData = false

    // Date formatter for FlightSector
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // MARK: - Computed Properties

    private var isEditMode: Bool {
        editingSector != nil
    }

    private var hasModifications: Bool {
        guard let editing = editingSector else {
            // Add mode - check if any field has content
            return !aircraftType.isEmpty ||
                   !blockTime.isEmpty ||
                   !nightTime.isEmpty ||
                   !p1Time.isEmpty ||
                   !p1usTime.isEmpty ||
                   !p2Time.isEmpty ||
                   !instrumentTime.isEmpty ||
                   !simTime.isEmpty ||
                   !remarks.isEmpty
        }

        // Edit mode - check if anything changed from original
        let originalDate = dateFormatter.date(from: editing.date) ?? Date()
        let blockChanged = formatTimeForComparison(blockTime) != formatTimeForComparison(editing.blockTime)
        let nightChanged = formatTimeForComparison(nightTime) != formatTimeForComparison(editing.nightTime)
        let p1Changed = formatTimeForComparison(p1Time) != formatTimeForComparison(editing.p1Time)
        let p1usChanged = formatTimeForComparison(p1usTime) != formatTimeForComparison(editing.p1usTime)
        let p2Changed = formatTimeForComparison(p2Time) != formatTimeForComparison(editing.p2Time)
        let instrumentChanged = formatTimeForComparison(instrumentTime) != formatTimeForComparison(editing.instrumentTime)
        let simChanged = formatTimeForComparison(simTime) != formatTimeForComparison(editing.simTime)

        return !Calendar.current.isDate(date, inSameDayAs: originalDate) ||
               aircraftType.uppercased() != editing.aircraftType.uppercased() ||
               blockChanged || nightChanged || p1Changed || p1usChanged || p2Changed || instrumentChanged || simChanged ||
               remarks.trimmingCharacters(in: .whitespacesAndNewlines) != editing.remarks.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatTimeForComparison(_ time: String) -> String {
        let value = Double(time) ?? 0.0
        return String(format: "%.1f", value)
    }

    private var canSave: Bool {
        !aircraftType.trimmingCharacters(in: .whitespaces).isEmpty &&
        hasAnyTimeValue
    }

    private var hasAnyTimeValue: Bool {
        let times = [blockTime, nightTime, p1Time, p1usTime, p2Time, instrumentTime, simTime]
        return times.contains { !$0.isEmpty && (Double($0) ?? 0) > 0 }
    }

    // MARK: - Initializers

    init(editingSector: FlightSector? = nil,
         onSave: @escaping (FlightSector) -> Void,
         onDelete: ((FlightSector) -> Void)? = nil) {
        self.editingSector = editingSector
        self.onSave = onSave
        self.onDelete = onDelete
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // Basic Info Card
                        SectionCard(title: "Basic Information", icon: "info.circle.fill", color: .blue) {
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Date")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    DatePicker(
                                        "Summary Date",
                                        selection: $date,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Aircraft Type")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    TextField("e.g. B738", text: $aircraftType)
                                        .textCase(.uppercase)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.body)
                                        .padding(10)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(8)
                                }
                            }
                        }

                        // Flight Times Card
                        SectionCard(title: "Flight Times", icon: "clock.fill", color: .purple) {
                            VStack(spacing: 12) {
                                SummaryTimeField(label: "Total Time", value: $blockTime)
                                SummaryTimeField(label: "Night Time", value: $nightTime)
                                SummaryTimeField(label: "P1 Time", value: $p1Time)
                                SummaryTimeField(label: "P1US Time", value: $p1usTime)
                                SummaryTimeField(label: "P2 Time", value: $p2Time)
                                SummaryTimeField(label: "Instrument Time", value: $instrumentTime)
                                SummaryTimeField(label: "SIM Time", value: $simTime)
                            }
                        }

                        // Remarks Card
                        SectionCard(title: "REMARKS", icon: "note.text", color: .gray) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $remarks)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .scrollContentBackground(.hidden)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)

                                if remarks.isEmpty {
                                    Text("Enter remarks...")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                        }

                        // Delete Button (only in edit mode)
                        if isEditMode {
                            deleteButton
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditMode ? "Edit Summary" : "Add Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasModifications {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "Save" : "Add") {
                        saveEntry()
                    }
                    .disabled(!canSave || (isEditMode && !hasModifications))
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Delete Summary?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete this aircraft summary.")
            }
            .onAppear {
                loadEditingData()
            }
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("Delete")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(10)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func loadEditingData() {
        guard let editing = editingSector, !hasLoadedEditingData else { return }

        // Parse the date string
        if let parsedDate = dateFormatter.date(from: editing.date) {
            date = parsedDate
        }

        aircraftType = editing.aircraftType
        blockTime = editing.blockTimeValue > 0 ? String(format: "%.1f", editing.blockTimeValue) : ""
        nightTime = editing.nightTimeValue > 0 ? String(format: "%.1f", editing.nightTimeValue) : ""
        p1Time = editing.p1TimeValue > 0 ? String(format: "%.1f", editing.p1TimeValue) : ""
        p1usTime = editing.p1usTimeValue > 0 ? String(format: "%.1f", editing.p1usTimeValue) : ""
        p2Time = editing.p2TimeValue > 0 ? String(format: "%.1f", editing.p2TimeValue) : ""
        instrumentTime = editing.instrumentTimeValue > 0 ? String(format: "%.1f", editing.instrumentTimeValue) : ""
        simTime = editing.simTimeValue > 0 ? String(format: "%.1f", editing.simTimeValue) : ""
        remarks = editing.remarks

        hasLoadedEditingData = true
    }

    private func saveEntry() {
        let dateString = dateFormatter.string(from: date)

        // Create a FlightSector entry for the summary
        // Preserve ID if editing, create new if adding
        let summary = FlightSector(
            id: editingSector?.id,
            date: dateString,
            flightNumber: "SUMMARY",
            aircraftReg: "",
            aircraftType: aircraftType.uppercased().trimmingCharacters(in: .whitespaces),
            fromAirport: "",
            toAirport: "",
            captainName: "",
            foName: "",
            blockTime: blockTime.isEmpty ? "0.0" : blockTime,
            nightTime: nightTime.isEmpty ? "0.0" : nightTime,
            p1Time: p1Time.isEmpty ? "0.0" : p1Time,
            p1usTime: p1usTime.isEmpty ? "0.0" : p1usTime,
            p2Time: p2Time.isEmpty ? "0.0" : p2Time,
            instrumentTime: instrumentTime.isEmpty ? "0.0" : instrumentTime,
            simTime: simTime.isEmpty ? "0.0" : simTime,
            isPilotFlying: false,
            isPositioning: false,
            remarks: remarks.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        onSave(summary)
        HapticManager.shared.notification(.success)
        dismiss()
    }

    private func deleteEntry() {
        guard let editing = editingSector else { return }
        onDelete?(editing)
        HapticManager.shared.notification(.warning)
        dismiss()
    }
}

// MARK: - Summary Time Field

private struct SummaryTimeField: View {
    let label: String
    @Binding var value: String

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextField("0.0", text: $value)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .font(.body)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        }
    }
}

// MARK: - Preview

#Preview("Add Mode") {
    AircraftSummarySheet { _ in }
}

#Preview("Edit Mode") {
    AircraftSummarySheet(
        editingSector: FlightSector(
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
            instrumentTime: "125.0",
            simTime: "45.0",
            isPilotFlying: false,
            remarks: "Previous hours from airline XYZ"
        ),
        onSave: { _ in },
        onDelete: { _ in }
    )
}
