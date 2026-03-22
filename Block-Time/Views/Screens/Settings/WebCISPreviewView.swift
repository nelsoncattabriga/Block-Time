//
//  WebCISPreviewView.swift
//  Block-Time
//
//  Created by Nelson on 22/03/2026.
//

import SwiftUI

// MARK: - ViewModel

@Observable @MainActor
final class WebCISPreviewViewModel {

    // MARK: Column indices (webCIS fixed schema)
    private enum Col {
        static let date   = 0
        static let reg    = 1
        static let dep    = 2
        static let des    = 3
        static let inst   = 4
        static let p2d    = 5
        static let p2n    = 6
        static let p1d    = 7
        static let p1n    = 8
        static let p1usd  = 9
        static let p1usn  = 10
        static let medd   = 11
        static let medn   = 12
        static let mefd   = 13
        static let mefn   = 14
        static let mecd   = 15
        static let mecn   = 16
        static let simu   = 17
        static let flen   = 18
        static let total  = 19
        static let spins  = 20
    }

    // MARK: State
    let importData: ImportData
    var selectedRowIndices: Set<Int>
    var duplicateRowIndices: Set<Int> = []   // placeholder for future duplicate detection

    init(importData: ImportData) {
        self.importData = importData
        self.selectedRowIndices = Set(importData.rows.indices)
    }

    // MARK: - Selection helpers

    var selectedCount: Int { selectedRowIndices.count }
    var totalCount: Int { importData.rows.count }

    var allSelected: Bool { selectedRowIndices.count == importData.rows.count }

    func toggleRow(_ index: Int) {
        if selectedRowIndices.contains(index) {
            selectedRowIndices.remove(index)
        } else {
            selectedRowIndices.insert(index)
        }
    }

    func selectAll() {
        selectedRowIndices = Set(importData.rows.indices)
    }

    func deselectAll() {
        selectedRowIndices = []
    }

    /// Returns a new ImportData containing only the selected rows.
    var filteredImportData: ImportData {
        let selectedRows = importData.rows.indices
            .filter { selectedRowIndices.contains($0) }
            .map { importData.rows[$0] }
        return ImportData(
            headers: importData.headers,
            rows: selectedRows,
            fileURL: importData.fileURL,
            delimiter: importData.delimiter
        )
    }

    // MARK: - Row classification

    func isSimRow(_ row: [String]) -> Bool {
        let dep = field(row, Col.dep)
        let des = field(row, Col.des)
        let simu = field(row, Col.simu)
        let total = field(row, Col.total)
        let isDep = !dep.isEmpty
        let isDes = !des.isEmpty
        let hasSim = !simu.isEmpty
        // A sim row: no dep/des and has sim time, OR dep/des empty and total == simu
        return (!isDep && !isDes && hasSim) ||
               (!isDep && !isDes && (total.isEmpty || total == simu))
    }

    // MARK: - Suspicious rows

    var suspiciousRowCount: Int {
        importData.rows.enumerated().filter { (index, row) in
            selectedRowIndices.contains(index) &&
            field(row, Col.total).isEmpty &&
            field(row, Col.simu).isEmpty
        }.count
    }

    // MARK: - Summary totals (selected rows only)

    var totalBlock: String {
        sumTimes(selectedRows.map { field($0, Col.total) })
    }

    var totalNight: String {
        sumTimes(selectedRows.flatMap { row in
            [Col.p2n, Col.p1n, Col.p1usn, Col.medn, Col.mefn, Col.mecn].map { field(row, $0) }
        })
    }

    var totalP1: String {
        sumTimes(selectedRows.flatMap { row in
            [Col.p1d, Col.p1n, Col.mecd, Col.mecn].map { field(row, $0) }
        })
    }

    var totalICUS: String {
        sumTimes(selectedRows.flatMap { row in
            [Col.p1usd, Col.p1usn].map { field(row, $0) }
        })
    }

    var totalP2: String {
        sumTimes(selectedRows.flatMap { row in
            [Col.p2d, Col.p2n, Col.medd, Col.medn, Col.mefd, Col.mefn].map { field(row, $0) }
        })
    }

    var totalSim: String {
        sumTimes(selectedRows.map { field($0, Col.simu) })
    }

    var totalInst: String {
        sumTimes(selectedRows.map { field($0, Col.inst) })
    }

    // MARK: - Per-row computed values

    func rowDate(_ row: [String]) -> String { field(row, Col.date) }
    func rowReg(_ row: [String]) -> String { field(row, Col.reg) }

    func rowSector(_ row: [String]) -> String {
        guard !isSimRow(row) else { return "SIM" }
        let dep = field(row, Col.dep)
        let des = field(row, Col.des)
        if dep.isEmpty && des.isEmpty { return "—" }
        return "\(dep)-\(des)"
    }

    func rowTotal(_ row: [String]) -> String { display(field(row, Col.total)) }
    func rowSim(_ row: [String]) -> String   { display(field(row, Col.simu)) }
    func rowInst(_ row: [String]) -> String  { display(field(row, Col.inst)) }

    func rowNight(_ row: [String]) -> String {
        display(sumTimes([Col.p2n, Col.p1n, Col.p1usn, Col.medn, Col.mefn, Col.mecn].map { field(row, $0) }))
    }

    func rowP1(_ row: [String]) -> String {
        display(sumTimes([Col.p1d, Col.p1n, Col.mecd, Col.mecn].map { field(row, $0) }))
    }

    func rowICUS(_ row: [String]) -> String {
        display(sumTimes([Col.p1usd, Col.p1usn].map { field(row, $0) }))
    }

    func rowP2(_ row: [String]) -> String {
        display(sumTimes([Col.p2d, Col.p2n, Col.medd, Col.medn, Col.mefd, Col.mefn].map { field(row, $0) }))
    }

    // MARK: - Time arithmetic

    /// Sums a collection of "HH:MM" strings, returning "HH:MM". Returns "—" if total is zero.
    func sumTimes(_ times: [String]) -> String {
        var totalMinutes = 0
        for t in times {
            let trimmed = t.trimmingCharacters(in: .whitespaces)
            guard (trimmed.count == 4 || trimmed.count == 5), trimmed.contains(":") else { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let h = Int(parts[0]),
                  let m = Int(parts[1]) else { continue }
            totalMinutes += h * 60 + m
        }
        if totalMinutes == 0 { return "—" }
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    // MARK: - Private helpers

    private var selectedRows: [[String]] {
        importData.rows.indices
            .filter { selectedRowIndices.contains($0) }
            .map { importData.rows[$0] }
    }

    private func field(_ row: [String], _ index: Int) -> String {
        guard index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespaces)
    }

    private func display(_ value: String) -> String {
        value.isEmpty || value == "—" ? "—" : value
    }
}

// MARK: - Main View

struct WebCISPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WebCISPreviewViewModel
    let onConfirm: (ImportData) -> Void

    // Fixed column widths
    private enum ColWidth {
        static let checkbox: CGFloat = 36
        static let date:     CGFloat = 90
        static let reg:      CGFloat = 64
        static let sector:   CGFloat = 80
        static let total:    CGFloat = 56
        static let night:    CGFloat = 56
        static let p1:       CGFloat = 56
        static let icus:     CGFloat = 56
        static let p2:       CGFloat = 56
        static let sim:      CGFloat = 56
        static let inst:     CGFloat = 56

        static var tableWidth: CGFloat {
            checkbox + date + reg + sector + total + night + p1 + icus + p2 + sim + inst
        }
    }

    init(importData: ImportData, onConfirm: @escaping (ImportData) -> Void) {
        self._viewModel = State(initialValue: WebCISPreviewViewModel(importData: importData))
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryStrip
                warningBanner
                Divider()
                tableBody
                Divider()
                bottomToolbar
            }
            .navigationTitle("Review webCIS Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
        }
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        VStack(spacing: 4) {
            Text("\(viewModel.selectedCount) of \(viewModel.totalCount) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    statChip(label: "Block",  value: viewModel.totalBlock)
                    statChip(label: "Night",  value: viewModel.totalNight)
                    statChip(label: "P1",     value: viewModel.totalP1)
                    statChip(label: "ICUS",   value: viewModel.totalICUS)
                    statChip(label: "P2",     value: viewModel.totalP2)
                    statChip(label: "Sim",    value: viewModel.totalSim)
                    statChip(label: "Inst",   value: viewModel.totalInst)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    private func statChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Warning banner

    @ViewBuilder
    private var warningBanner: some View {
        let suspicious = viewModel.suspiciousRowCount
        let noneSelected = viewModel.selectedCount == 0

        if noneSelected || suspicious > 0 {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)

                if noneSelected {
                    Text("No rows selected — select at least one row to import.")
                        .font(.caption)
                        .foregroundStyle(.primary)
                } else {
                    Text("\(suspicious) selected row\(suspicious == 1 ? "" : "s") have no flight or sim time — they may be header or summary rows.")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.15))
        }
    }

    // MARK: - Column header row

    private var headerHStack: some View {
        HStack(spacing: 0) {
            // Checkbox column header
            Image(systemName: "checkmark.square")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: ColWidth.checkbox, alignment: .center)

            columnHeader("Date",  width: ColWidth.date,   align: .leading)
            columnHeader("Reg",   width: ColWidth.reg,    align: .leading)
            columnHeader("Sector",width: ColWidth.sector, align: .leading)
            columnHeader("Total", width: ColWidth.total)
            columnHeader("Night", width: ColWidth.night)
            columnHeader("P1",    width: ColWidth.p1)
            columnHeader("ICUS",  width: ColWidth.icus)
            columnHeader("P2",    width: ColWidth.p2)
            columnHeader("Sim",   width: ColWidth.sim)
            columnHeader("Inst",  width: ColWidth.inst)
        }
    }

    private func columnHeader(_ title: String, width: CGFloat, align: Alignment = .trailing) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: align)
            .padding(.horizontal, 2)
    }

    // MARK: - Table body

    private var tableBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(viewModel.importData.rows.enumerated()), id: \.offset) { index, row in
                            tableRow(index: index, row: row)
                            Divider()
                        }
                    } header: {
                        headerHStack
                            .frame(height: 30)
                            .background(Color.secondary.opacity(0.12))
                            .padding(.horizontal, 4)
                        Divider()
                    }
                }
                .frame(minWidth: ColWidth.tableWidth)
                .padding(.horizontal, 4)
            }
        }
    }

    private func tableRow(index: Int, row: [String]) -> some View {
        let isSelected = viewModel.selectedRowIndices.contains(index)
        let isSim = viewModel.isSimRow(row)

        return Button {
            viewModel.toggleRow(index)
        } label: {
            rowContent(index: index, row: row, isSelected: isSelected, isSim: isSim)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func rowContent(index: Int, row: [String], isSelected: Bool, isSim: Bool) -> some View {
        let dimmed = !isSelected

        return HStack(spacing: 0) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.caption)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: ColWidth.checkbox, alignment: .center)

            // Date
            Text(viewModel.rowDate(row))
                .frame(width: ColWidth.date, alignment: .leading)
                .padding(.horizontal, 2)

            // Reg
            Text(isSim ? "SIM" : viewModel.rowReg(row))
                .frame(width: ColWidth.reg, alignment: .leading)
                .padding(.horizontal, 2)

            // Sector
            sectorCell(row: row, isSim: isSim)
                .frame(width: ColWidth.sector, alignment: .leading)
                .padding(.horizontal, 2)

            // Numeric columns — right-aligned
            numericCell(viewModel.rowTotal(row), width: ColWidth.total, highlight: !isSim)
            numericCell(viewModel.rowNight(row), width: ColWidth.night)
            numericCell(viewModel.rowP1(row),    width: ColWidth.p1)
            numericCell(viewModel.rowICUS(row),  width: ColWidth.icus)
            numericCell(viewModel.rowP2(row),    width: ColWidth.p2)
            numericCell(viewModel.rowSim(row),   width: ColWidth.sim, highlight: isSim)
            numericCell(viewModel.rowInst(row),  width: ColWidth.inst)
        }
        .font(.caption)
        .foregroundStyle(dimmed ? Color.secondary.opacity(0.5) : Color.primary)
        .frame(height: 36)
        .background(rowBackground(isSelected: isSelected, isSim: isSim))
    }

    @ViewBuilder
    private func sectorCell(row: [String], isSim: Bool) -> some View {
        if isSim {
            Text("SIM")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.indigo.opacity(0.75), in: Capsule())
        } else {
            Text(viewModel.rowSector(row))
        }
    }

    private func numericCell(_ value: String, width: CGFloat, highlight: Bool = false) -> some View {
        Text(value)
            .foregroundStyle(value == "—" ? Color.secondary.opacity(0.4) : (highlight ? Color.primary : Color.primary))
            .frame(width: width, alignment: .trailing)
            .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func rowBackground(isSelected: Bool, isSim: Bool) -> some View {
        if isSim && isSelected {
            Color.indigo.opacity(0.08)
        } else if !isSelected {
            Color.secondary.opacity(0.15)
        } else {
            Color.clear
        }
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            Button {
                let filtered = viewModel.filteredImportData
                onConfirm(filtered)
                dismiss()
            } label: {
                Text("Import \(viewModel.selectedCount) Row\(viewModel.selectedCount == 1 ? "" : "s")")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.selectedCount == 0 ? Color.secondary.opacity(0.3) : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.selectedCount == 0)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .primaryAction) {
            Button(viewModel.allSelected ? "Deselect All" : "Select All") {
                if viewModel.allSelected {
                    viewModel.deselectAll()
                } else {
                    viewModel.selectAll()
                }
            }
        }
    }
}
