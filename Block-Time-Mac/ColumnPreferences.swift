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

    var order:  [String]    // IDs of scrolling columns in user order
    var hidden: Set<String> // IDs of hidden scrolling columns

    init() {
        let defaultIDs = LogbookColumn.scrollingColumns.map(\.id)

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
    }

    var visibleColumns: [LogbookColumn] {
        let lookup = Dictionary(uniqueKeysWithValues: LogbookColumn.scrollingColumns.map { ($0.id, $0) })
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
        order  = LogbookColumn.scrollingColumns.map(\.id)
        hidden = []
        persist()
    }

    func persist() {
        UserDefaults.standard.set(order, forKey: Self.orderKey)
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
    }
}
