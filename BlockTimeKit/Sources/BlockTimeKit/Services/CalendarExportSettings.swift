//
//  CalendarExportSettings.swift
//  Block-Time
//

import Foundation
import Observation

// MARK: - Export Mode

enum CalendarExportMode: String, CaseIterable {
    case allDayOnly
    case sectorsOnly
    case both

    var displayName: String {
        switch self {
        case .allDayOnly:  return "All-day only"
        case .sectorsOnly: return "Individual sectors"
        case .both:        return "Both"
        }
    }
}

// MARK: - Component Enums

enum AllDayComponent: String, CaseIterable, Identifiable {
    case firstSTD
    case route
    case lastSTA
    case flightNumbers

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firstSTD:      return "First STD (0900)"
        case .route:         return "Route (BNE -> SYD)"
        case .lastSTA:       return "Last STA (1700)"
        case .flightNumbers: return "Flight numbers in route"
        }
    }
}

enum SectorComponent: String, CaseIterable, Identifiable {
    case std
    case flightNumber
    case from
    case to
    case sta
    case paxIndicator

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .std:          return "STD (09:00)"
        case .flightNumber: return "Flight number"
        case .from:         return "From (BNE)"
        case .to:           return "To (SYD)"
        case .sta:          return "STA (11:30)"
        case .paxIndicator: return "PAX indicator"
        }
    }
}

// MARK: - OrderedComponent

struct OrderedComponent: Codable, Identifiable {
    var rawValue: String
    var enabled: Bool
    var id: String { rawValue }
}

// MARK: - Settings

@Observable
@MainActor
final class CalendarExportSettings {

    static let shared = CalendarExportSettings()

    private static let modeKey              = "CalendarExport.mode"
    private static let allDayComponentsKey  = "CalendarExport.allDayComponents"
    private static let sectorComponentsKey  = "CalendarExport.sectorComponents"

    var mode: CalendarExportMode {
        didSet { persist() }
    }

    var allDayComponents: [OrderedComponent] {
        didSet { persist() }
    }

    var sectorComponents: [OrderedComponent] {
        didSet { persist() }
    }

    private init() {
        // Load mode
        let rawMode = UserDefaults.standard.string(forKey: Self.modeKey) ?? ""
        self.mode = CalendarExportMode(rawValue: rawMode) ?? .both

        // Load and merge allDayComponents
        let defaultAllDay: [OrderedComponent] = [
            OrderedComponent(rawValue: AllDayComponent.firstSTD.rawValue,      enabled: true),
            OrderedComponent(rawValue: AllDayComponent.route.rawValue,         enabled: true),
            OrderedComponent(rawValue: AllDayComponent.lastSTA.rawValue,       enabled: true),
            OrderedComponent(rawValue: AllDayComponent.flightNumbers.rawValue, enabled: false),
        ]
        self.allDayComponents = Self.loadComponents(
            key: Self.allDayComponentsKey,
            defaults: defaultAllDay,
            allCases: AllDayComponent.allCases.map { $0.rawValue }
        )

        // Load and merge sectorComponents
        let defaultSector: [OrderedComponent] = [
            OrderedComponent(rawValue: SectorComponent.std.rawValue,          enabled: true),
            OrderedComponent(rawValue: SectorComponent.flightNumber.rawValue, enabled: true),
            OrderedComponent(rawValue: SectorComponent.from.rawValue,         enabled: true),
            OrderedComponent(rawValue: SectorComponent.to.rawValue,           enabled: true),
            OrderedComponent(rawValue: SectorComponent.sta.rawValue,          enabled: true),
            OrderedComponent(rawValue: SectorComponent.paxIndicator.rawValue, enabled: true),
        ]
        self.sectorComponents = Self.loadComponents(
            key: Self.sectorComponentsKey,
            defaults: defaultSector,
            allCases: SectorComponent.allCases.map { $0.rawValue }
        )
    }

    // MARK: - Enabled Helpers

    func enabledAllDay() -> [AllDayComponent] {
        allDayComponents
            .filter { $0.enabled }
            .compactMap { AllDayComponent(rawValue: $0.rawValue) }
    }

    func enabledSector() -> [SectorComponent] {
        sectorComponents
            .filter { $0.enabled }
            .compactMap { SectorComponent(rawValue: $0.rawValue) }
    }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey)
        if let data = try? JSONEncoder().encode(allDayComponents) {
            UserDefaults.standard.set(data, forKey: Self.allDayComponentsKey)
        }
        if let data = try? JSONEncoder().encode(sectorComponents) {
            UserDefaults.standard.set(data, forKey: Self.sectorComponentsKey)
        }
    }

    // MARK: - Load + Merge

    private static func loadComponents(
        key: String,
        defaults: [OrderedComponent],
        allCases: [String]
    ) -> [OrderedComponent] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let stored = try? JSONDecoder().decode([OrderedComponent].self, from: data)
        else {
            return defaults
        }

        // Drop unknown rawValues, preserve order of known ones
        let known = Set(allCases)
        var merged = stored.filter { known.contains($0.rawValue) }

        // Append any new cases not yet in stored list (disabled by default)
        let storedRawValues = Set(merged.map { $0.rawValue })
        for rawValue in allCases where !storedRawValues.contains(rawValue) {
            merged.append(OrderedComponent(rawValue: rawValue, enabled: false))
        }

        return merged
    }
}
