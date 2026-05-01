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
        let defaultIDs = LogbookColumn.scrollingColumns(hhmm: true, rounding: "standard", localTime: false).map(\.id)

        if let saved = UserDefaults.standard.stringArray(forKey: Self.orderKey),
           Set(saved) == Set(defaultIDs) {
            order = saved
        } else {
            order = defaultIDs
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
        let lookup = Dictionary(uniqueKeysWithValues: LogbookColumn.scrollingColumns(hhmm: hhmm, rounding: rounding, localTime: localTime, useIATA: useIATA).map { ($0.id, $0) })
        return order.compactMap { lookup[$0] }.filter { !hidden.contains($0.id) }
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
        order  = LogbookColumn.scrollingColumns(hhmm: true, rounding: "standard", localTime: false).map(\.id)
        hidden = []
        widths = [:]
        persist()
        UserDefaults.standard.removeObject(forKey: Self.widthsKey)
    }

    func persist() {
        UserDefaults.standard.set(order, forKey: Self.orderKey)
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
    }
}
