//
//  MacFilterPanelView.swift
//  Block-Time-Mac

import SwiftUI
import AppKit

// MARK: - ComboBox

private struct ComboBox: NSViewRepresentable {
    let options: [String]
    @Binding var selection: String
    var uppercases: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.usesDataSource = true
        box.dataSource = context.coordinator
        box.completes = false
        box.numberOfVisibleItems = 8
        box.isEditable = true
        box.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        box.delegate = context.coordinator
        return box
    }

    func updateNSView(_ box: NSComboBox, context: Context) {
        context.coordinator.parent = self
        if box.stringValue != selection {
            box.stringValue = selection
        }
        context.coordinator.filtered = options
        box.reloadData()
    }

    class Coordinator: NSObject, NSComboBoxDelegate, NSComboBoxDataSource {
        var parent: ComboBox
        var filtered: [String] = []

        init(_ parent: ComboBox) {
            self.parent = parent
            self.filtered = parent.options
        }

        // MARK: NSComboBoxDataSource
        func numberOfItems(in box: NSComboBox) -> Int { filtered.count }
        func comboBox(_ box: NSComboBox, objectValueForItemAt index: Int) -> Any? { filtered[index] }

        // MARK: NSComboBoxDelegate
        func controlTextDidChange(_ obj: Notification) {
            guard let box = obj.object as? NSComboBox else { return }
            var typed = box.stringValue
            if parent.uppercases { typed = typed.uppercased() }
            if box.stringValue != typed { box.stringValue = typed }

            if typed.isEmpty {
                filtered = parent.options
            } else {
                filtered = parent.options.filter { $0.localizedCaseInsensitiveContains(typed) }
            }
            box.reloadData()
            parent.selection = typed
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }
            let idx = box.indexOfSelectedItem
            guard idx >= 0, idx < filtered.count else { return }
            let picked = filtered[idx]
            parent.selection = picked
            box.stringValue = picked
        }

        func comboBoxWillDismiss(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }
            parent.selection = box.stringValue
        }
    }
}

// MARK: - Combo Row

private struct FilterComboRow: View {
    let label: String
    let options: [String]
    @Binding var selection: String
    var isActive: Bool
    var uppercases: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            activePip(isActive)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 60, alignment: .leading)
            Spacer()
            HStack(spacing: 4) {
                ComboBox(options: options, selection: $selection, uppercases: uppercases)
                    .frame(width: isActive ? 114 : 130, height: 22)
                if isActive {
                    Button {
                        selection = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func activePip(_ active: Bool) -> some View {
        Circle()
            .fill(active ? Color.blue : Color.clear)
            .frame(width: 5, height: 5)
            .overlay(Circle().stroke(active ? Color.blue : Color.primary.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Date Button Row

private struct DateButtonRow: View {
    let label: String
    @Binding var selection: Date

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.blue)
                .frame(width: 5, height: 5)
                .overlay(Circle().stroke(Color.blue, lineWidth: 0.5))
            Text(label)
                .font(.system(size: 12))
            Spacer()
            DatePicker("", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.stepperField)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Main Panel

struct MacFilterPanelView: View {
    @Bindable var filter: MacFilterState
    let rows: [MacFlightRow]
    var onClose: () -> Void

    private var earliestDate: Date {
        rows.map(\.rawDate).min() ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    }
    private var latestDate: Date {
        rows.map(\.rawDate).max() ?? Date()
    }

    private var aircraftTypes: [String] {
        Array(Set(rows.map(\.aircraftType).filter { !$0.isEmpty })).sorted()
    }
    private var aircraftRegs: [String] {
        Array(Set(rows.map(\.aircraftReg).filter { !$0.isEmpty })).sorted()
    }
    private var captainNames: [String] {
        Array(Set(rows.map(\.captainName).filter { !$0.isEmpty })).sorted()
    }
    private var foNames: [String] {
        Array(Set(rows.map(\.foName).filter { !$0.isEmpty })).sorted()
    }
    private var soNames: [String] {
        let s1 = rows.map(\.so1Name).filter { !$0.isEmpty }
        let s2 = rows.map(\.so2Name).filter { !$0.isEmpty }
        return Array(Set(s1 + s2)).sorted()
    }
    private var flightNumbers: [String] {
        Array(Set(rows.map(\.flightNumber).filter { !$0.isEmpty && $0 != "SUMMARY" })).sorted()
    }
    private var fromAirports: [String] {
        Array(Set(rows.map(\.fromAirport).filter { !$0.isEmpty })).sorted()
    }
    private var toAirports: [String] {
        Array(Set(rows.map(\.toAirport).filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    sortSection
                    dateSection
                    searchSection
                    aircraftSection
                    crewSection
                    flightDetailsSection
                    operationsSection
                    missingDataSection
                }
                .padding(.bottom, 16)
            }
        }
        .background(.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.blue)
            Text("FILTERS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            if filter.isActive {
                Text("\(activeFilterCount)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue, in: Capsule())
            }
            Spacer()
            if filter.isActive {
                Button("CLEAR ALL") { filter.clearFilters() }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(filter.isActive ? Color.blue.opacity(0.4) : Color.primary.opacity(0.1))
                .frame(height: 1)
        }
    }

    private var activeFilterCount: Int {
        var n = 0
        if filter.selectedDateRange != .allFlights    { n += 1 }
        if !filter.filterAircraftType.isEmpty         { n += 1 }
        if !filter.filterAircraftReg.isEmpty          { n += 1 }
        if !filter.filterCaptainName.isEmpty          { n += 1 }
        if !filter.filterFOName.isEmpty               { n += 1 }
        if !filter.filterSOName.isEmpty               { n += 1 }
        if !filter.filterFromAirport.isEmpty          { n += 1 }
        if !filter.filterToAirport.isEmpty            { n += 1 }
        if !filter.filterFlightNumber.isEmpty         { n += 1 }
        if !filter.filterKeywordSearch.isEmpty        { n += 1 }
        if filter.filterPilotFlyingOnly               { n += 1 }
        if filter.filterApproachType != nil           { n += 1 }
        if filter.filterContainsRemarks               { n += 1 }
        if filter.filterSimulator                     { n += 1 }
        if filter.filterPositioning                   { n += 1 }
        if filter.filterSpIns                         { n += 1 }
        if filter.filterTypeSummary                   { n += 1 }
        if filter.filterNoBlockTime                   { n += 1 }
        if filter.filterNoCrewNames                   { n += 1 }
        if filter.filterNoFlightNumber                { n += 1 }
        if filter.filterNoAircraftType                { n += 1 }
        if filter.filterNoAircraftReg                 { n += 1 }
        if filter.sortOrderReversed                   { n += 1 }
        return n
    }

    // MARK: - Sections

    private var sortSection: some View {
        filterGroup("SORT BY") {
            segmentRow(label: "Date Order", isActive: filter.sortOrderReversed) {
                Picker("Date", selection: $filter.sortOrderReversed) {
                    Text("Newest").tag(false)
                    Text("Oldest").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)
            }
        }
    }

    private var dateSection: some View {
        filterGroup("DATE RANGE") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    dateChip("All",    option: .allFlights)
                    dateChip("28d",    option: .twentyEightDays)
                    dateChip("6m",     option: .sixMonths)
                    dateChip("12m",    option: .twelveMonths)
                    dateChip("Custom", option: .custom)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                if filter.selectedDateRange == .custom {
                    filterDivider()
                    compactDateRow("From", selection: $filter.filterStartDate)
                    filterDivider()
                    compactDateRow("To",   selection: $filter.filterEndDate)
                }
            }
        }
    }

    private func dateChip(_ label: String, option: MacDateRangeOption) -> some View {
        let selected = filter.selectedDateRange == option
        return Button {
            if option == .custom && filter.selectedDateRange != .custom {
                filter.filterStartDate = earliestDate
                filter.filterEndDate   = latestDate
            }
            filter.selectedDateRange = option
        } label: {
            Text(label)
                .font(.system(size: 11, weight: selected ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(selected ? Color.blue : Color.primary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private var searchSection: some View {
        filterGroup("SEARCH") {
            HStack(spacing: 8) {
                activePip(!filter.filterKeywordSearch.isEmpty)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Keyword…", text: $filter.filterKeywordSearch)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity)
                if !filter.filterKeywordSearch.isEmpty {
                    Button { filter.filterKeywordSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
    }

    private var aircraftSection: some View {
        filterGroup("AIRCRAFT") {
            FilterComboRow(label: "Type", options: aircraftTypes,
                           selection: $filter.filterAircraftType,
                           isActive: !filter.filterAircraftType.isEmpty)
            filterDivider()
            FilterComboRow(label: "Reg", options: aircraftRegs,
                           selection: $filter.filterAircraftReg,
                           isActive: !filter.filterAircraftReg.isEmpty,
                           uppercases: true)
        }
    }

    private var crewSection: some View {
        filterGroup("CREW") {
            FilterComboRow(label: "Captain", options: captainNames,
                           selection: $filter.filterCaptainName,
                           isActive: !filter.filterCaptainName.isEmpty)
            filterDivider()
            FilterComboRow(label: "F/O", options: foNames,
                           selection: $filter.filterFOName,
                           isActive: !filter.filterFOName.isEmpty)
            filterDivider()
            FilterComboRow(label: "S/O", options: soNames,
                           selection: $filter.filterSOName,
                           isActive: !filter.filterSOName.isEmpty)
        }
    }

    private var flightDetailsSection: some View {
        filterGroup("FLIGHT") {
            FilterComboRow(label: "Flt No", options: flightNumbers,
                           selection: $filter.filterFlightNumber,
                           isActive: !filter.filterFlightNumber.isEmpty)
            filterDivider()
            FilterComboRow(label: "From", options: fromAirports,
                           selection: $filter.filterFromAirport,
                           isActive: !filter.filterFromAirport.isEmpty)
            filterDivider()
            FilterComboRow(label: "To", options: toAirports,
                           selection: $filter.filterToAirport,
                           isActive: !filter.filterToAirport.isEmpty)
        }
    }

    private var operationsSection: some View {
        filterGroup("OPERATIONS") {
            toggleRow("Pilot Flying",      isOn: $filter.filterPilotFlyingOnly)
            filterDivider()
            toggleRow("Has Remarks",       isOn: $filter.filterContainsRemarks)
            filterDivider()
            toggleRow("Simulator",         isOn: $filter.filterSimulator)
            filterDivider()
            toggleRow("PAX / Positioning", isOn: $filter.filterPositioning)
            filterDivider()
            toggleRow("Sp/Ins Instructor", isOn: $filter.filterSpIns)
            filterDivider()
            toggleRow("Summary Rows",      isOn: $filter.filterTypeSummary)
            filterDivider()
            approachRow
        }
    }

    private var missingDataSection: some View {
        filterGroup("MISSING DATA") {
            toggleRow("No Block Time",     isOn: $filter.filterNoBlockTime)
            filterDivider()
            toggleRow("No Crew Names",     isOn: $filter.filterNoCrewNames)
            filterDivider()
            toggleRow("No Flight Number",  isOn: $filter.filterNoFlightNumber)
            filterDivider()
            toggleRow("No Aircraft Type",  isOn: $filter.filterNoAircraftType)
            filterDivider()
            toggleRow("No Registration",   isOn: $filter.filterNoAircraftReg)
        }
    }

    // MARK: - Row Components

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            activePip(isOn.wrappedValue)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(isOn.wrappedValue ? .primary : .secondary)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var approachRow: some View {
        HStack(spacing: 8) {
            activePip(filter.filterApproachType != nil)
            Text("Approach")
                .font(.system(size: 12))
                .foregroundStyle(filter.filterApproachType != nil ? .primary : .secondary)
            Spacer()
            Picker("Approach", selection: $filter.filterApproachType) {
                Text("Any").tag(Optional<String>.none)
                Text("ILS").tag(Optional("ILS"))
                Text("GLS").tag(Optional("GLS"))
                Text("NPA").tag(Optional("NPA"))
                Text("RNP").tag(Optional("RNP"))
                Text("AIII").tag(Optional("AIII"))
            }
            .labelsHidden()
            .font(.system(size: 12))
            .frame(width: 80)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func segmentRow<Content: View>(label: String, isActive: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            activePip(isActive)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? .primary : .secondary)
            Spacer()
            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func compactDateRow(_ label: String, selection: Binding<Date>) -> some View {
        DateButtonRow(label: label, selection: selection)
    }

    // MARK: - Layout Helpers

    @ViewBuilder
    private func filterGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .padding(.horizontal, 8)
        }
    }

    private func filterDivider() -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(height: 0.5)
            .padding(.leading, 26)
    }

    private func activePip(_ active: Bool) -> some View {
        Circle()
            .fill(active ? Color.blue : Color.clear)
            .frame(width: 5, height: 5)
            .overlay(Circle().stroke(active ? Color.blue : Color.primary.opacity(0.2), lineWidth: 0.5))
    }
}
