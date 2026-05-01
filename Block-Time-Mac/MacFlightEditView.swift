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
    @State private var original: MacEditableFlight
    @State private var showingDeleteConfirm = false
    @State private var showingEntryOptions = false
    @State private var saveError: String? = nil

    private var isDirty: Bool {
        switch mode {
        case .add:   return true
        case .edit:  return draft != original
        }
    }

    @AppStorage("enterTimesInLocalTime")  private var enterTimesInLocalTime = false
    @AppStorage("showSpInsSelector")      private var showSpInsSelector = false
    @AppStorage("showSONameFields")       private var showSONameFields = false
    @AppStorage("logApproaches")          private var logApproaches = true
    @AppStorage("logCustomCount")         private var logCustomCount = false
    @AppStorage("customCountLabel")       private var customCountLabel = "Custom"
    @AppStorage("showTimesInHoursMinutes") private var timesInHHMM: Bool = true
    @AppStorage("decimalRoundingMode")    private var decimalRounding: String = "standard"

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        switch mode {
        case .add:        return "New Flight"
        case .edit(let r): return "Edit — \(r.flightNumber.isEmpty ? r.dateDisplay(localTime: false) : r.flightNumber)"
        }
    }

    init(mode: MacFlightEditMode, viewModel: MacLogbookViewModel, onDismiss: @escaping () -> Void) {
        self.mode = mode
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        let hhmm     = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
        let rounding = UserDefaults.standard.string(forKey: "decimalRoundingMode") ?? "standard"
        switch mode {
        case .add:
            let empty = MacEditableFlight.empty()
            _draft    = State(initialValue: empty)
            _original = State(initialValue: empty)
        case .edit(let r):
            let initial = MacEditableFlight(from: r, hhmm: hhmm, rounding: rounding)
            _draft      = State(initialValue: initial)
            _original   = State(initialValue: initial)
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
        .onChange(of: timesInHHMM)    { reformatTimes() }
        .onChange(of: decimalRounding) { reformatTimes() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button {
                showingEntryOptions.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingEntryOptions, arrowEdge: .bottom) {
                EditEntryOptionsPopover()
            }
            Button("Cancel") { onDismiss() }
                .keyboardShortcut(.escape, modifiers: [])
            Button("Save") { commitSave() }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!isDirty)
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
                TextField("Flight No.", text: $draft.flightNumber)
                    .font(.system(.body, design: .monospaced))
                TextField("DEP", text: $draft.fromAirport)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: draft.fromAirport) { _, v in
                        draft.fromAirport = v.uppercased()
                    }
                TextField("ARR", text: $draft.toAirport)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: draft.toAirport) { _, v in
                        draft.toAirport = v.uppercased()
                    }
                TextField("STD", text: $draft.scheduledDeparture)
                    .font(.system(.body, design: .monospaced))
                TextField("STA", text: $draft.scheduledArrival)
                    .font(.system(.body, design: .monospaced))
                TextField("OUT", text: $draft.outTime)
                    .font(.system(.body, design: .monospaced))
                TextField("IN", text: $draft.inTime)
                    .font(.system(.body, design: .monospaced))
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
                TextField("Type", text: $draft.aircraftType)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: draft.aircraftType) { _, v in
                        draft.aircraftType = v.uppercased()
                    }
                TextField("Reg", text: $draft.aircraftReg)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: draft.aircraftReg) { _, v in
                        draft.aircraftReg = v.uppercased()
                    }
            }

            Section("T/O & Ldg") {
                intRow("Day T/O",    value: $draft.dayTakeoffs)
                intRow("Night T/O",  value: $draft.nightTakeoffs)
                intRow("Day Ldg",    value: $draft.dayLandings)
                intRow("Night Ldg",  value: $draft.nightLandings)
            }

            Section("Crew") {
                TextField("Captain", text: $draft.captainName)
                TextField("F/O", text: $draft.foName)
                if showSONameFields {
                    TextField("S/O 1", text: $draft.so1Name)
                    TextField("S/O 2", text: $draft.so2Name)
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
        TextField("Date", text: $draft.date)
            .font(.system(.body, design: .monospaced))
    }

    private func timeRow(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .font(.system(.body, design: .monospaced))
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
        Task {
            let ok: Bool
            switch mode {
            case .add:   ok = await viewModel.saveFlight(draft)
            case .edit:  ok = await viewModel.updateFlight(draft)
            }
            if ok {
                onDismiss()
            } else {
                saveError = "Save failed. Please try again."
            }
        }
    }

    private func commitDelete() {
        guard case .edit(let row) = mode else { return }
        Task {
            _ = await viewModel.deleteFlight(id: row.id)
            onDismiss()
        }
    }

    private func reformatTimes() {
        func reformat(_ s: String) -> String {
            MacFlightRow.formatTime(MacFlightRow.parseTime(s), hhmm: timesInHHMM, rounding: decimalRounding)
        }
        draft.blockTime      = reformat(draft.blockTime)
        draft.nightTime      = reformat(draft.nightTime)
        draft.instrumentTime = reformat(draft.instrumentTime)
        draft.p1Time         = reformat(draft.p1Time)
        draft.p1usTime       = reformat(draft.p1usTime)
        draft.p2Time         = reformat(draft.p2Time)
        draft.simTime        = reformat(draft.simTime)
        draft.spInsTime      = reformat(draft.spInsTime)
        original.blockTime      = reformat(original.blockTime)
        original.nightTime      = reformat(original.nightTime)
        original.instrumentTime = reformat(original.instrumentTime)
        original.p1Time         = reformat(original.p1Time)
        original.p1usTime       = reformat(original.p1usTime)
        original.p2Time         = reformat(original.p2Time)
        original.simTime        = reformat(original.simTime)
        original.spInsTime      = reformat(original.spInsTime)
    }
}

// MARK: - Edit Entry Options Popover

private struct EditEntryOptionsPopover: View {
    @AppStorage("flightTimePosition")            private var flightTimePosition: String = "Captain"
    @AppStorage("foPilotFlyingCredit")           private var foPilotFlyingCredit: String = "P1S"
    @AppStorage("defaultCaptainName")            private var defaultCaptainName: String = ""
    @AppStorage("defaultCoPilotName")            private var defaultCoPilotName: String = ""
    @AppStorage("defaultSOName")                 private var defaultSOName: String = ""
    @AppStorage("showSONameFields")              private var showSONameFields: Bool = false
    @AppStorage("showSpInsSelector")             private var showSpInsSelector: Bool = false
    @AppStorage("defaultInstructionEnvironment") private var defaultInstructionEnv: String = "aircraft"
    @AppStorage("pfAutoInstrumentMinutes")       private var pfAutoInstrumentMinutes: Int = 0
    @AppStorage("logApproaches")                 private var logApproaches: Bool = true
    @AppStorage("defaultApproachType")           private var defaultApproachType: String = ""
    @AppStorage("logCustomCount")                private var logCustomCount: Bool = false
    @AppStorage("customCountLabel")              private var customCountLabel: String = "Custom"
    @AppStorage("enterTimesInLocalTime")         private var enterTimesInLocalTime: Bool = false
    @AppStorage("showFullAircraftReg")           private var showFullAircraftReg: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Entry Options")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            Form {
                Section("Crew Position") {
                    Picker("Log Flight Time As", selection: $flightTimePosition) {
                        Text("Captain").tag("Captain")
                        Text("First Officer").tag("FirstOfficer")
                        Text("Second Officer").tag("SecondOfficer")
                    }
                    if flightTimePosition == "FirstOfficer" {
                        Picker("Log PF Time As", selection: $foPilotFlyingCredit) {
                            Text("ICUS").tag("P1S")
                            Text("P2").tag("P2")
                        }
                    }
                    switch flightTimePosition {
                    case "FirstOfficer":
                        TextField("Default F/O Name", text: $defaultCoPilotName)
                    case "SecondOfficer":
                        TextField("Default S/O Name", text: $defaultSOName)
                    default:
                        TextField("Default Captain Name", text: $defaultCaptainName)
                    }
                    Toggle("Show S/O Name Fields", isOn: $showSONameFields)
                }

                Section("Logging") {
                    Toggle("Log Instructor Time", isOn: $showSpInsSelector)
                    if showSpInsSelector {
                        Picker("Default Environment", selection: $defaultInstructionEnv) {
                            Text("Aircraft").tag("aircraft")
                            Text("Simulator").tag("simulator")
                        }
                    }
                    Picker("Inst. Time When PF", selection: $pfAutoInstrumentMinutes) {
                        Text("None").tag(0)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("60 min").tag(60)
                    }
                    Toggle("Log Approaches", isOn: $logApproaches)
                    if logApproaches {
                        Picker("Default Approach", selection: $defaultApproachType) {
                            Text("None").tag("")
                            Text("ILS").tag("ILS")
                            Text("GLS").tag("GLS")
                            Text("RNP").tag("RNP")
                            Text("AIII").tag("AIII")
                            Text("NPA").tag("NPA")
                        }
                    }
                    Toggle("Custom Counter", isOn: $logCustomCount)
                    if logCustomCount {
                        TextField("Counter Label", text: $customCountLabel)
                    }
                }

                Section("Aircraft") {
                    Toggle("Full Registration (VH-ABC)", isOn: $showFullAircraftReg)
                }

                Section("Times") {
                    Picker("Enter Times In", selection: $enterTimesInLocalTime) {
                        Text("UTC").tag(false)
                        Text("Local").tag(true)
                    }
                    if enterTimesInLocalTime {
                        Text("Local time entry not yet supported on Mac — times will be treated as UTC.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 300)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }
}
