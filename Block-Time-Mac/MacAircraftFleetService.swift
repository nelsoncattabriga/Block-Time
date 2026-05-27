//
//  MacAircraftFleetService.swift
//  Block-Time-Mac
//
//  Fleet service for the Mac. Exposes the same static Qantas fleet as the iOS
//  AircraftFleetService, plus custom aircraft read from the shared CloudKit-synced
//  Core Data store via MacLogbookViewModel's context.
//

import Foundation
import Combine

// MARK: - Models (mirrors iOS Aircraft / Fleet)

struct MacAircraft: Identifiable, Hashable {
    let id: String
    let registration: String        // short form, e.g. "VXA"
    let fullRegistration: String    // e.g. "VH-VXA"
    let type: String
    let isCustom: Bool

    /// Standard static aircraft init.
    init(id: String, registration: String, fullRegistration: String, type: String) {
        self.id = id
        self.registration = registration
        self.fullRegistration = fullRegistration
        self.type = type
        self.isCustom = false
    }

    /// Custom aircraft init — mirrors iOS Aircraft(customRegistration:type:).
    /// Strips "VH-" prefix and stores short form so the showFullReg toggle works.
    /// Non-VH registrations (sims, foreign) are stored verbatim.
    init(customRegistration rawInput: String, type: String) {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("VH-") {
            let short = String(trimmed.dropFirst(3))
            self.id = short
            self.registration = short
            self.fullRegistration = trimmed
        } else {
            self.id = trimmed
            self.registration = trimmed
            self.fullRegistration = trimmed
        }
        self.type = type
        self.isCustom = true
    }

    func displayRegistration(showFullReg: Bool) -> String {
        showFullReg ? fullRegistration : registration
    }
}

struct MacFleet: Identifiable, Hashable {
    let id: String
    let name: String
    let aircraft: [MacAircraft]
}

// MARK: - Service

final class MacAircraftFleetService: ObservableObject {

    static let shared = MacAircraftFleetService()

    @Published private(set) var fleets: [MacFleet] = []

    private init() {
        fleets = Self.buildFleets(customAircraft: [])
    }

    // MARK: - Refresh (called by MacLogbookViewModel after any aircraft CRUD)

    func refresh(customAircraft: [MacAircraft]) {
        fleets = Self.buildFleets(customAircraft: customAircraft)
    }

    // MARK: - Computed helpers

    var selectedFleet: MacFleet? {
        let id = UserDefaults.standard.string(forKey: "selectedFleetID") ?? "B737"
        return fleets.first { $0.id == id } ?? fleets.first
    }

    // MARK: - Fleet construction

    private static let fleetDefinitions: [(name: String, types: [String], prefix: String?)] = [
        ("B737",  ["B731","B732","B733","B734","B735","B736","B737","B738","B739","B37M","B38M","B39M","B3XM"], "B73"),
        ("A320",  ["A321","A21N","A320","A20N","A318","A319","A19N"], "A32"),
        ("A330",  ["A330","A332","A333","A338","A339"], "A330"),
        ("B787",  ["B787","B788","B789","B78X"], "B78"),
        ("A380",  ["A388","A380"], "A38"),
        ("B747",  ["B741","B742","B743","B744","B74S","B747","B748"], "B74"),
        ("B767",  ["B762","B763","B764","B767"], "B767"),
        ("DHC-8", ["DHC-8","DHC8","DH8A","DH8B","DH8C","DH8D"], "DH8"),
    ]

    private static let staticAircraft: [MacAircraft] = {
        func a(_ reg: String, _ type: String) -> MacAircraft {
            MacAircraft(id: reg, registration: reg, fullRegistration: "VH-\(reg)", type: type)
        }
        return [
            // B737-800
            a("VXA","B738"), a("VXB","B738"), a("VXC","B738"), a("VXD","B738"), a("VXE","B738"),
            a("VXF","B738"), a("VXG","B738"), a("VXH","B738"), a("VXI","B738"), a("VXJ","B738"),
            a("VXK","B738"), a("VXL","B738"), a("VXM","B738"), a("VXN","B738"), a("VXO","B738"),
            a("VXP","B738"), a("VXQ","B738"), a("VXR","B738"), a("VXS","B738"), a("VXT","B738"),
            a("VXU","B738"),
            a("VYA","B738"), a("VYB","B738"), a("VYC","B738"), a("VYD","B738"), a("VYE","B738"),
            a("VYF","B738"), a("VYG","B738"), a("VYH","B738"), a("VYI","B738"), a("VYJ","B738"),
            a("VYK","B738"), a("VYL","B738"), a("VYZ","B738"),
            a("VZA","B738"), a("VZB","B738"), a("VZC","B738"), a("VZD","B738"), a("VZE","B738"),
            a("VZF","B738"), a("VZG","B738"), a("VZH","B738"), a("VZI","B738"), a("VZJ","B738"),
            a("VZK","B738"), a("VZL","B738"), a("VZM","B738"), a("VZN","B738"), a("VZO","B738"),
            a("VZP","B738"), a("VZQ","B738"), a("VZR","B738"), a("VZS","B738"), a("VZT","B738"),
            a("VZU","B738"), a("VZV","B738"), a("VZW","B738"), a("VZX","B738"), a("VZY","B738"),
            a("VZZ","B738"),
            a("XZA","B738"), a("XZB","B738"), a("XZC","B738"), a("XZD","B738"), a("XZE","B738"),
            a("XZF","B738"), a("XZG","B738"), a("XZH","B738"), a("XZI","B738"), a("XZJ","B738"),
            a("XZK","B738"), a("XZL","B738"), a("XZM","B738"), a("XZN","B738"), a("XZO","B738"),
            a("XZP","B738"), a("XZQ","B738"), a("XZR","B738"), a("XZS","B738"), a("XZT","B738"),
            // A321 XLR
            a("OGA","A21N"), a("OGB","A21N"), a("OGC","A21N"), a("OGD","A21N"),
            a("OGE","A21N"), a("OGF","A21N"), a("OGG","A21N"),
            // B787
            a("ZNA","B789"), a("ZNB","B789"), a("ZNC","B789"), a("ZND","B789"),
            a("ZNE","B789"), a("ZNF","B789"), a("ZNG","B789"), a("ZNH","B789"),
            a("ZNI","B789"), a("ZNJ","B789"), a("ZNK","B789"), a("ZNL","B789"),
            a("ZNM","B789"), a("ZNN","B789"),
            // A330-200
            a("EBA","A332"), a("EBB","A332"), a("EBC","A332"), a("EBD","A332"),
            a("EBE","A332"), a("EBF","A332"), a("EBG","A332"), a("EBH","A332"),
            a("EBI","A332"), a("EBJ","A332"), a("EBK","A332"), a("EBL","A332"),
            a("EBM","A332"), a("EBN","A332"), a("EBO","A332"), a("EBP","A332"),
            a("EBQ","A332"), a("EBR","A332"), a("EBS","A332"), a("EBT","A332"),
            a("EBU","A332"), a("EBV","A332"),
            // A330-300
            a("QPA","A333"), a("QPB","A333"), a("QPC","A333"), a("QPD","A333"),
            a("QPE","A333"), a("QPF","A333"), a("QPG","A333"), a("QPH","A333"),
            a("QPI","A333"), a("QPJ","A333"), a("QPK","A333"), a("QPL","A333"),
            // A380
            a("OQA","A388"), a("OQB","A388"), a("OQC","A388"), a("OQD","A388"),
            a("OQE","A388"), a("OQF","A388"), a("OQG","A388"), a("OQH","A388"),
            a("OQI","A388"), a("OQJ","A388"), a("OQK","A388"), a("OQL","A388"),
        ]
    }()

    private static func buildFleets(customAircraft: [MacAircraft]) -> [MacFleet] {
        var result: [MacFleet] = []
        var customRemainder = customAircraft

        for def in fleetDefinitions {
            let staticMatching = staticAircraft.filter {
                def.types.contains($0.type) ||
                (def.prefix != nil && $0.type.hasPrefix(def.prefix!))
            }
            let customMatching = customRemainder.filter {
                def.types.contains($0.type) ||
                (def.prefix != nil && $0.type.hasPrefix(def.prefix!))
            }
            customRemainder.removeAll { a in customMatching.contains(a) }

            let all = (staticMatching + customMatching).sorted { $0.registration < $1.registration }
            guard !all.isEmpty else { continue }
            result.append(MacFleet(id: def.name, name: def.name, aircraft: all))
        }

        // Custom aircraft whose type doesn't match any known fleet go in a "Custom" section
        if !customRemainder.isEmpty {
            let sorted = customRemainder.sorted { $0.registration < $1.registration }
            result.append(MacFleet(id: "Custom", name: "Custom", aircraft: sorted))
        }

        return result
    }
}
