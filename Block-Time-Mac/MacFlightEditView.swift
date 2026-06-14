//
//  MacFlightEditView.swift
//  Block-Time-Mac
//
//  Add / Edit flight panel. Layout and auto-calculation behaviour mirrors the iOS app.
//

import SwiftUI
import BlockTimeKit

// MARK: - Panel mode

enum MacFlightEditMode {
    case add
    case edit(MacFlightRow)
}

// MARK: - Flight type

private enum MacFlightType {
    case flight, positioning, sim
}

// MARK: - Main view

struct MacFlightEditView: View {
    let mode: MacFlightEditMode
    let viewModel: MacLogbookViewModel
    var onDismiss: () -> Void

    @State private var draft: MacEditableFlight
    @State private var original: MacEditableFlight
    @State private var showingDeleteConfirm = false
    @State private var saveError: String? = nil
    @State private var isSearchingFlight = false
    @State private var flightSearchError: String? = nil
    @State private var flightSegments: [FlightAwareData] = []
    @State private var showingSegmentPicker = false

    // Auto-calc state
    @State private var nightTimeDebounceTask: Task<Void, Never>? = nil
    @State private var hasManuallyEditedTakeoffsLandings = false
    @State private var selectedApproachType: String? = nil

    private let timeCalc = TimeCalculationManager()
    private let nightCalc = NightCalcService()

    @AppStorage("enterTimesInLocalTime")   private var enterTimesInLocalTime = false
    @AppStorage("showSpInsSelector")       private var showSpInsSelector = false
    @AppStorage("showSONameFields")        private var showSONameFields = false
    @AppStorage("logApproaches")           private var logApproaches = true
    @AppStorage("showTimesInHoursMinutes") private var timesInHHMM: Bool = true
    @AppStorage("decimalRoundingMode")     private var decimalRounding: String = "standard"
    @AppStorage("foPilotFlyingCredit")     private var foPilotFlyingCredit: String = "P1US"
    @AppStorage("flightTimePosition")      private var flightTimePosition: String = "Capt"
    @AppStorage("pfAutoInstrumentMinutes") private var pfAutoInstrumentMinutes: Int = 0
    @AppStorage("defaultApproachType")     private var defaultApproachType: String = ""
    @AppStorage("useIATACodes")            private var useIATACodes: Bool = true

    private let crewService = UserDefaultsService()

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isDirty: Bool {
        switch mode {
        case .add:  return true
        case .edit: return draft != original
        }
    }

    private var title: String {
        switch mode {
        case .add:         return "New Flight"
        case .edit(let r): return "Edit — \(r.flightNumber.isEmpty ? r.dateDisplay(localTime: false) : r.flightNumber)"
        }
    }

    init(mode: MacFlightEditMode, viewModel: MacLogbookViewModel, onDismiss: @escaping () -> Void) {
        self.mode      = mode
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
                VStack(spacing: 12) {
                    if enterTimesInLocalTime {
                        localTimeBanner
                    }
                    flightTypeSelector
                    flightInfoSection
                    aircraftSection
                    crewSection
                    timesAndPFSection
                    if showSpInsSelector {
                        spInsSection
                    }
                    customFieldsSection
                    remarksSection
                    if isEditing {
                        deleteSection
                    }
                }
                .padding(12)
            }
            if let err = saveError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            if let err = flightSearchError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .alert("Delete Flight", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) { commitDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete this flight. You can undo this from the Edit menu (⌘Z).")
        }
        .onChange(of: timesInHHMM)     { reformatTimes() }
        .onChange(of: decimalRounding)  { reformatTimes() }
        .onChange(of: draft.outTime)    { scheduleRecalculation() }
        .onChange(of: draft.inTime)     { scheduleRecalculation() }
        .onChange(of: draft.fromAirport) { scheduleRecalculation() }
        .onChange(of: draft.toAirport)   { scheduleRecalculation() }
        .onChange(of: draft.isPilotFlying) { onPilotFlyingChanged() }
        .onChange(of: draft.isPositioning) { onPositioningChanged() }
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Flight type selector (FLT / PAX / SIM)

    private var isSim: Bool { !draft.isPositioning && !draft.simTime.isEmpty }
    private var isFlight: Bool { !draft.isPositioning && draft.simTime.isEmpty }

    private var flightTypeSelector: some View {
        HStack {
            Text("FLIGHT INFO")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 0) {
                typeButton("FLT", color: .blue,    active: isFlight,         action: { setFlightType(.flight) })
                typeButton("PAX", color: .orange,  active: draft.isPositioning, action: { setFlightType(.positioning) })
                typeButton("SIM", color: .purple,  active: isSim,            action: { setFlightType(.sim) })
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        draft.isPositioning ? Color.orange : (isSim ? Color.purple : Color.blue),
                        lineWidth: 2
                    )
            )
        }
    }

    @ViewBuilder
    private func typeButton(_ label: String, color: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(active ? .white : .secondary)
                .frame(width: 50, height: 30)
                .background(active ? color : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Flight Info section

    private var flightInfoSection: some View {
        MacFormCard {
            MacFormRow(label: "DATE") {
                MacDatePickerField(dateString: $draft.date)
            }
            Divider()
            MacFormRow(label: "FLIGHT #") {
                MacFlightNumberTextField(value: $draft.flightNumber)
            }
            Divider()
            MacFormRow(label: "SEARCH") {
                Button {
                    Task { await runFlightSearch() }
                } label: {
                    HStack(spacing: 4) {
                        if isSearchingFlight {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                        }
                        Text(isSearchingFlight ? "Searching…" : "Online Search")
                            .font(.subheadline)
                    }
                    .foregroundStyle(canSearchFlight ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSearchFlight || isSearchingFlight)
                .popover(isPresented: $showingSegmentPicker, arrowEdge: .trailing) {
                    MacFlightSegmentPickerPopover(
                        segments: flightSegments,
                        onSelect: { applyFlightData($0) },
                        onDismiss: { showingSegmentPicker = false }
                    )
                }
            }
            Divider()
            MacFormRow(label: "FROM") {
                TextField(useIATACodes ? "IATA" : "ICAO", text: airportDisplayBinding(icao: $draft.fromAirport))
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.trailing)
            }
            Divider()
            MacFormRow(label: "TO") {
                TextField(useIATACodes ? "IATA" : "ICAO", text: airportDisplayBinding(icao: $draft.toAirport))
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.trailing)
            }
            Divider()
            MacFormRow(label: "STD") {
                MacTimeTextField(value: $draft.scheduledDeparture)
            }
            Divider()
            MacFormRow(label: "STA") {
                MacTimeTextField(value: $draft.scheduledArrival)
            }
        }
    }

    // MARK: - Combined times + PF section

    private var timesAndPFSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(enterTimesInLocalTime ? "FLIGHT TIMES (LOCAL)" : "FLIGHT TIMES (UTC)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            MacFormCard {
                MacFormRow(label: "OUT") {
                    MacTimeTextField(value: $draft.outTime)
                }
                Divider()
                MacFormRow(label: "IN") {
                    MacTimeTextField(value: $draft.inTime)
                }
                Divider()
                MacFormRow(label: "BLOCK") {
                    HStack(spacing: 4) {
                        if blockIsAutoCalculated {
                            Image(systemName: "wand.and.stars")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Auto-calculated")
                        }
                        TextField("0.00", text: $draft.blockTime)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(blockIsAutoCalculated ? .secondary : .primary)
                    }
                }
                Divider()
                MacFormRow(label: "NIGHT") {
                    HStack(spacing: 4) {
                        if nightIsAutoCalculated {
                            Image(systemName: "wand.and.stars")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Auto-calculated")
                        }
                        TextField("0.00", text: $draft.nightTime)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(nightIsAutoCalculated ? .secondary : .primary)
                    }
                }
            }

            // PF / PM toggle + approach picker
            MacFormCard {
                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        pfButton("PF", active: draft.isPilotFlying, color: .green) {
                            draft.isPilotFlying = true
                            if !isEditing && logApproaches && !defaultApproachType.isEmpty {
                                selectedApproachType = defaultApproachType
                                applyApproachType(defaultApproachType)
                            }
                        }
                        pfButton("PM", active: !draft.isPilotFlying, color: .gray) {
                            draft.isPilotFlying = false
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(draft.isPilotFlying ? Color.green : Color.gray, lineWidth: 2)
                    )

                    Spacer()

                    if logApproaches {
                        approachPicker
                    }
                }
                .padding(8)
            }

            // INST, SIM, P1, ICUS, P2 — auto-populated when PF is toggled
            MacFormCard {
                MacFormRow(label: "INST.") {
                    TextField("0.00", text: $draft.instrumentTime)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                if !draft.isPositioning && !draft.simTime.isEmpty {
                    Divider()
                    MacFormRow(label: "SIM") {
                        TextField("0.00", text: $draft.simTime)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                    }
                }
                Divider()
                MacFormRow(label: "P1") {
                    TextField("0.00", text: $draft.p1Time)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                MacFormRow(label: "ICUS") {
                    TextField("0.00", text: $draft.p1usTime)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                MacFormRow(label: "P2") {
                    TextField("0.00", text: $draft.p2Time)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
            }

            // T/O & Ldg — only when PF
            if draft.isPilotFlying {
                Text("T/O & LDG")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                MacFormCard {
                    HStack(spacing: 12) {
                        MacStepperRow(label: "Day T/O",   icon: "airplane.departure", value: $draft.dayTakeoffs,   onChanged: { hasManuallyEditedTakeoffsLandings = true })
                        Divider()
                        MacStepperRow(label: "Day LDG",   icon: "airplane.arrival",   value: $draft.dayLandings,   onChanged: { hasManuallyEditedTakeoffsLandings = true })
                    }
                    Divider()
                    HStack(spacing: 12) {
                        MacStepperRow(label: "Night T/O", icon: "moon.fill",           value: $draft.nightTakeoffs, onChanged: { hasManuallyEditedTakeoffsLandings = true })
                        Divider()
                        MacStepperRow(label: "Night LDG", icon: "moon.stars.fill",     value: $draft.nightLandings, onChanged: { hasManuallyEditedTakeoffsLandings = true })
                    }
                }
            }
        }
    }

    private var blockIsAutoCalculated: Bool {
        !draft.outTime.isEmpty && !draft.inTime.isEmpty &&
        timeCalc.isValidTimeHHmm(draft.outTime) && timeCalc.isValidTimeHHmm(draft.inTime)
    }

    private var nightIsAutoCalculated: Bool {
        blockIsAutoCalculated && !draft.fromAirport.isEmpty && !draft.toAirport.isEmpty
    }

    @ViewBuilder
    private func pfButton(_ label: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(active ? .white : .secondary)
                .frame(width: 55, height: 30)
                .background(active ? color : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Approach picker

    private var approachPicker: some View {
        HStack(spacing: 6) {
            Text("APP")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Menu {
                Button("NIL") { clearApproach() }
                Divider()
                ForEach(["ILS", "GLS", "RNP", "AIII", "NPA"], id: \.self) { type in
                    Button(type) { applyApproachType(type); selectedApproachType = type }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedApproachType ?? "NIL")
                        .font(.footnote.bold())
                        .foregroundStyle(selectedApproachType != nil ? .white : .secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(selectedApproachType != nil ? .white : .secondary)
                }
                .frame(width: 64, height: 28)
                .background(selectedApproachType != nil ? Color.orange.opacity(0.8) : Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!draft.isPilotFlying)
            .opacity(draft.isPilotFlying ? 1 : 0.5)
        }
    }

    // MARK: - Aircraft section

    private var aircraftSection: some View {
        MacFormCard {
            MacFormRow(label: "TYPE") {
                TextField("", text: $draft.aircraftType)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.aircraftType) { _, v in draft.aircraftType = v.uppercased() }
            }
            Divider()
            MacAircraftRegPickerRow(registration: $draft.aircraftReg, aircraftType: $draft.aircraftType, viewModel: viewModel)
        }
    }

    // MARK: - Crew section

    private var crewSection: some View {
        MacFormCard {
            MacCrewNamePickerRow(
                label: "CAPTAIN",
                name: $draft.captainName,
                savedNames: crewService.loadSettings().savedCaptainNames,
                onSave: { _ = crewService.addCaptainName($0) }
            )
            Divider()
            MacCrewNamePickerRow(
                label: "F/O",
                name: $draft.foName,
                savedNames: crewService.loadSettings().savedCoPilotNames,
                onSave: { _ = crewService.addCoPilotName($0) }
            )
            if showSONameFields {
                Divider()
                MacCrewNamePickerRow(
                    label: "S/O 1",
                    name: $draft.so1Name,
                    savedNames: crewService.loadSettings().savedSONames,
                    onSave: { _ = crewService.addSOName($0) }
                )
                Divider()
                MacCrewNamePickerRow(
                    label: "S/O 2",
                    name: $draft.so2Name,
                    savedNames: crewService.loadSettings().savedSONames,
                    onSave: { _ = crewService.addSOName($0) }
                )
            }
        }
    }

    // MARK: - Sp/Ins section

    private var spInsSection: some View {
        MacFormCard {
            MacFormRow(label: "SP/INS") {
                TextField("0.00", text: $draft.spInsTime)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Custom fields section

    @ViewBuilder
    private var customFieldsSection: some View {
        let defs = CustomCounterService.shared.definitions.sorted { $0.columnIndex < $1.columnIndex }
        if !defs.isEmpty {
            MacFormCard {
                ForEach(Array(defs.enumerated()), id: \.element.id) { idx, def in
                    if idx > 0 { Divider() }
                    MacFormRow(label: def.label.uppercased()) {
                        switch def.type {
                        case .integer:
                            let binding = intBinding(for: def.columnIndex)
                            Stepper("\(binding.wrappedValue)", value: binding, in: 0...99)
                                .labelsHidden()
                        default:
                            TextField("", text: counterBinding(for: def.columnIndex))
                                .font(.system(.body, design: .monospaced))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Remarks section

    private var remarksSection: some View {
        MacFormCard {
            MacFormRow(label: "REMARKS") {
                TextField("", text: $draft.remarks, axis: .vertical)
                    .lineLimit(3...6)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Delete section

    private var deleteSection: some View {
        Button("Delete Flight", role: .destructive) {
            showingDeleteConfirm = true
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Auto-calculation

    private func scheduleRecalculation() {
        guard !draft.isPositioning else { return }
        nightTimeDebounceTask?.cancel()
        nightTimeDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            recalculateNow()
        }
    }

    @MainActor
    private func recalculateNow() {
        let out = draft.outTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let inT = draft.inTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard timeCalc.isValidTimeHHmm(out), timeCalc.isValidTimeHHmm(inT) else { return }

        let blockTimeStr = timeCalc.calculateFlightTime(outTime: out, inTime: inT)
        draft.blockTime = MacFlightRow.formatTime(MacFlightRow.parseTime(blockTimeStr), hhmm: timesInHHMM, rounding: decimalRounding)

        if let context = timeCalc.buildCalculationContext(
            fromAirport: draft.fromAirport,
            toAirport: draft.toAirport,
            outTime: out,
            blockTime: blockTimeStr,
            flightDate: draft.date
        ) {
            let night = timeCalc.calculateNightTime(using: context)
            draft.nightTime = MacFlightRow.formatTime(MacFlightRow.parseTime(night), hhmm: timesInHHMM, rounding: decimalRounding)

            if draft.isPilotFlying && !hasManuallyEditedTakeoffsLandings {
                let isDepartureNight = nightCalc.isNight(
                    at: context.fromCoordinates.latitude,
                    lon: context.fromCoordinates.longitude,
                    time: context.departureTime
                )
                let isArrivalNight = nightCalc.isNight(
                    at: context.toCoordinates.latitude,
                    lon: context.toCoordinates.longitude,
                    time: context.arrivalTime
                )
                draft.dayTakeoffs   = isDepartureNight ? 0 : 1
                draft.nightTakeoffs = isDepartureNight ? 1 : 0
                draft.dayLandings   = isArrivalNight   ? 0 : 1
                draft.nightLandings = isArrivalNight   ? 1 : 0
            }
        }
    }

    private func onPilotFlyingChanged() {
        if draft.isPilotFlying {
            if !hasManuallyEditedTakeoffsLandings {
                scheduleRecalculation()
            }
            autoFillTimesForPF()
        } else {
            // Clear approaches, T/O & Ldg, and auto-filled times when switching to PM
            clearApproach()
            if !hasManuallyEditedTakeoffsLandings {
                draft.dayTakeoffs   = 0
                draft.nightTakeoffs = 0
                draft.dayLandings   = 0
                draft.nightLandings = 0
            }
            clearAutoFilledTimes()
        }
    }

    private func autoFillTimesForPF() {
        guard !isEditing else { return }
        let blockVal = MacFlightRow.parseTime(draft.blockTime)

        // INST: pfAutoInstrumentMinutes / 60, only when PF and not sim
        if pfAutoInstrumentMinutes > 0 {
            let instHours = Double(pfAutoInstrumentMinutes) / 60.0
            draft.instrumentTime = MacFlightRow.formatTime(instHours, hhmm: timesInHHMM, rounding: decimalRounding)
        }

        // P1/ICUS/P2 based on position setting — mirrors iOS selectedTimeCredit logic
        switch flightTimePosition {
        case "Capt":
            // Captain always gets P1
            draft.p1Time   = MacFlightRow.formatTime(blockVal, hhmm: timesInHHMM, rounding: decimalRounding)
            draft.p1usTime = MacFlightRow.formatTime(0, hhmm: timesInHHMM, rounding: decimalRounding)
            draft.p2Time   = MacFlightRow.formatTime(0, hhmm: timesInHHMM, rounding: decimalRounding)
        case "F/O":
            // F/O PF: use foPilotFlyingCredit setting (P1US = ICUS, or P2)
            if foPilotFlyingCredit == "P1US" {
                draft.p1Time   = MacFlightRow.formatTime(0, hhmm: timesInHHMM, rounding: decimalRounding)
                draft.p1usTime = MacFlightRow.formatTime(blockVal, hhmm: timesInHHMM, rounding: decimalRounding)
                draft.p2Time   = MacFlightRow.formatTime(0, hhmm: timesInHHMM, rounding: decimalRounding)
            } else {
                draft.p1Time   = MacFlightRow.formatTime(0, hhmm: timesInHHMM, rounding: decimalRounding)
                draft.p1usTime = MacFlightRow.formatTime(0, hhmm: timesInHHMM, rounding: decimalRounding)
                draft.p2Time   = MacFlightRow.formatTime(blockVal, hhmm: timesInHHMM, rounding: decimalRounding)
            }
        default:
            // S/O or unknown — no time credit auto-fill
            break
        }
    }

    private func clearAutoFilledTimes() {
        guard !isEditing else { return }
        let zero = MacFlightRow.formatTime(0, hhmm: timesInHHMM, rounding: decimalRounding)
        draft.instrumentTime = zero
        draft.p1Time         = zero
        draft.p1usTime       = zero
        draft.p2Time         = zero
    }

    private func onPositioningChanged() {
        if draft.isPositioning {
            draft.blockTime  = ""
            draft.nightTime  = ""
            draft.isPilotFlying = false
            clearApproach()
        }
    }

    private func setFlightType(_ type: MacFlightType) {
        switch type {
        case .flight:
            draft.isPositioning = false
            draft.simTime = ""
        case .positioning:
            draft.isPositioning = true
            draft.simTime = ""
        case .sim:
            draft.isPositioning = false
            if draft.simTime.isEmpty { draft.simTime = draft.blockTime }
        }
    }

    // MARK: - Approach helpers

    private func applyApproachType(_ type: String) {
        draft.isILS  = (type == "ILS")
        draft.isGLS  = (type == "GLS")
        draft.isNPA  = (type == "NPA")
        draft.isRNP  = (type == "RNP")
        draft.isAIII = (type == "AIII")
    }

    private func clearApproach() {
        selectedApproachType = nil
        draft.isILS  = false
        draft.isGLS  = false
        draft.isNPA  = false
        draft.isRNP  = false
        draft.isAIII = false
    }

    // MARK: - Bindings

    /// Shows the stored ICAO in the user's preferred format (IATA or ICAO).
    /// Converts back to ICAO on set so the draft always stores ICAO internally.
    private func airportDisplayBinding(icao: Binding<String>) -> Binding<String> {
        Binding(
            get: { AirportService.shared.getDisplayCode(icao.wrappedValue, useIATA: useIATACodes) },
            set: { icao.wrappedValue = AirportService.shared.convertToICAO($0) }
        )
    }

    private func counterBinding(for idx: Int) -> Binding<String> {
        Binding(
            get: { draft.counterValue(idx) },
            set: { draft.setCounter(idx, value: $0) }
        )
    }

    private func intBinding(for idx: Int) -> Binding<Int> {
        Binding(
            get: { Int(draft.counterValue(idx)) ?? 0 },
            set: { draft.setCounter(idx, value: $0 > 0 ? "\($0)" : "") }
        )
    }

    // MARK: - Online Search

    private var canSearchFlight: Bool {
        !draft.flightNumber.isEmpty && !draft.date.isEmpty
    }

    private func runFlightSearch() async {
        flightSearchError = nil
        isSearchingFlight = true
        let result = await viewModel.searchFlight(
            flightNumber: draft.flightNumber,
            date: draft.date,
            airlinePrefix: UserDefaults.standard.string(forKey: "airlinePrefix") ?? "QF",
            includePrefix: UserDefaults.standard.bool(forKey: "includeAirlinePrefixInFlightNumber")
        )
        isSearchingFlight = false
        switch result {
        case .single(let data):
            applyFlightData(data)
        case .multiple(let segments):
            flightSegments = segments
            showingSegmentPicker = true
        case .error(let msg):
            flightSearchError = msg
        }
    }

    private func applyFlightData(_ data: FlightAwareData) {
        showingSegmentPicker = false
        flightSearchError = nil

        draft.fromAirport = data.origin
        draft.toAirport = data.destination
        draft.outTime = data.departureTime
        draft.inTime = data.arrivalTime

        if let std = data.scheduledDepartureTime { draft.scheduledDeparture = std }
        if let sta = data.scheduledArrivalTime { draft.scheduledArrival = sta }

        if let reg = data.aircraftRegistration, !reg.isEmpty {
            let showFullReg = UserDefaults.standard.bool(forKey: "showFullAircraftReg")
            let formatted: String
            if showFullReg {
                formatted = reg
            } else if let dash = reg.firstIndex(of: "-") {
                formatted = String(reg[reg.index(after: dash)...])
            } else {
                formatted = reg
            }
            draft.aircraftReg = formatted
        }

        scheduleRecalculation()
    }

    // MARK: - Actions

    private func commitSave() {
        saveError = nil
        // Trigger a final recalculation before saving (mirrors iOS onSave)
        if !draft.isPositioning {
            let times = timeCalc.recalculateTimes(
                outTime: draft.outTime, inTime: draft.inTime,
                fromAirport: draft.fromAirport, toAirport: draft.toAirport,
                flightDate: draft.date,
                isEditingMode: isEditing,
                existingNightTime: draft.nightTime
            )
            if !times.blockTime.isEmpty {
                draft.blockTime = MacFlightRow.formatTime(MacFlightRow.parseTime(times.blockTime), hhmm: timesInHHMM, rounding: decimalRounding)
                draft.nightTime = MacFlightRow.formatTime(MacFlightRow.parseTime(times.nightTime), hhmm: timesInHHMM, rounding: decimalRounding)
            }
        }
        Task {
            let ok: Bool
            switch mode {
            case .add:  ok = await viewModel.saveFlight(draft)
            case .edit: ok = await viewModel.updateFlight(draft)
            }
            if ok { onDismiss() } else { saveError = "Save failed. Please try again." }
        }
    }

    private func commitDelete() {
        guard case .edit(let row) = mode else { return }
        let undoManager = NSApp.keyWindow?.undoManager
        Task {
            _ = await viewModel.deleteFlight(id: row.id, undoManager: undoManager)
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

// MARK: - MacFormCard

struct MacFormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - MacFormRow

struct MacFormRow<Trailing: View>: View {
    let label: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Spacer()
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

// MARK: - MacStepperRow

struct MacStepperRow: View {
    let label: String
    let icon: String
    @Binding var value: Int
    var onChanged: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Stepper(value: $value, in: 0...99) {
                Text("\(value)")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 24, alignment: .trailing)
            }
            .onChange(of: value) { onChanged() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

// MARK: - MacDatePickerField

struct MacDatePickerField: View {
    @Binding var dateString: String

    private static let storageFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_AU")
        return f
    }()

    @State private var selectedDate: Date

    init(dateString: Binding<String>) {
        _dateString = dateString
        let initial = Self.storageFormatter.date(from: dateString.wrappedValue) ?? Date()
        _selectedDate = State(initialValue: initial)
    }

    var body: some View {
        DatePicker(
            "",
            selection: $selectedDate,
            displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .environment(\.locale, Locale(identifier: "en_AU"))
        .environment(\.timeZone, .gmt)
        .onChange(of: selectedDate) { _, newDate in
            dateString = Self.storageFormatter.string(from: newDate)
        }
        .onChange(of: dateString) { _, newString in
            if let date = Self.storageFormatter.date(from: newString) {
                selectedDate = date
            }
        }
    }
}

// MARK: - MacFlightNumberTextField

/// Flight number field that mirrors iOS formatting on blur:
/// prepends the airline prefix if enabled, and applies/strips leading zeros per settings.
struct MacFlightNumberTextField: View {
    @Binding var value: String
    @FocusState private var isFocused: Bool

    @AppStorage("includeAirlinePrefixInFlightNumber") private var includePrefix: Bool = true
    @AppStorage("airlinePrefix")                      private var airlinePrefix: String = "QF"
    @AppStorage("includeLeadingZeroInFlightNumber")   private var includeLeadingZero: Bool = false

    private var placeholder: String {
        let number = includeLeadingZero ? "0430" : "430"
        return includePrefix ? "\(airlinePrefix)\(number)" : number
    }

    var body: some View {
        TextField(placeholder, text: $value)
            .font(.system(.body, design: .monospaced))
            .multilineTextAlignment(.trailing)
            .onChange(of: value) { _, v in
                value = v.uppercased()
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    value = formatFlightNumber(value)
                }
            }
            .focused($isFocused)
    }

    private func formatFlightNumber(_ input: String) -> String {
        guard !input.isEmpty else { return input }
        var formatted = input

        if includePrefix && !formatted.hasPrefix(airlinePrefix) {
            formatted = airlinePrefix + formatted
        }

        if formatted.hasPrefix(airlinePrefix) {
            let numeric = String(formatted.dropFirst(airlinePrefix.count))
            let adjusted = includeLeadingZero ? padToFourDigits(numeric) : stripLeadingZeros(numeric)
            return airlinePrefix + adjusted
        } else {
            return includeLeadingZero ? padToFourDigits(formatted) : stripLeadingZeros(formatted)
        }
    }

    private func padToFourDigits(_ number: String) -> String {
        let numericPrefix = number.prefix(while: { $0.isNumber })
        let suffix = String(number.dropFirst(numericPrefix.count))
        guard !numericPrefix.isEmpty else { return number }
        let stripped = String(numericPrefix.drop(while: { $0 == "0" }))
        let core = stripped.isEmpty ? "0" : stripped
        let padded = String(repeating: "0", count: max(0, 4 - core.count)) + core
        return padded + suffix
    }

    private func stripLeadingZeros(_ number: String) -> String {
        let numericPrefix = number.prefix(while: { $0.isNumber })
        let suffix = String(number.dropFirst(numericPrefix.count))
        guard !numericPrefix.isEmpty else { return number }
        let stripped = numericPrefix.drop(while: { $0 == "0" })
        let result = stripped.isEmpty ? String(numericPrefix.last!) : String(stripped)
        return result + suffix
    }
}

// MARK: - MacTimeTextField

/// HH:MM time entry field with auto-formatting: typing "2300" becomes "23:00" on the
/// fourth digit, and leading zeros are padded on blur. Mirrors iOS ModernTimeField logic.
struct MacTimeTextField: View {
    @Binding var value: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("HH:MM", text: $value)
            .font(.system(.body, design: .monospaced))
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .onChange(of: value) { _, newValue in
                value = Self.applyFormatting(newValue)
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    value = Self.formatWithLeadingZeros(value)
                }
            }
    }

    private static func applyFormatting(_ input: String) -> String {
        let filtered = input.filter { $0.isNumber || $0 == ":" }
        if filtered.count == 4 && !filtered.contains(":") {
            return "\(filtered.prefix(2)):\(filtered.suffix(2))"
        }
        return String(filtered.prefix(5))
    }

    private static func formatWithLeadingZeros(_ input: String) -> String {
        guard input.contains(":") else { return input }
        let parts = input.split(separator: ":", maxSplits: 1)
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h < 24, m < 60 else { return input }
        return String(format: "%02d:%02d", h, m)
    }
}
