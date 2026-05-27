//
//  MacSettingsView.swift
//  Block-Time-Mac
//
//  macOS Settings scene content — tab-based preferences window opened via ⌘,.
//  All values read/write the same UserDefaults keys as the iOS app.
//

import SwiftUI

// MARK: - Tab identifiers

enum MacSettingsTab: String, CaseIterable, Identifiable {
    case crew       = "Crew & Ops"
    case flightInfo = "Flight Info"
    case frms       = "FRMS"
    case appearance = "Appearance"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .crew:       return "person.2.fill"
        case .flightInfo: return "scribble.variable"
        case .frms:       return "clock.badge.exclamationmark"
        case .appearance: return "moonphase.first.quarter"
        }
    }
}

// MARK: - Crew & Ops

struct MacCrewSettingsView: View {
    @AppStorage("flightTimePosition")          private var flightTimePosition: String = "Capt"
    @AppStorage("foPilotFlyingCredit")         private var foPilotFlyingCredit: String = "P1US"
    @AppStorage("defaultCaptainName")          private var defaultCaptainName: String = ""
    @AppStorage("defaultCoPilotName")          private var defaultCoPilotName: String = ""
    @AppStorage("defaultSOName")               private var defaultSOName: String = ""
    @AppStorage("showSONameFields")            private var showSONameFields: Bool = false
    @AppStorage("showSpInsSelector")           private var showSpInsSelector: Bool = false
    @AppStorage("defaultInstructionEnvironment") private var defaultInstructionEnv: String = "simulator"
    @AppStorage("pfAutoInstrumentMinutes")     private var pfAutoInstrumentMinutes: Int = 0
    @AppStorage("logApproaches")              private var logApproaches: Bool = true
    @AppStorage("defaultApproachType")        private var defaultApproachType: String = ""

    var body: some View {
        Form {
            Section("Flight Role") {
                Picker("Log Flight Time As", selection: $flightTimePosition) {
                    Text("Captain").tag("Capt")
                    Text("First Officer").tag("F/O")
                    Text("Second Officer").tag("S/O")
                }

                if flightTimePosition == "F/O" {
                    Picker("Log PF Time As", selection: $foPilotFlyingCredit) {
                        Text("ICUS").tag("P1US")
                        Text("P2").tag("P2")
                    }
                }
            }

            Section("Default Names") {
                switch flightTimePosition {
                case "Capt":
                    TextField("Default Captain Name", text: $defaultCaptainName)
                case "F/O":
                    TextField("Default F/O Name", text: $defaultCoPilotName)
                default:
                    TextField("Default S/O Name", text: $defaultSOName)
                }

                Toggle("Show S/O Name Fields", isOn: $showSONameFields)
            }

            Section("Instructor Time") {
                Toggle("Log Instructor Time", isOn: $showSpInsSelector)

                if showSpInsSelector {
                    Picker("Default Environment", selection: $defaultInstructionEnv) {
                        Text("Simulator").tag("simulator")
                        Text("Aircraft").tag("aircraft")
                    }
                }
            }

            Section("Operations") {
                Picker("Inst Time When PF", selection: $pfAutoInstrumentMinutes) {
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
            }

            Section("Custom Fields") {
                MacCustomFieldsSettingsView()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Custom Fields

private struct MacCustomFieldsSettingsView: View {
    @ObservedObject private var service = MacCustomFieldService.shared
    @State private var showingAdd = false
    @State private var editing: CustomCounterDefinition? = nil

    var body: some View {
        if service.definitions.isEmpty {
            Text("No custom fields defined.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(service.definitions) { definition in
                HStack(spacing: 10) {
                    Image(systemName: iconFor(definition.type))
                        .foregroundStyle(colorFor(definition.type))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(definition.label)
                        Text(definition.type.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { editing = definition }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }
            }
            .onMove { source, dest in service.move(fromOffsets: source, toOffset: dest) }
            .onDelete { offsets in
                for i in offsets {
                    service.remove(columnIndex: service.definitions[i].columnIndex)
                }
            }
        }

        Button("Add Field", systemImage: "plus.circle.fill") { showingAdd = true }
            .foregroundStyle(.blue)
            .sheet(isPresented: $showingAdd) {
                MacFieldEditSheet(mode: .add) { label, type, showTotal in
                    service.add(label: label, type: type, showTotal: showTotal)
                }
            }
            .sheet(item: $editing) { definition in
                MacFieldEditSheet(mode: .edit(definition)) { label, type, showTotal in
                    service.update(columnIndex: definition.columnIndex, label: label, type: type, showTotal: showTotal)
                } onDelete: {
                    service.remove(columnIndex: definition.columnIndex)
                }
            }
    }

    private func iconFor(_ type: CounterType) -> String {
        switch type {
        case .time:    return "clock.fill"
        case .decimal: return "number.circle.fill"
        case .integer: return "number.square.fill"
        case .text:    return "text.alignleft"
        }
    }

    private func colorFor(_ type: CounterType) -> Color {
        switch type {
        case .time:    return .blue
        case .decimal: return .orange
        case .integer: return .teal
        case .text:    return .purple
        }
    }
}

// MARK: - Field Edit Mode

private enum FieldEditMode {
    case add
    case edit(CustomCounterDefinition)
}

// MARK: - Field Edit Sheet

private struct MacFieldEditSheet: View {
    let mode: FieldEditMode
    var onSave: (String, CounterType, Bool) -> Void
    var onDelete: (() -> Void)?

    @State private var label: String
    @State private var type: CounterType
    @State private var showTotal: Bool
    @State private var showingDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    init(mode: FieldEditMode, onSave: @escaping (String, CounterType, Bool) -> Void, onDelete: (() -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
        switch mode {
        case .add:
            _label     = State(initialValue: "")
            _type      = State(initialValue: .integer)
            _showTotal = State(initialValue: true)
        case .edit(let d):
            _label     = State(initialValue: d.label)
            _type      = State(initialValue: d.type)
            _showTotal = State(initialValue: d.showTotal)
        }
    }

    private var title: String {
        if case .add = mode { return "Add Field" }
        return "Edit Field"
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Label") {
                    TextField("Field name", text: $label)
                }

                Section("Data Type") {
                    Picker("Type", selection: $type) {
                        ForEach(CounterType.allCases) { counterType in
                            VStack(alignment: .leading) {
                                Text(counterType.displayName)
                            }
                            .tag(counterType)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: type) { _, newValue in
                        if newValue == .text { showTotal = false }
                    }
                }

                if type != .text {
                    Section("Options") {
                        Toggle("Show Total", isOn: $showTotal)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if case .edit = mode, onDelete != nil {
                    Button("Delete", role: .destructive) { showingDeleteConfirm = true }
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(label.trimmingCharacters(in: .whitespacesAndNewlines), type, showTotal)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 380, height: 460)
        .confirmationDialog("Delete this field?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("This will delete the field and all its data.")
        }
    }
}

// MARK: - Flight Information

struct MacFlightInfoSettingsView: View {
    @AppStorage("useIATACodes")                    private var useIATACodes: Bool = true
    @AppStorage("includeAirlinePrefixInFlightNumber") private var includePrefix: Bool = true
    @AppStorage("airlinePrefix")                   private var airlinePrefix: String = "QF"
    @AppStorage("includeLeadingZeroInFlightNumber") private var leadingZero: Bool = false
    @AppStorage("showFullAircraftReg")             private var showFullReg: Bool = true
    @AppStorage("showTimesInHoursMinutes")          private var timesInHHMM: Bool = true
    @AppStorage("decimalRoundingMode")             private var decimalRounding: String = "Standard"
    @AppStorage("countSimInTotal")                 private var countSimInTotal: Bool = false
    @AppStorage("showOutInTimes")                  private var showOutInTimes: Bool = true
    @AppStorage("enterTimesInLocalTime")           private var enterTimesInLocalTime: Bool = false
    @AppStorage("displayFlightsInLocalTime")       private var displayFlightsInLocalTime: Bool = false
    @AppStorage("selectedFleetID")                 private var selectedFleetID: String = "B737"

    var body: some View {
        Form {
            Section("Airport & Aircraft") {
                Picker("Airport Code Format", selection: $useIATACodes) {
                    Text("ICAO (YBBN)").tag(false)
                    Text("IATA (BNE)").tag(true)
                }

                Toggle("Full A/C Registration (VH-ABC)", isOn: $showFullReg)

                Picker("Fleet", selection: $selectedFleetID) {
                    Text("B737").tag("B737")
                    Text("A320").tag("A320")
                    Text("A330").tag("A330")
                    Text("B787").tag("B787")
                    Text("A380").tag("A380")
                    Text("B747").tag("B747")
                    Text("B767").tag("B767")
                    Text("DHC-8").tag("DHC-8")
                }
            }

            Section("Flight Number") {
                Toggle("Include Airline Prefix", isOn: $includePrefix)

                if includePrefix {
                    HStack {
                        Text("Airline Prefix")
                        Spacer()
                        TextField("e.g. QF", text: $airlinePrefix)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: airlinePrefix) { _, v in
                                airlinePrefix = v.uppercased()
                            }
                    }
                }

                Toggle("Leading Zeros (QF0405)", isOn: $leadingZero)
            }

            Section("Time Display") {
                Picker("Block Times In", selection: $timesInHHMM) {
                    Text("Decimal (1.5)").tag(false)
                    Text("Hrs:Min (1:30)").tag(true)
                }

                if !timesInHHMM {
                    Picker("Decimal Rounding", selection: $decimalRounding) {
                        Text("Standard (03:57 → 4.0)").tag("Standard")
                        Text("Alternate (03:57 → 3.9)").tag("Alternate")
                    }
                }

                Toggle("Show OUT/IN Times in Logbook", isOn: $showOutInTimes)
                Toggle("Count SIM Time in Total", isOn: $countSimInTotal)
            }

            Section("Time Entry") {
                Picker("Times Entered In", selection: $enterTimesInLocalTime) {
                    Text("UTC").tag(false)
                    Text("Local").tag(true)
                }

                Picker("Times Shown In", selection: $displayFlightsInLocalTime) {
                    Text("UTC").tag(false)
                    Text("Local").tag(true)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - FRMS

struct MacFRMSSettingsView: View {
    @State private var fleet: String = "A320/B737"
    @State private var homeBase: String = "SYD"
    @State private var signOnMinutes: Int = 60
    @State private var signOffMinutes: Int = 30

    private let frmsKey = "FRMSConfiguration"

    var body: some View {
        Form {
            Section("Configuration") {
                Picker("Fleet", selection: $fleet) {
                    Text("Shorthaul (A320/B737)").tag("A320/B737")
                    Text("Longhaul (A380/A330/B787)").tag("A380/A330/B787")
                }
                .onChange(of: fleet) { _, _ in save() }

                Picker("Home Base", selection: $homeBase) {
                    Text("SYD").tag("SYD")
                    Text("MEL").tag("MEL")
                    Text("BNE").tag("BNE")
                    Text("ADL").tag("ADL")
                    Text("PER").tag("PER")
                }
                .onChange(of: homeBase) { _, _ in save() }
            }

            Section("Duty Times") {
                Stepper("Sign-on: \(signOnMinutes) min before STD", value: $signOnMinutes, in: 0...120, step: 5)
                    .onChange(of: signOnMinutes) { _, _ in save() }

                Stepper("Sign-off: \(signOffMinutes) min after IN", value: $signOffMinutes, in: 0...120, step: 5)
                    .onChange(of: signOffMinutes) { _, _ in save() }
            }

            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.green)
                        .frame(width: 20)
                        .padding(.top, 1)

                    Text("STD, STA, OUT and IN times are required for accurate FRMS calculations. Flights missing any of these times will have inaccurate duty time data.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { load() }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: frmsKey),
              let config = try? JSONDecoder().decode(FRMSConfigSnapshot.self, from: data) else { return }
        fleet          = config.fleet
        homeBase       = config.homeBase
        signOnMinutes  = config.signOnMinutesBeforeSTD
        signOffMinutes = config.signOffMinutesAfterIN
    }

    private func save() {
        let snapshot = FRMSConfigSnapshot(
            fleet: fleet,
            homeBase: homeBase,
            signOnMinutesBeforeSTD: signOnMinutes,
            signOffMinutesAfterIN: signOffMinutes
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: frmsKey)
        }
    }
}

// Codable snapshot matching the keys FRMSConfiguration uses
struct FRMSConfigSnapshot: Codable {
    var fleet: String
    var homeBase: String
    var signOnMinutesBeforeSTD: Int
    var signOffMinutesAfterIN: Int
}

// MARK: - Appearance

struct MacAppearanceSettingsView: View {
    @AppStorage("macAppearance") private var appearanceRaw: String = "system"

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appearanceRaw) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.inline)
            }
        }
        .formStyle(.grouped)
    }
}
