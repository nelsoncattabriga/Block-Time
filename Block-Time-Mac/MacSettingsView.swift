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
                MacCrewSettingsSection()
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

// MARK: - Crew & Ops

private struct MacCrewSettingsSection: View {
    @AppStorage("flightTimePosition")       private var flightTimePosition: String = "Captain"
    @AppStorage("foPilotFlyingCredit")      private var foPilotFlyingCredit: String = "P1S"
    @AppStorage("defaultCaptainName")       private var defaultCaptainName: String = ""
    @AppStorage("defaultCoPilotName")       private var defaultCoPilotName: String = ""
    @AppStorage("defaultSOName")            private var defaultSOName: String = ""
    @AppStorage("showSONameFields")         private var showSONameFields: Bool = false
    @AppStorage("showSpInsSelector")        private var showSpInsSelector: Bool = false
    @AppStorage("defaultInstructionEnvironment") private var defaultInstructionEnv: String = "aircraft"
    @AppStorage("pfAutoInstrumentMinutes")  private var pfAutoInstrumentMinutes: Int = 0
    @AppStorage("logApproaches")            private var logApproaches: Bool = true
    @AppStorage("defaultApproachType")      private var defaultApproachType: String = ""
    @AppStorage("logCustomCount")           private var logCustomCount: Bool = false
    @AppStorage("customCountLabel")         private var customCountLabel: String = "Custom"

    private var positionLabel: String {
        switch flightTimePosition {
        case "FirstOfficer": return "First Officer"
        case "SecondOfficer": return "Second Officer"
        default: return "Captain"
        }
    }

    var body: some View {
        Form {
            Section("Crew") {
                Picker("Log Flight Time As", selection: $flightTimePosition) {
                    Text("Captain").tag("Captain")
                    Text("First Officer").tag("FirstOfficer")
                    Text("Second Officer").tag("SecondOfficer")
                }

                if flightTimePosition == "FirstOfficer" {
                    Picker("Log PF Time As", selection: $foPilotFlyingCredit) {
                        Text("ICUS").tag("P1S")
                        Text("P2").tag("P2")
                    }
                }

                switch flightTimePosition {
                case "FirstOfficer":
                    LabeledContent("Default F/O Name") {
                        TextField("Name", text: $defaultCoPilotName)
                            .multilineTextAlignment(.trailing)
                    }
                case "SecondOfficer":
                    LabeledContent("Default S/O Name") {
                        TextField("Name", text: $defaultSOName)
                            .multilineTextAlignment(.trailing)
                    }
                default:
                    LabeledContent("Default Captain Name") {
                        TextField("Name", text: $defaultCaptainName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Toggle("Log S/O Names", isOn: $showSONameFields)
                Toggle("Log Instructor Time", isOn: $showSpInsSelector)

                if showSpInsSelector {
                    Picker("Default Instruction Env", selection: $defaultInstructionEnv) {
                        Text("Aircraft").tag("aircraft")
                        Text("Simulator").tag("simulator")
                    }
                }
            }

            Section("Operations") {
                Picker("Inst. Time When PF", selection: $pfAutoInstrumentMinutes) {
                    Text("None").tag(0)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("45 min").tag(45)
                    Text("60 min").tag(60)
                }

                Toggle("Log Approaches", isOn: $logApproaches)

                if logApproaches {
                    Picker("Default Approach", selection: $defaultApproachType) {
                        Text("None").tag("")
                        Text("ILS").tag("ILS")
                        Text("GLS").tag("GLS")
                        Text("RNP").tag("RNP")
                        Text("AIII").tag("AIII")
                        Text("NPA").tag("NPA")
                    }
                }

                Toggle("Use Custom Counter", isOn: $logCustomCount)

                if logCustomCount {
                    LabeledContent("Counter Label") {
                        TextField("e.g. Pax Carried", text: $customCountLabel)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Flight Information

private struct MacFlightInfoSettingsSection: View {
    @AppStorage("includeAirlinePrefixInFlightNumber") private var includePrefix: Bool = true
    @AppStorage("airlinePrefix")                      private var airlinePrefix: String = "QF"
    @AppStorage("showFullAircraftReg")                private var showFullReg: Bool = false
    @AppStorage("includeLeadingZeroInFlightNumber")   private var leadingZero: Bool = false
    @AppStorage("useIATACodes")                       private var useIATA: Bool = true
    @AppStorage("enterTimesInLocalTime")              private var enterTimesInLocalTime: Bool = false
    @AppStorage("displayFlightsInLocalTime")          private var displayInLocalTime: Bool = true
    @AppStorage("countSimInTotal")                    private var countSimInTotal: Bool = false
    @AppStorage("showOutInTimes")                     private var showOutInTimes: Bool = false
    @AppStorage("showTimesInHoursMinutes")            private var timesInHHMM: Bool = true
    @AppStorage("decimalRoundingMode")                private var decimalRoundingMode: String = "standard"

    var body: some View {
        Form {
            Section("Flight Information") {
                Toggle("Include Airline Prefix", isOn: $includePrefix)
                if includePrefix {
                    LabeledContent("Airline Prefix") {
                        TextField("QF", text: $airlinePrefix)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .onChange(of: airlinePrefix) { _, v in
                                airlinePrefix = v.uppercased()
                            }
                    }
                }

                Toggle("Full A/C Registration (VH-ABC)", isOn: $showFullReg)
                Toggle("Leading Zeros in Flight No (QF0405)", isOn: $leadingZero)

                Picker("Airport Code Format", selection: $useIATA) {
                    Text("ICAO (YBBN)").tag(false)
                    Text("IATA (BNE)").tag(true)
                }
            }

            Section("Times") {
                Picker("Times Entered In", selection: $enterTimesInLocalTime) {
                    Text("UTC").tag(false)
                    Text("Local").tag(true)
                }

                if enterTimesInLocalTime {
                    Text("Local time entry requires airport timezone data — UTC entry is recommended until this is fully supported on Mac.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Picker("Times Shown In", selection: $displayInLocalTime) {
                    Text("UTC").tag(false)
                    Text("Local").tag(true)
                }

                Picker("Block Times Format", selection: $timesInHHMM) {
                    Text("Decimal (1.25)").tag(false)
                    Text("HH:MM (1:15)").tag(true)
                }

                if !timesInHHMM {
                    Picker("Decimal Rounding", selection: $decimalRoundingMode) {
                        Text("Standard (3:57 → 4.0)").tag("standard")
                        Text("Alternate (3:57 → 3.9)").tag("alternate")
                    }
                }

                Toggle("Count SIM in Total", isOn: $countSimInTotal)
                Toggle("Show OUT/IN Times", isOn: $showOutInTimes)
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
