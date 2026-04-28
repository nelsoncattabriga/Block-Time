//
//  WidgetConfigurationIntent.swift
//  BlockTimeWidget
//
//  AppIntent providing user-configurable style and appearance options
//  for the Block-Time widget.
//

import AppIntents
import WidgetKit

// MARK: - Display mode option

enum WidgetDisplayModeOption: String, AppEnum {
    case flightInfo
    case countdown

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [WidgetDisplayModeOption: DisplayRepresentation] = [
        .flightInfo: "Flight Info",
        .countdown:  "Countdown",
    ]
}

// MARK: - Style option

enum WidgetStyleOption: String, AppEnum {
    case gradient
    case solid

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Style")
    static var caseDisplayRepresentations: [WidgetStyleOption: DisplayRepresentation] = [
        .gradient: "Gradient",
        .solid:    "Solid",
    ]
}

// MARK: - Time zone option

enum WidgetTimeZoneOption: String, AppEnum {
    case utc
    case local

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Times")
    static var caseDisplayRepresentations: [WidgetTimeZoneOption: DisplayRepresentation] = [
        .utc:   "UTC (Z)",
        .local: "Local",
    ]
}

// MARK: - Appearance option

enum WidgetAppearanceOption: String, AppEnum {
    case automatic
    case light
    case dark

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Appearance")
    static var caseDisplayRepresentations: [WidgetAppearanceOption: DisplayRepresentation] = [
        .automatic: "Automatic",
        .light:     "Light",
        .dark:      "Dark",
    ]
}

// MARK: - Configuration intent

struct NextFlightIntent: AppIntents.WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Settings"
    static var description = IntentDescription("Customise the widget appearance.")

    @Parameter(title: "Display", default: .flightInfo)
    var displayMode: WidgetDisplayModeOption

    @Parameter(title: "Style", default: .gradient)
    var style: WidgetStyleOption

    /// Only shown when Style = Solid. Gradient always uses Automatic.
    @Parameter(title: "Appearance", default: .automatic)
    var appearance: WidgetAppearanceOption

    @Parameter(title: "Times", default: .utc)
    var timeZone: WidgetTimeZoneOption

    static var parameterSummary: some ParameterSummary {
        When(\NextFlightIntent.$displayMode, .equalTo, .flightInfo) {
            When(\NextFlightIntent.$style, .equalTo, .solid) {
                Summary {
                    \NextFlightIntent.$displayMode
                    \NextFlightIntent.$style
                    \NextFlightIntent.$appearance
                    \NextFlightIntent.$timeZone
                }
            } otherwise: {
                Summary {
                    \NextFlightIntent.$displayMode
                    \NextFlightIntent.$style
                    \NextFlightIntent.$timeZone
                }
            }
        } otherwise: {
            // Countdown mode
            When(\NextFlightIntent.$style, .equalTo, .solid) {
                Summary {
                    \NextFlightIntent.$displayMode
                    \NextFlightIntent.$style
                    \NextFlightIntent.$appearance
                    \NextFlightIntent.$timeZone
                }
            } otherwise: {
                Summary {
                    \NextFlightIntent.$displayMode
                    \NextFlightIntent.$style
                    \NextFlightIntent.$timeZone
                }
            }
        }
    }

    /// Resolved appearance — gradient always follows system.
    var resolvedAppearance: WidgetAppearanceOption {
        style == .gradient ? .automatic : appearance
    }
}
