//
//  Block_Time_MacApp.swift
//  Block-Time-Mac
//

import SwiftUI

@main
struct Block_Time_MacApp: App {
    var body: some Scene {
        WindowGroup {
            MacRootView()
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
    }
}

extension Notification.Name {
    static let macNewFlight = Notification.Name("macNewFlight")
}
