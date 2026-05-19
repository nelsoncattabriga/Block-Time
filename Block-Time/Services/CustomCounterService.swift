//
//  CustomCounterService.swift
//  Block-Time
//
//  @Observable singleton managing user-defined counter definitions in UserDefaults.
//

import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class CustomCounterService {

    static let shared = CustomCounterService()

    private(set) var definitions: [CustomCounterDefinition]
    private let storageKey = "customCounterDefinitions"

    private init() {
        if let data = UserDefaults.standard.data(forKey: "customCounterDefinitions"),
           let decoded = try? JSONDecoder().decode([CustomCounterDefinition].self, from: data) {
            definitions = decoded
        } else {
            definitions = []
        }
    }

    /// One-time migration: if the user had the legacy custom counter enabled but no new
    /// counter definitions yet, register column 1 using the legacy label.
    /// Returns true if a definition was created (caller should then run the Core Data migration).
    @discardableResult
    func migrateLegacyDefinitionIfNeeded(legacyLabel: String) -> Bool {
        let trimmed = legacyLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, definitions.isEmpty else { return false }
        let definition = CustomCounterDefinition(columnIndex: 1, label: trimmed, type: .integer)
        definitions.append(definition)
        persist()
        return true
    }

    func add(label: String, type: CounterType, showTotal: Bool = true) {
        let usedSlots = Set(definitions.map { $0.columnIndex })
        guard let slot = (1...10).first(where: { !usedSlots.contains($0) }) else { return }
        let definition = CustomCounterDefinition(columnIndex: slot, label: label, type: type, showTotal: showTotal)
        definitions.append(definition)
        persist()
    }

    func remove(columnIndex: Int) {
        definitions.removeAll { $0.columnIndex == columnIndex }
        persist()
    }

    func update(columnIndex: Int, label: String, type: CounterType, showTotal: Bool) {
        guard let index = definitions.firstIndex(where: { $0.columnIndex == columnIndex }) else { return }
        definitions[index].label = label
        definitions[index].type = type
        definitions[index].showTotal = showTotal
        persist()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        definitions.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    func definition(for columnIndex: Int) -> CustomCounterDefinition? {
        definitions.first { $0.columnIndex == columnIndex }
    }

    func replaceAll(_ definitions: [CustomCounterDefinition]) {
        self.definitions = definitions
        persist()
    }

    var isFull: Bool { definitions.count >= 10 }

    private func persist() {
        if let data = try? JSONEncoder().encode(definitions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        CloudKitSettingsSyncService.shared.syncToCloud()
    }
}
