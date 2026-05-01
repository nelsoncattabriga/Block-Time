//
//  MacSettingsView.swift
//  Block-Time-Mac
//
//  Native macOS settings using Form(.grouped).
//  Reads/writes the same UserDefaults keys as the iOS app so settings
//  are shared across the same device and can be synced in future.
//

import SwiftUI

struct MacSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MacFlightInfoSettingsSection()
                MacFRMSSettingsSection()
                MacAppearanceSettingsSection()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Settings")
    }
}

// MARK: - Flight Information

private struct MacFlightInfoSettingsSection: View {
    @AppStorage("includeAirlinePrefixInFlightNumber") private var includePrefix: Bool = true
    @AppStorage("airlinePrefix")                      private var airlinePrefix: String = "QF"
    @AppStorage("includeLeadingZeroInFlightNumber")   private var leadingZero: Bool = false

    var body: some View {
        Form {
            Section("Flight Information") {
                Toggle("Include Airline Prefix", isOn: $includePrefix)
                if includePrefix {
                    TextField("Airline Prefix", text: $airlinePrefix)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: airlinePrefix) { _, v in
                            airlinePrefix = v.uppercased()
                        }
                }
                Toggle("Leading Zeros in Flight No. (QF0405)", isOn: $leadingZero)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - FRMS

private struct MacFRMSSettingsSection: View {
    @State private var fleet: String = "A320/B737"
    @State private var homeBase: String = "SYD"
    @State private var signOnMinutes: Int = 60
    @State private var signOffMinutes: Int = 30

    private let frmsKey = "FRMSConfiguration"

    var body: some View {
        Form {
            Section("FRMS") {
                Picker("Fleet", selection: $fleet) {
                    Text("Shorthaul (A320/B737)").tag("A320/B737")
                    Text("Longhaul (A380/A330/B787)").tag("A380/A330/B787")
                }
                .onChange(of: fleet) { _, _ in save() }

                Picker("Home Base", selection: $homeBase) {
                    Text("SYD").tag("SYD")
                    Text("MEL").tag("MEL")
                    Text("BNE").tag("BNE")
                    Text("ADL").tag("ADL")
                    Text("PER").tag("PER")
                }
                .onChange(of: homeBase) { _, _ in save() }

                Stepper("Sign-on: \(signOnMinutes) min before STD", value: $signOnMinutes, in: 0...120, step: 5)
                    .onChange(of: signOnMinutes) { _, _ in save() }

                Stepper("Sign-off: \(signOffMinutes) min after IN", value: $signOffMinutes, in: 0...120, step: 5)
                    .onChange(of: signOffMinutes) { _, _ in save() }
            }
        }
        .formStyle(.grouped)
        .onAppear { load() }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: frmsKey),
              let config = try? JSONDecoder().decode(FRMSConfigSnapshot.self, from: data) else { return }
        fleet         = config.fleet
        homeBase      = config.homeBase
        signOnMinutes = config.signOnMinutesBeforeSTD
        signOffMinutes = config.signOffMinutesAfterIN
    }

    private func save() {
        let snapshot = FRMSConfigSnapshot(
            fleet: fleet,
            homeBase: homeBase,
            signOnMinutesBeforeSTD: signOnMinutes,
            signOffMinutesAfterIN: signOffMinutes
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: frmsKey)
        }
    }
}

// Minimal codable snapshot matching the keys FRMSConfiguration uses
private struct FRMSConfigSnapshot: Codable {
    var fleet: String
    var homeBase: String
    var signOnMinutesBeforeSTD: Int
    var signOffMinutesAfterIN: Int
}

// MARK: - Appearance

private struct MacAppearanceSettingsSection: View {
    @AppStorage("macAppearance") private var appearanceRaw: String = "system"

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearanceRaw) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
        }
        .formStyle(.grouped)
    }
}
