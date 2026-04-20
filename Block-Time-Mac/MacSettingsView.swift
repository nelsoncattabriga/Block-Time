//
//  MacSettingsView.swift
//  Block-Time-Mac
//

import SwiftUI

struct MacSettingsView: View {
    @AppStorage("macAppearance") private var appearanceRaw: String = "system"

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearanceRaw) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
