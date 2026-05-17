//
//  CustomCounterService.swift
//  Block-Time
//
//  @Observable singleton managing user-defined counter definitions in UserDefaults.
//

import Foundation
import Observation

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

    func add(label: String, type: CounterType) {
        let definition = CustomCounterDefinition(id: UUID(), label: label, type: type)
        definitions.append(definition)
        persist()
    }

    func remove(id: UUID) {
        definitions.removeAll { $0.id == id }
        persist()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        definitions.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    func definition(for id: UUID) -> CustomCounterDefinition? {
        definitions.first { $0.id == id }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(definitions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
