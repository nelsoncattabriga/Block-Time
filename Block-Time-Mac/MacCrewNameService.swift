//
//  MacCrewNameService.swift
//  Block-Time-Mac
//
//  Reads and writes crew name lists from the same UserDefaults keys
//  as the iOS app. Lists sync via iCloud KVS so Mac and iOS share names.
//

import Foundation
import Combine

@MainActor
final class MacCrewNameService: ObservableObject {

    static let shared = MacCrewNameService()

    @Published private(set) var captainNames: [String] = []
    @Published private(set) var coPilotNames: [String] = []
    @Published private(set) var soNames: [String] = []

    private let kvs = NSUbiquitousKeyValueStore.default

    private enum Keys {
        static let captain  = "savedCaptainNames"
        static let coPilot  = "savedCoPilotNames"
        static let so       = "savedSONames"
        static let kCapt    = "cloud_savedCaptainNames"
        static let kCoPilot = "cloud_savedCoPilotNames"
        static let kSO      = "cloud_savedSONames"
    }

    private init() {
        load()
        kvs.synchronize()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvsChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs
        )
    }

    // MARK: - Load

    private func load() {
        captainNames = loadNames(localKey: Keys.captain, kvsKey: Keys.kCapt)
        coPilotNames = loadNames(localKey: Keys.coPilot, kvsKey: Keys.kCoPilot)
        soNames      = loadNames(localKey: Keys.so,      kvsKey: Keys.kSO)
    }

    private func loadNames(localKey: String, kvsKey: String) -> [String] {
        // KVS takes precedence if non-empty (iOS is source of truth)
        if let kvsNames = kvs.array(forKey: kvsKey) as? [String], !kvsNames.isEmpty {
            UserDefaults.standard.set(kvsNames, forKey: localKey)
            return kvsNames.sorted()
        }
        return (UserDefaults.standard.stringArray(forKey: localKey) ?? []).sorted()
    }

    @objc private func kvsChanged(_ notification: Notification) {
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        if keys.contains(Keys.kCapt)    { captainNames = loadNames(localKey: Keys.captain, kvsKey: Keys.kCapt) }
        if keys.contains(Keys.kCoPilot) { coPilotNames = loadNames(localKey: Keys.coPilot, kvsKey: Keys.kCoPilot) }
        if keys.contains(Keys.kSO)      { soNames      = loadNames(localKey: Keys.so,      kvsKey: Keys.kSO) }
    }

    // MARK: - Write

    func addCaptainName(_ name: String) { captainNames = addName(name, localKey: Keys.captain, kvsKey: Keys.kCapt) }
    func addCoPilotName(_ name: String) { coPilotNames = addName(name, localKey: Keys.coPilot, kvsKey: Keys.kCoPilot) }
    func addSOName(_ name: String)      { soNames      = addName(name, localKey: Keys.so,      kvsKey: Keys.kSO) }

    private func addName(_ name: String, localKey: String, kvsKey: String) -> [String] {
        var names = UserDefaults.standard.stringArray(forKey: localKey) ?? []
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !names.contains(trimmed) else { return names.sorted() }
        names.append(trimmed)
        names.sort()
        UserDefaults.standard.set(names, forKey: localKey)
        kvs.set(names, forKey: kvsKey)
        kvs.synchronize()
        return names
    }
}
