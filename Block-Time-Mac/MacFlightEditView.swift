//
//  MacFlightEditView.swift
//  Block-Time-Mac
//
//  Add / Edit flight panel. Reads UserDefaults settings (same keys as iOS).
//  Local-time conversion is deferred — a banner warns the user if that mode is active.
//

import SwiftUI

// MARK: - Panel mode

enum MacFlightEditMode {
    case add
    case edit(MacFlightRow)
}

// MARK: - Main view

struct MacFlightEditView: View {
    let mode: MacFlightEditMode
    let viewModel: MacLogbookViewModel
    var onDismiss: () -> Void

    @State private var draft: MacEditableFlight
    @State private var showingDeleteConfirm = false
    @State private var saveError: String? = nil

    @AppStorage("enterTimesInLocalTime") private var enterTimesInLocalTime = false
    @AppStorage("showSpInsSelector")     private var showSpInsSelector = false
    @AppStorage("showSONameFields")      private var showSONameFields = false
    @AppStorage("logApproaches")         private var logApproaches = true
    @AppStorage("logCustomCount")        private var logCustomCount = false
    @AppStorage("customCountLabel")      private var customCountLabel = "Custom"

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        switch mode {
        case .add:        return "New Flight"
        case .edit(let r): return "Edit — \(r.flightNumber.isEmpty ? r.dateDisplay : r.flightNumber)"
        }
    }

    init(mode: MacFlightEditMode, viewModel: MacLogbookViewModel, onDismiss: @escaping () -> Void) {
        self.mode = mode
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        switch mode {
        case .add:        _draft = State(initialValue: .empty())
        case .edit(let r): _draft = State(initialValue: MacEditableFlight(from: r))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    if enterTimesInLocalTime {
                        localTimeBanner
                    }
                    formContent
                }
                .padding(.bottom, 16)
            }
            if let err = saveError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .alert("Delete Flight", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) { commitDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this flight. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button("Cancel") { onDismiss() }
                .keyboardShortcut(.escape, modifiers: [])
            Button("Save") { commitSave() }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Local time banner

    private var localTimeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(.orange)
                .font(.caption)
            Text("Times entered in LOCAL time. Airport-based conversion coming soon — enter UTC for now.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Form content

    private var formContent: some View {
        Form {
            Section("Flight Details") {
                dateRow
                LabeledContent("Flight No.") {
                    TextField("QF123", text: $draft.flightNumber)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("DEP") {
                    TextField("MEL", text: $draft.fromAirport)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .textCase(.uppercase)
                        .onChange(of: draft.fromAirport) { _, v in
                            draft.fromAirport = v.uppercased()
                        }
                }
                LabeledContent("ARR") {
                    TextField("SYD", text: $draft.toAirport)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .onChange(of: draft.toAirport) { _, v in
                            draft.toAirport = v.uppercased()
                        }
                }
                LabeledContent("STD") {
                    TextField("0600", text: $draft.scheduledDeparture)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("STA") {
                    TextField("0730", text: $draft.scheduledArrival)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("OUT") {
                    TextField("0610", text: $draft.outTime)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("IN") {
                    TextField("0735", text: $draft.inTime)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Times") {
                timeRow("Block",  text: $draft.blockTime)
                timeRow("Night",  text: $draft.nightTime)
                timeRow("Inst.",  text: $draft.instrumentTime)
                timeRow("P1",     text: $draft.p1Time)
                timeRow("ICUS",   text: $draft.p1usTime)
                timeRow("P2",     text: $draft.p2Time)
                timeRow("Sim",    text: $draft.simTime)
                if showSpInsSelector {
                    timeRow("Sp/Ins", text: $draft.spInsTime)
                }
            }

            Section("Aircraft") {
                LabeledContent("Type") {
                    TextField("B738", text: $draft.aircraftType)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .onChange(of: draft.aircraftType) { _, v in
                            draft.aircraftType = v.uppercased()
                        }
                }
                LabeledContent("Reg") {
                    TextField("VH-XZA", text: $draft.aircraftReg)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .onChange(of: draft.aircraftReg) { _, v in
                            draft.aircraftReg = v.uppercased()
                        }
                }
            }

            Section("T/O & Ldg") {
                intRow("Day T/O",    value: $draft.dayTakeoffs)
                intRow("Night T/O",  value: $draft.nightTakeoffs)
                intRow("Day Ldg",    value: $draft.dayLandings)
                intRow("Night Ldg",  value: $draft.nightLandings)
            }

            Section("Crew") {
                LabeledContent("Captain") {
                    TextField("Name", text: $draft.captainName)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("F/O") {
                    TextField("Name", text: $draft.foName)
                        .multilineTextAlignment(.trailing)
                }
                if showSONameFields {
                    LabeledContent("S/O 1") {
                        TextField("Name", text: $draft.so1Name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("S/O 2") {
                        TextField("Name", text: $draft.so2Name)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section("Flags") {
                Toggle("Pilot Flying", isOn: $draft.isPilotFlying)
                Toggle("Positioning", isOn: $draft.isPositioning)
                if logApproaches {
                    Toggle("ILS",  isOn: $draft.isILS)
                    Toggle("GLS",  isOn: $draft.isGLS)
                    Toggle("NPA",  isOn: $draft.isNPA)
                    Toggle("RNP",  isOn: $draft.isRNP)
                    Toggle("AIII", isOn: $draft.isAIII)
                }
            }

            if logCustomCount {
                Section(customCountLabel) {
                    intRow(customCountLabel, value: $draft.customCount)
                }
            }

            Section("Notes") {
                TextField("Remarks", text: $draft.remarks, axis: .vertical)
                    .lineLimit(3...6)
            }

            if isEditing {
                Section {
                    Button("Delete Flight", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Reusable rows

    private var dateRow: some View {
        LabeledContent("Date") {
            TextField("dd/MM/yyyy", text: $draft.date)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
    }

    private func timeRow(_ label: String, text: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField("0.00", text: text)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
    }

    private func intRow(_ label: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...99) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func commitSave() {
        saveError = nil
        let ok: Bool
        switch mode {
        case .add:   ok = viewModel.saveFlight(draft)
        case .edit:  ok = viewModel.updateFlight(draft)
        }
        if ok {
            onDismiss()
        } else {
            saveError = "Save failed. Please try again."
        }
    }

    private func commitDelete() {
        guard case .edit(let row) = mode else { return }
        _ = viewModel.deleteFlight(id: row.id)
        onDismiss()
    }
}
