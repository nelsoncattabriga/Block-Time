//
//  CalendarExportSettings.swift
//  Block-Time
//

import Foundation
import Observation

// MARK: - Export Mode

public enum CalendarExportMode: String, CaseIterable {
    case allDayOnly
    case sectorsOnly
    case both

    public var displayName: String {
        switch self {
        case .allDayOnly:  return "All-day only"
        case .sectorsOnly: return "Individual sectors"
        case .both:        return "Both"
        }
    }
}

// MARK: - Component Enums

public enum AllDayComponent: String, CaseIterable, Identifiable {
    case firstSTD
    case route
    case lastSTA
    case flightNumbers

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .firstSTD:      return "First STD (0900)"
        case .route:         return "Route (BNE -> SYD)"
        case .lastSTA:       return "Last STA (1700)"
        case .flightNumbers: return "Flight numbers in route"
        }
    }
}

public enum SectorComponent: String, CaseIterable, Identifiable {
    case std
    case flightNumber
    case from
    case to
    case sta
    case paxIndicator

    public var id: String { rawValue }

    public var displayName: String {
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

public struct OrderedComponent: Codable, Identifiable {
    public var rawValue: String
    public var enabled: Bool
    public var id: String { rawValue }

    public init(rawValue: String, enabled: Bool) {
        self.rawValue = rawValue
        self.enabled = enabled
    }
}

// MARK: - Settings

@Observable
@MainActor
public final class CalendarExportSettings {

    public static let shared = CalendarExportSettings()

    private static let modeKey              = "CalendarExport.mode"
    private static let allDayComponentsKey  = "CalendarExport.allDayComponents"
    private static let sectorComponentsKey  = "CalendarExport.sectorComponents"

    public var mode: CalendarExportMode {
        didSet { persist() }
    }

    public var allDayComponents: [OrderedComponent] {
        didSet { persist() }
    }

    public var sectorComponents: [OrderedComponent] {
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

    public func enabledAllDay() -> [AllDayComponent] {
        allDayComponents
            .filter { $0.enabled }
            .compactMap { AllDayComponent(rawValue: $0.rawValue) }
    }

    public func enabledSector() -> [SectorComponent] {
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
