//
//  ThemeService.swift
//  Block-Time
//
//  Created by Nelson on 10/9/2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Appearance Mode Enum
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "Auto"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var displayName: String {
        return rawValue
    }
}

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable, Identifiable {
    case defaultTheme = "Sunrise"
    case clearSky = "Sky"
    case ocean = "Ocean"
    case forest = "Forest"
    case midnight = "Midnight"

    var id: String { rawValue }

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .defaultTheme:
            return "paintpalette"
        case .clearSky:
            return "sun.max.fill"
        case .ocean:
            return "water.waves"
        case .forest:
            return "tree.fill"
        case .midnight:
            return "moon.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .defaultTheme:
            return [Color.blue.opacity(0.4), Color.orange.opacity(0.35)]
        case .clearSky:
            return [Color(red: 0.5, green: 0.8, blue: 1.0).opacity(0.4),
                    Color.blue.opacity(0.35)]
        case .ocean:
            return [Color(red: 0.2, green: 0.6, blue: 0.7).opacity(0.4),
                    Color(red: 0.1, green: 0.3, blue: 0.6).opacity(0.35)]
        case .forest:
            return [Color(red: 0.2, green: 0.6, blue: 0.4).opacity(0.4),
                    Color(red: 0.2, green: 0.5, blue: 0.6).opacity(0.35)]
        case .midnight:
            return [Color(red: 0.1, green: 0.2, blue: 0.4).opacity(0.5),
                    Color(red: 0.2, green: 0.2, blue: 0.5).opacity(0.4)]
        }
    }

    var description: String {
        switch self {
        case .defaultTheme:
            return "Sunrise blues & orange"
        case .clearSky:
            return "Bright daytime"
        case .ocean:
            return "Calm waters"
        case .forest:
            return "Natural greens"
        case .midnight:
            return "Darker tones"
        }
    }
}

// MARK: - Theme Service
class ThemeService: ObservableObject {
    static let shared = ThemeService()

    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    private init() {
        // Load saved theme
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .defaultTheme
        }

        // Load appearance mode preference
        // Migrate from old isDarkMode boolean to new AppearanceMode enum
        if let savedMode = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.appearanceMode = mode
        } else if UserDefaults.standard.object(forKey: "isDarkMode") != nil {
            // Migrate from old boolean setting
            let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
            self.appearanceMode = isDarkMode ? .dark : .light
            UserDefaults.standard.removeObject(forKey: "isDarkMode")
        } else {
            // Default to system
            self.appearanceMode = .system
        }
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        HapticManager.shared.impact(.light)
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        HapticManager.shared.impact(.light)
    }

    func getGradient() -> LinearGradient {
        return LinearGradient(
            gradient: Gradient(colors: currentTheme.gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
