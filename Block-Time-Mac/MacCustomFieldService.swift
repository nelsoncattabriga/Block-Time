//
//  MacCustomFieldService.swift
//  Block-Time-Mac
//
//  Mac-only service that reads CustomCounterDefinition objects from local
//  UserDefaults and iCloud Key-Value Store, exposing them as @Published so
//  the table and edit panel react to iOS-side definition changes.
//

import Foundation
import Combine

@MainActor
final class MacCustomFieldService: ObservableObject {

    static let shared = MacCustomFieldService()

    @Published private(set) var definitions: [CustomCounterDefinition] = []

    private let localKey = "customCounterDefinitions"
    private let kvsKey   = "cloud_customCounterDefinitions"

    private init() {
        loadFromLocal()
        loadFromKVS()
        NSUbiquitousKeyValueStore.default.synchronize()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
    }

    // MARK: - Load helpers

    private func loadFromLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([CustomCounterDefinition].self, from: data)
        else {
            print("[MacCustomFieldService] loadFromLocal: nothing in UserDefaults")
            return
        }
        print("[MacCustomFieldService] loadFromLocal: \(decoded.count) definitions: \(decoded.map(\.label))")
        definitions = decoded
    }

    private func loadFromKVS() {
        guard let defs = decodeKVS(), !defs.isEmpty else {
            let raw = NSUbiquitousKeyValueStore.default.string(forKey: kvsKey)
            print("[MacCustomFieldService] loadFromKVS: nothing — raw KVS value: \(raw ?? "nil")")
            return
        }
        print("[MacCustomFieldService] loadFromKVS: \(defs.count) definitions: \(defs.map(\.label))")
        definitions = defs
        persistLocally(defs)
    }

    // MARK: - KVS decode helper

    private func decodeKVS() -> [CustomCounterDefinition]? {
        guard let jsonString = NSUbiquitousKeyValueStore.default.string(forKey: kvsKey),
              let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CustomCounterDefinition].self, from: data)
        else { return nil }
        return decoded
    }

    // MARK: - KVS change observer

    @objc private func kvStoreChanged(_ notification: Notification) {
        let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        print("[MacCustomFieldService] kvStoreChanged: keys=\(changedKeys)")
        guard changedKeys.contains(kvsKey) else { return }

        guard let defs = decodeKVS() else {
            print("[MacCustomFieldService] kvStoreChanged: decode failed")
            return
        }
        print("[MacCustomFieldService] kvStoreChanged: \(defs.count) definitions: \(defs.map(\.label))")
        definitions = defs
        persistLocally(defs)
    }

    // MARK: - Local persistence

    private func persistLocally(_ defs: [CustomCounterDefinition]) {
        if let data = try? JSONEncoder().encode(defs) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }
}
