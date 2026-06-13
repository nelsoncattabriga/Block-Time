//
//  ColumnPreferences.swift
//  Block-Time-Mac
//
//  Persists user column order and visibility to UserDefaults.
//

import Foundation
import Observation
import SwiftUI

@Observable
final class ColumnPreferences {
    private static let orderKey  = "logbook.column.order"
    private static let hiddenKey = "logbook.column.hidden"
    private static let widthsKey = "logbook.column.widths"

    var order:  [String]
    var hidden: Set<String>
    var widths: [String: CGFloat]

    init() {
        // Static columns only — custom field columns are dynamic and handled in visibleColumns.
        let staticIDs = LogbookColumn.scrollingColumns(hhmm: true, rounding: "standard", localTime: false).map(\.id)

        if let saved = UserDefaults.standard.stringArray(forKey: Self.orderKey) {
            // Accept saved order if it contains at least the static columns (subset check).
            // Custom column IDs may or may not be present depending on when definitions loaded.
            let staticSet = Set(staticIDs)
            let savedSet  = Set(saved)
            order = staticSet.isSubset(of: savedSet) ? saved : staticIDs
        } else {
            order = staticIDs
        }

        if let savedHidden = UserDefaults.standard.stringArray(forKey: Self.hiddenKey) {
            hidden = Set(savedHidden)
        } else {
            hidden = []
        }

        if let saved = UserDefaults.standard.dictionary(forKey: Self.widthsKey) as? [String: Double] {
            widths = saved.mapValues { CGFloat($0) }
        } else {
            widths = [:]
        }
    }

    func saveWidth(_ width: CGFloat, forID id: String) {
        widths[id] = width
        UserDefaults.standard.set(widths.mapValues { Double($0) }, forKey: Self.widthsKey)
    }

    func visibleColumns(hhmm: Bool, rounding: String, localTime: Bool, useIATA: Bool = true) -> [LogbookColumn] {
        let allCols = LogbookColumn.scrollingColumns(hhmm: hhmm, rounding: rounding, localTime: localTime, useIATA: useIATA)
        let lookup  = Dictionary(uniqueKeysWithValues: allCols.map { ($0.id, $0) })
        // Columns in persisted order first, then any not-yet-ordered columns appended at end
        // (covers custom columns added after first launch or before definitions loaded).
        let orderedIDs  = order + allCols.map(\.id).filter { !order.contains($0) }
        return orderedIDs.compactMap { lookup[$0] }.filter { !hidden.contains($0.id) }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        order.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    func toggleVisibility(_ id: String) {
        if hidden.contains(id) { hidden.remove(id) } else { hidden.insert(id) }
        persist()
    }

    func reset() {
        // Reset to default order — visibleColumns will append any custom columns not in this list.
        order  = LogbookColumn.scrollingColumns(hhmm: true, rounding: "standard", localTime: false).map(\.id)
        hidden = []
        widths = [:]
        UserDefaults.standard.removeObject(forKey: Self.widthsKey)
        persist()
    }

    func persist() {
        UserDefaults.standard.set(order, forKey: Self.orderKey)
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
    }
}
