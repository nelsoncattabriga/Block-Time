//
//  WidgetConfigurationIntent.swift
//  BlockTimeWidget
//
//  AppIntent providing user-configurable style and appearance options
//  for the Block-Time widget.
//

import AppIntents
import WidgetKit

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

    @Parameter(title: "Style", default: .gradient)
    var style: WidgetStyleOption

    /// Only shown when Style = Solid. Gradient always uses Automatic.
    @Parameter(title: "Appearance", default: .automatic)
    var appearance: WidgetAppearanceOption

    static var parameterSummary: some ParameterSummary {
        When(\NextFlightIntent.$style, .equalTo, .solid) {
            Summary {
                \NextFlightIntent.$style
                \NextFlightIntent.$appearance
            }
        } otherwise: {
            Summary {
                \NextFlightIntent.$style
            }
        }
    }

    /// Resolved appearance — gradient always follows system.
    var resolvedAppearance: WidgetAppearanceOption {
        style == .gradient ? .automatic : appearance
    }
}
