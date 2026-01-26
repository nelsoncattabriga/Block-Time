import Foundation
import SwiftUI

@Observable
class LogbookSettings {
    static let shared = LogbookSettings()

    private let userDefaults = UserDefaults.standard
    private let selectedCardsKey = "selectedLogbookCards"
    private let selectedAircraftTypeKey = "selectedAircraftType"
    private let maxHoursConfigKey = "recentActivityMaxHours"
    private let averageMetricConfigKey = "averageMetricConfig"
    private let isCompactViewKey = "isCompactView"

    var selectedCards: [StatCardType] = []
    var selectedAircraftType: String = ""
    var maxHoursConfig: [String: Double] = [:]
    var averageMetricConfig: [String: String] = [:] // Keys: "aircraftType", "timePeriod", "metricType"
    var isCompactView: Bool = false // true = 1 column, false = 2 columns (on iPhone)

    private init() {
        loadSettings()
    }

    func loadSettings() {
        if let savedData = userDefaults.data(forKey: selectedCardsKey),
           let savedCards = try? JSONDecoder().decode([String].self, from: savedData) {
            selectedCards = savedCards.compactMap { StatCardType(rawValue: $0) }
        } else {
            // Default selection
            selectedCards = [.totalTime, .nightTime, .aircraftTypeTime, .pfRecency, .recentActivity28, .recentActivity7, ]
        }

        // Load selected aircraft type
        selectedAircraftType = userDefaults.string(forKey: selectedAircraftTypeKey) ?? ""

        // Load max hours configuration
        if let savedMaxHours = userDefaults.dictionary(forKey: maxHoursConfigKey) as? [String: Double] {
            maxHoursConfig = savedMaxHours
        } else {
            // Default max hours for each card
            maxHoursConfig = [
                "recentActivity7": 0,
                "recentActivity28": 100,
                "recentActivity30": 100,
                "recentActivity365": 1000
            ]
        }

        // Load average metric configuration
        if let savedConfig = userDefaults.dictionary(forKey: averageMetricConfigKey) as? [String: String] {
            averageMetricConfig = savedConfig
        } else {
            // Default configuration
            averageMetricConfig = [
                "aircraftType": "", // All aircraft
                "timePeriod": "28", // 28 days
                "metricType": "hours", // hours
                "comparisonPeriod": "" // Entire logbook (empty = all time)
            ]
        }

        // Load compact view preference
        isCompactView = userDefaults.bool(forKey: isCompactViewKey)
    }

    func saveSettings() {
        let cardRawValues = selectedCards.map { $0.rawValue }
        if let encoded = try? JSONEncoder().encode(cardRawValues) {
            userDefaults.set(encoded, forKey: selectedCardsKey)
        }

        // Save selected aircraft type
        userDefaults.set(selectedAircraftType, forKey: selectedAircraftTypeKey)

        // Save max hours configuration
        userDefaults.set(maxHoursConfig, forKey: maxHoursConfigKey)

        // Save average metric configuration
        userDefaults.set(averageMetricConfig, forKey: averageMetricConfigKey)

        // Save compact view preference
        userDefaults.set(isCompactView, forKey: isCompactViewKey)
    }

    func toggleCard(_ card: StatCardType) {
        if selectedCards.contains(card) {
            selectedCards.removeAll { $0 == card }
        } else {
            selectedCards.append(card)
        }
        saveSettings()
    }

    func addCard(_ card: StatCardType) {
        guard !selectedCards.contains(card) else { return }
        selectedCards.append(card)
        saveSettings()
    }

    func moveCard(from source: IndexSet, to destination: Int) {
        selectedCards.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }

    func removeCards(at indexSet: IndexSet) {
        selectedCards.remove(atOffsets: indexSet)
        saveSettings()
    }

    func removeCard(_ card: StatCardType) {
        selectedCards.removeAll { $0 == card }
        saveSettings()
    }

    func setMaxHours(for key: String, value: Double) {
        maxHoursConfig[key] = value
        saveSettings()
    }

    func toggleCompactView() {
        isCompactView.toggle()
        saveSettings()
    }
}
