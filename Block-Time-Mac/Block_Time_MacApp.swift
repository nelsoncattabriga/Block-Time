//
//  Block_Time_MacApp.swift
//  Block-Time-Mac
//

import SwiftUI

@main
struct Block_Time_MacApp: App {
    @AppStorage("macAppearance") private var appearanceRaw: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch appearanceRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .preferredColorScheme(preferredColorScheme)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Flight") {
                    NotificationCenter.default.post(name: .macNewFlight, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            TabView {
                Tab("Crew & Ops", systemImage: "person.2.fill") {
                    MacCrewSettingsView()
                }
                Tab("Flight Info", systemImage: "scribble.variable") {
                    MacFlightInfoSettingsView()
                }
                Tab("FRMS", systemImage: "clock.badge.exclamationmark") {
                    MacFRMSSettingsView()
                }
                Tab("Appearance", systemImage: "moonphase.first.quarter") {
                    MacAppearanceSettingsView()
                }
            }
            .frame(width: 520, height: 480)
        }
    }
}

extension Notification.Name {
    static let macNewFlight = Notification.Name("macNewFlight")
}
