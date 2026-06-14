//
//  WebCISPreviewView.swift
//  Block-Time
//
//  Created by Nelson on 22/03/2026.
//

import SwiftUI
import BlockTimeKit

// MARK: - Pre-processed row (all display values computed once — never recomputed)

struct WebCISDisplayRow: Identifiable {
    let id: Int         // same as index
    let index: Int
    let isSim: Bool
    let date: String
    let reg: String
    let sector: String
    // Display strings — "—" when zero
    let total: String
    let night: String
    let p1: String
    let icus: String
    let p2: String
    let sim: String
    let inst: String
    let flen: String      // Flight Engineer
    let spins: String     // Sp/Ins
    let isSuspicious: Bool  // true when both totalMin and simMin are zero (incomplete data)
    // Raw minute values for incremental summary arithmetic
    let totalMin: Int
    let nightMin: Int
    let p1Min: Int
    let icusMin: Int
    let p2Min: Int
    let simMin: Int
    let instMin: Int
    let flenMin: Int
    let spinsMin: Int
}

// MARK: - Background parsing helpers (file-private free functions — nonisolated, thread-safe)

nonisolated private func parseWebCISDisplayRows(from importData: ImportData) -> [WebCISDisplayRow] {
    var result = [WebCISDisplayRow]()
    result.reserveCapacity(importData.rows.count)
    for (i, raw) in importData.rows.enumerated() {
        result.append(wcisParseRow(index: i, raw: raw))
    }
    return result
}

nonisolated private func wcisParseRow(index: Int, raw: [String]) -> WebCISDisplayRow {
    func f(_ i: Int) -> String {
        guard i < raw.count else { return "" }
        return raw[i].trimmingCharacters(in: .whitespaces)
    }
    // ImportData column layout after FileImportService.parseWebCISText:
    //  0:DATE 1:REG 2:DEP 3:DES 4:INST
    //  5:P2D  6:P2N 7:P1D 8:P1N 9:P1USD 10:P1USN
    //  11:MEDD 12:MEDN 13:MEFD 14:MEFN 15:MECD 16:MECN
    //  17:SIMU 18:FLEN 19:TOTAL 20:SPINS
    let dep = f(2), des = f(3), simu = f(17)
    let isSim = dep.isEmpty && des.isEmpty && !simu.isEmpty

    // TOTAL (col 19) is stored as decimal hours e.g. "1.77" by sumWebCISTimes.
    // Parse via decimal rather than H:MM to avoid showing zeros everywhere.
    let totalMin = wcisParseDecimalHours(f(19))
    let nightMin = wcisSumMinutes([f(6), f(8), f(10), f(12), f(14), f(16)])
    let p1Min    = wcisSumMinutes([f(7), f(8), f(15), f(16)])
    let icusMin  = wcisSumMinutes([f(9), f(10)])
    let p2Min    = wcisSumMinutes([f(5), f(6), f(11), f(12), f(13), f(14)])
    let simMin   = wcisParseMinutes(simu)
    let instMin  = wcisParseMinutes(f(4))
    let flenMin  = wcisParseMinutes(f(18))
    let spinsMin = wcisParseMinutes(f(20))

    let sector: String
    if isSim            { sector = "SIM" }
    else if dep.isEmpty { sector = "—" }
    else                { sector = "\(dep)-\(des)" }

    return WebCISDisplayRow(
        id: index, index: index, isSim: isSim,
        date:   f(0),
        reg:    isSim ? "SIM" : f(1),
        sector: sector,
        total:  wcisDisplayTime(totalMin), night: wcisDisplayTime(nightMin),
        p1:     wcisDisplayTime(p1Min),    icus:  wcisDisplayTime(icusMin),
        p2:     wcisDisplayTime(p2Min),    sim:   wcisDisplayTime(simMin),
        inst:   wcisDisplayTime(instMin),  flen:  wcisDisplayTime(flenMin),
        spins:  wcisDisplayTime(spinsMin),
        isSuspicious: totalMin == 0 && simMin == 0,
        totalMin: totalMin, nightMin: nightMin, p1Min:  p1Min,
        icusMin:  icusMin,  p2Min:    p2Min,    simMin: simMin,
        instMin:  instMin,  flenMin:  flenMin,  spinsMin: spinsMin
    )
}

/// Parses TOTAL column stored as decimal hours e.g. "1.77" → 106 minutes.
nonisolated private func wcisParseDecimalHours(_ s: String) -> Int {
    let t = s.trimmingCharacters(in: .whitespaces)
    guard let d = Double(t), d > 0 else { return 0 }
    return Int((d * 60).rounded())
}

nonisolated private func wcisParseMinutes(_ s: String) -> Int {
    let t = s.trimmingCharacters(in: .whitespaces)
    guard (t.count == 4 || t.count == 5), let colon = t.firstIndex(of: ":") else { return 0 }
    guard let h = Int(t[t.startIndex..<colon]),
          let m = Int(t[t.index(after: colon)...]) else { return 0 }
    return h * 60 + m
}

nonisolated private func wcisSumMinutes(_ times: [String]) -> Int {
    times.reduce(0) { $0 + wcisParseMinutes($1) }
}

nonisolated private func wcisDisplayTime(_ minutes: Int) -> String {
    guard minutes > 0 else { return "—" }
    return String(format: "%d:%02d", minutes / 60, minutes % 60)
}

// MARK: - ViewModel

@Observable @MainActor
final class WebCISPreviewViewModel {

    let rows: [WebCISDisplayRow]
    let totalCount: Int
    let importData: ImportData

    var selectedRowIndices: Set<Int>

    // Incremental totals in minutes — O(1) per toggle
    private(set) var sumBlock: Int
    private(set) var sumNight: Int
    private(set) var sumP1: Int
    private(set) var sumICUS: Int
    private(set) var sumP2: Int
    private(set) var sumSim: Int
    private(set) var sumInst: Int
    private(set) var sumFlen: Int
    private(set) var sumSpins: Int

    init(importData: ImportData, prebuiltRows: [WebCISDisplayRow]) {
        self.importData = importData
        self.totalCount = prebuiltRows.count
        self.rows = prebuiltRows
        self.selectedRowIndices = Set(prebuiltRows.indices)

        var b = 0, n = 0, p1 = 0, ic = 0, p2 = 0, si = 0, ins = 0, fl = 0, sp = 0
        for r in prebuiltRows {
            b += r.totalMin; n += r.nightMin; p1 += r.p1Min
            ic += r.icusMin; p2 += r.p2Min;  si += r.simMin
            ins += r.instMin; fl += r.flenMin; sp += r.spinsMin
        }
        self.sumBlock = b; self.sumNight = n; self.sumP1 = p1
        self.sumICUS  = ic; self.sumP2 = p2;  self.sumSim = si
        self.sumInst  = ins; self.sumFlen = fl; self.sumSpins = sp
    }

    // MARK: Selection

    var selectedCount: Int { selectedRowIndices.count }
    var allSelected: Bool  { selectedRowIndices.count == totalCount }

    func toggleRow(_ index: Int) {
        guard index < rows.count else { return }
        let r = rows[index]
        if selectedRowIndices.contains(index) {
            selectedRowIndices.remove(index)
            sumBlock -= r.totalMin; sumNight -= r.nightMin; sumP1   -= r.p1Min
            sumICUS  -= r.icusMin;  sumP2    -= r.p2Min;   sumSim  -= r.simMin
            sumInst  -= r.instMin;  sumFlen  -= r.flenMin; sumSpins -= r.spinsMin
        } else {
            selectedRowIndices.insert(index)
            sumBlock += r.totalMin; sumNight += r.nightMin; sumP1   += r.p1Min
            sumICUS  += r.icusMin;  sumP2    += r.p2Min;   sumSim  += r.simMin
            sumInst  += r.instMin;  sumFlen  += r.flenMin; sumSpins += r.spinsMin
        }
    }

    func selectAll() {
        selectedRowIndices = Set(rows.indices)
        recomputeTotals()
    }

    func deselectAll() {
        selectedRowIndices = []
        sumBlock = 0; sumNight = 0; sumP1 = 0; sumICUS = 0
        sumP2 = 0; sumSim = 0; sumInst = 0; sumFlen = 0; sumSpins = 0
    }

    private func recomputeTotals() {
        var b = 0, n = 0, p1 = 0, ic = 0, p2 = 0, si = 0, ins = 0, fl = 0, sp = 0
        for idx in selectedRowIndices {
            let r = rows[idx]
            b += r.totalMin; n += r.nightMin; p1 += r.p1Min
            ic += r.icusMin; p2 += r.p2Min;  si += r.simMin
            ins += r.instMin; fl += r.flenMin; sp += r.spinsMin
        }
        sumBlock = b; sumNight = n; sumP1 = p1; sumICUS = ic
        sumP2 = p2; sumSim = si; sumInst = ins; sumFlen = fl; sumSpins = sp
    }

    var filteredImportData: ImportData {
        let selected = rows
            .filter { selectedRowIndices.contains($0.index) }
            .map { importData.rows[$0.index] }
        return ImportData(headers: importData.headers, rows: selected,
                          fileURL: importData.fileURL, delimiter: importData.delimiter)
    }

    var suspiciousRowCount: Int {
        rows.filter { selectedRowIndices.contains($0.index) && $0.isSuspicious }.count
    }

    // Summary display strings
    var totalBlock: String { wcisDisplayTime(sumBlock) }
    var totalNight: String { wcisDisplayTime(sumNight) }
    var totalP1: String    { wcisDisplayTime(sumP1) }
    var totalICUS: String  { wcisDisplayTime(sumICUS) }
    var totalP2: String    { wcisDisplayTime(sumP2) }
    var totalSim: String   { wcisDisplayTime(sumSim) }
    var totalInst: String  { wcisDisplayTime(sumInst) }
    var totalFlen: String  { wcisDisplayTime(sumFlen) }
    var totalSpins: String { wcisDisplayTime(sumSpins) }
}

// MARK: - Main View

struct WebCISPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WebCISPreviewViewModel?
    let importData: ImportData
    let onConfirm: (ImportData) -> Void

    // Fixed column widths
    private enum CW {
        static let checkbox: CGFloat = 36
        static let date:     CGFloat = 88
        static let reg:      CGFloat = 60
        static let sector:   CGFloat = 76
        static let num:      CGFloat = 52   // all numeric columns share this width

        static var tableWidth: CGFloat {
            // checkbox + date + reg + sector + 9 numeric columns
            checkbox + date + reg + sector + num * 9
        }
    }

    init(importData: ImportData, onConfirm: @escaping (ImportData) -> Void) {
        self.importData = importData
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    loadedBody(vm: vm)
                } else {
                    loadingBody
                }
            }
            .navigationTitle("Review webCIS Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let vm = viewModel {
                    loadedToolbarItems(vm: vm)
                } else {
                    cancelToolbarItem
                }
            }
        }
        .task {
            let data = importData
            let prebuilt = await Task.detached(priority: .userInitiated) {
                parseWebCISDisplayRows(from: data)
            }.value
            self.viewModel = WebCISPreviewViewModel(importData: data, prebuiltRows: prebuilt)
        }
    }

    // MARK: - Loading state

    private var loadingBody: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Preparing \(importData.rows.count) rows…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loaded state

    private func loadedBody(vm: WebCISPreviewViewModel) -> some View {
        VStack(spacing: 0) {
            summaryStrip(vm: vm)
            warningBanner(vm: vm)
            Divider()
            // Pinned column-header row outside the List, but inside the same
            // horizontal scroll as the list rows — both share one ScrollView(.horizontal).
            // Vertical laziness comes from List; horizontal scroll wraps everything.
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerHStack
                        .frame(height: 30)
                        .frame(minWidth: CW.tableWidth)
                        .background(Color.secondary.opacity(0.12))
                    Divider()
                    // List provides native, truly-lazy vertical scrolling
                    List {
                        ForEach(vm.rows) { row in
                            rowContent(row, vm: vm)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.visible)
                                .listRowBackground(rowBackground(isSelected: vm.selectedRowIndices.contains(row.index), isSim: row.isSim, isSuspicious: row.isSuspicious))
                        }
                    }
                    .listStyle(.plain)
                    .frame(minWidth: CW.tableWidth)
                    // List has no intrinsic height inside a VStack — give it all remaining space
                    .frame(maxHeight: .infinity)
                    .environment(\.defaultMinListRowHeight, 36)
                }
            }
            Divider()
            bottomToolbar(vm: vm)
        }
    }

    // MARK: - Summary strip

    private func summaryStrip(vm: WebCISPreviewViewModel) -> some View {
        VStack(spacing: 4) {
            Text("\(vm.selectedCount) of \(vm.totalCount) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    statChip(label: "Block",  value: vm.totalBlock)
                    statChip(label: "Night",  value: vm.totalNight)
                    statChip(label: "P1",     value: vm.totalP1)
                    statChip(label: "ICUS",   value: vm.totalICUS)
                    statChip(label: "P2",     value: vm.totalP2)
                    statChip(label: "Sim",    value: vm.totalSim)
                    statChip(label: "Inst",   value: vm.totalInst)
                    if vm.sumFlen  > 0 { statChip(label: "F/Eng",  value: vm.totalFlen) }
                    if vm.sumSpins > 0 { statChip(label: "Sp/Ins", value: vm.totalSpins) }
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
    private func warningBanner(vm: WebCISPreviewViewModel) -> some View {
        let suspicious  = vm.suspiciousRowCount
        let noneSelected = vm.selectedCount == 0

        if noneSelected || suspicious > 0 {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                if noneSelected {
                    Text("No rows selected — select at least one row to import.")
                        .font(.caption)
                } else {
                    Text("\(suspicious) selected row\(suspicious == 1 ? "" : "s") flagged - no FLT times.")
                        .font(.caption)
                }
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.15))
        }
    }

    // MARK: - Column header row

    private var headerHStack: some View {
        HStack(spacing: 0) {
            Image(systemName: "checkmark.square")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: CW.checkbox, alignment: .center)
            colHdr("Date",   w: CW.date,   a: .leading)
            colHdr("Reg",    w: CW.reg,    a: .leading)
            colHdr("Sector", w: CW.sector, a: .leading)
            colHdr("Total",  w: CW.num)
            colHdr("Night",  w: CW.num)
            colHdr("P1",     w: CW.num)
            colHdr("ICUS",   w: CW.num)
            colHdr("P2",     w: CW.num)
            colHdr("Sim",    w: CW.num)
            colHdr("Inst",   w: CW.num)
            colHdr("F/Eng",  w: CW.num)
            colHdr("Sp/Ins", w: CW.num)
        }
        .padding(.horizontal, 4)
    }

    private func colHdr(_ title: String, w: CGFloat, a: Alignment = .trailing) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(width: w, alignment: a)
            .padding(.horizontal, 2)
    }

    // MARK: - Row content (used inside List)

    private func rowContent(_ row: WebCISDisplayRow, vm: WebCISPreviewViewModel) -> some View {
        let isSelected = vm.selectedRowIndices.contains(row.index)
        return Button {
            vm.toggleRow(row.index)
        } label: {
            HStack(spacing: 0) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: CW.checkbox, alignment: .center)

                Text(row.date)
                    .frame(width: CW.date, alignment: .leading).padding(.horizontal, 2)

                Text(row.reg)
                    .frame(width: CW.reg, alignment: .leading).padding(.horizontal, 2)

                sectorCell(row)
                    .frame(width: CW.sector, alignment: .leading).padding(.horizontal, 2)

                numCell(row.total, w: CW.num)
                numCell(row.night, w: CW.num)
                numCell(row.p1,    w: CW.num)
                numCell(row.icus,  w: CW.num)
                numCell(row.p2,    w: CW.num)
                numCell(row.sim,   w: CW.num)
                numCell(row.inst,  w: CW.num)
                numCell(row.flen,  w: CW.num)
                numCell(row.spins, w: CW.num)
            }
            .font(.caption)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.5))
            .frame(height: 36)
            .frame(minWidth: CW.tableWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectorCell(_ row: WebCISDisplayRow) -> some View {
        if row.isSim {
            Text("SIM")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.indigo.opacity(0.75), in: Capsule())
        } else {
            Text(row.sector)
        }
    }

    private func numCell(_ value: String, w: CGFloat) -> some View {
        Text(value)
            .foregroundStyle(value == "—" ? Color.secondary.opacity(0.4) : Color.primary)
            .frame(width: w, alignment: .trailing)
            .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func rowBackground(isSelected: Bool, isSim: Bool, isSuspicious: Bool) -> some View {
        if isSuspicious && isSelected {
            Color.orange.opacity(0.15)
        } else if isSuspicious {
            Color.orange.opacity(0.07)
        } else if isSim && isSelected {
            Color.indigo.opacity(0.08)
        } else if !isSelected {
            Color.secondary.opacity(0.12)
        } else {
            Color.clear
        }
    }

    // MARK: - Bottom toolbar

    private func bottomToolbar(vm: WebCISPreviewViewModel) -> some View {
        VStack(spacing: 0) {
            Button {
                let filtered = vm.filteredImportData
                onConfirm(filtered)
                dismiss()
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vm.selectedCount == 0 ? Color.secondary.opacity(0.3) : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(vm.selectedCount == 0)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var cancelToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    @ToolbarContentBuilder
    private func loadedToolbarItems(vm: WebCISPreviewViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(vm.allSelected ? "Deselect All" : "Select All") {
                if vm.allSelected { vm.deselectAll() } else { vm.selectAll() }
            }
        }
    }
}
