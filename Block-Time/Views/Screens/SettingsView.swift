// Views/Screens/SettingsView.swift - Master-Detail Settings Design
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Category Enum
enum SettingsCategory: String, CaseIterable, Identifiable {
    case crew = "Crew Settings"
    case flightInfo = "Flight Information"
    case frms = "FRMS"
    case backups = "Backup & Sync"
    case importExport = "Import & Export"
    case appearance = "Appearance"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .appearance: return "moonphase.first.quarter"
        case .crew: return "person.2.fill"
        case .flightInfo: return "scribble.variable"
        case .frms: return "clock.badge.exclamationmark"
        case .backups: return "arrow.clockwise.icloud"
        case .importExport: return "arrow.up.arrow.down.circle"
        case .about: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .appearance: return .red
        case .crew: return .blue
        case .flightInfo: return .orange
        case .frms: return .green
        case .backups: return .blue
        case .importExport: return .indigo
        case .about: return .orange
        }
    }

    var subtitle: String {
        switch self {
        case .appearance: return "Display Themes and Colours"
        case .crew: return "Default Crew Settings"
        case .flightInfo: return "Flight Data Formatting"
        case .frms: return "Fatigue Risk Management System"
        case .backups: return "iCloud Sync & Backups"
        case .importExport: return "Import & Export Data"
        case .about: return "App Version & Developer Info"
        }
    }
}

// MARK: - Main Settings View (iPhone/Portrait iPad)
struct SettingsView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var frmsViewModel: FRMSViewModel
    @ObservedObject private var themeService = ThemeService.shared

    var body: some View {
        ZStack {
            themeService.getGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(SettingsCategory.allCases) { category in
                        NavigationLink(destination: categoryDetailView(for: category)) {
                            HStack(spacing: 16) {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                    .background(category.color.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.rawValue)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    Text(category.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(.thinMaterial)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func categoryDetailView(for category: SettingsCategory) -> some View {
        switch category {
        case .appearance:
            AppearanceSettingsView()
        case .crew:
            PersonalCrewSettingsView(viewModel: viewModel)
        case .flightInfo:
            FlightInformationSettingsView(viewModel: viewModel)
        case .frms:
            FRMSSettingsDetailView(viewModel: viewModel, frmsViewModel: frmsViewModel)
        case .backups:
            BackupsView(viewModel: viewModel)
        case .importExport:
            ImportExportView(viewModel: viewModel)
        case .about:
            AboutView()
        }
    }
}

// MARK: - Appearance Settings Detail View
struct AppearanceSettingsView: View {
    @ObservedObject private var themeService = ThemeService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Combined Appearance & Theme Card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(.red)
                            .font(.title3)

                        Text("Appearance")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Spacer()
                    }

                    VStack(spacing: 12) {
                        // Appearance Picker
                        HStack(spacing: 12) {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundColor(.red)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Light/Dark Theme")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(themeService.appearanceMode.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Picker("", selection: Binding(
                                get: { themeService.appearanceMode },
                                set: { themeService.setAppearanceMode($0) }
                            )) {
                                ForEach(AppearanceMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(12)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(8)

                        // Colour Theme Picker
                        HStack(spacing: 12) {
                            Image(systemName: themeService.currentTheme.icon)
                                .foregroundColor(.red)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Colour Theme")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(themeService.currentTheme.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Picker("", selection: Binding(
                                get: { themeService.currentTheme },
                                set: { themeService.setTheme($0) }
                            )) {
                                ForEach(AppTheme.allCases) { theme in
                                    Text(theme.displayName).tag(theme)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(12)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(.thinMaterial)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Personal & Crew Settings Detail View
struct PersonalCrewSettingsView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject private var themeService = ThemeService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ModernDefaultCrewNamesCard(viewModel: viewModel)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Crew Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Flight Information Settings Detail View
struct FlightInformationSettingsView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject private var themeService = ThemeService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ModernFormatOptionsCard(viewModel: viewModel)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Flight Information")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FRMS Settings Detail View
struct FRMSSettingsDetailView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var frmsViewModel: FRMSViewModel
    @ObservedObject private var themeService = ThemeService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ModernFRMSCard(viewModel: frmsViewModel)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("FRMS")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Modern Settings Cards (Existing Components)

private struct ModernDefaultCrewNamesCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Crew Info")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                // Flight Time Position Picker
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log Flight Time As")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.flightTimePosition },
                        set: { viewModel.updateFlightTimePosition($0) }
                    )) {
                        ForEach(FlightTimePosition.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // F/O PF Time Credit Picker (only show when F/O is selected)
                if viewModel.flightTimePosition == .firstOfficer {
                    HStack(spacing: 12) {
                        Image(systemName: "airplane.circle")
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log PF time as")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

//                            Text(viewModel.foPilotFlyingCredit == .p1us ? "ICUS" : "P2")
//                                .font(.caption)
//                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { viewModel.foPilotFlyingCredit },
                            set: { viewModel.updateFOPilotFlyingCredit($0) }
                        )) {
                            Text("ICUS").tag(TimeCreditType.p1us)
                            Text("P2").tag(TimeCreditType.p2)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }

                // Default Name Field
                switch viewModel.flightTimePosition {
                case .captain:
                    ModernTextFieldRow(
                        label: "Default Captain Name",
                        text: Binding(
                            get: { viewModel.defaultCaptainName },
                            set: { viewModel.updateDefaultCaptainName($0) }
                        ),
                        placeholder: "Enter default captain name",
                        icon: "person.badge.shield.checkmark"
                    )

                case .firstOfficer:
                    ModernTextFieldRow(
                        label: "Default F/O Name",
                        text: Binding(
                            get: { viewModel.defaultCoPilotName },
                            set: { viewModel.updateDefaultCoPilotName($0) }
                        ),
                        placeholder: "Enter default F/O name",
                        icon: "person.badge.clock"
                    )

                case .secondOfficer:
                    ModernTextFieldRow(
                        label: "Default S/O Name",
                        text: Binding(
                            get: { viewModel.defaultSOName },
                            set: { viewModel.updateDefaultSOName($0) }
                        ),
                        placeholder: "Enter default S/O name",
                        icon: "person.badge.key"
                    )
                }

                Divider()
                    .padding(.horizontal, 8)

                ModernToggleRow(
                    title: "Log S/O Names",
                    subtitle: "Show S/O Name Fields",
                    isOn: Binding(
                        get: { viewModel.showSONameFields },
                        set: { viewModel.updateShowSONameFields($0) }
                    ),
                    color: .blue,
                    icon: "person.2.badge.key"
                )
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct ModernFormatOptionsCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "scribble.variable")
                    .foregroundColor(.orange)
                    .font(.title3)

                Text("Flight Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {

                // Fleet Selector
                ModernFleetSelectorRow(viewModel: viewModel)

                ModernToggleRow(
                    title: "Long A/C Registration",
                    subtitle: "VH-ABC vs ABC",
                    isOn: Binding(
                        get: { viewModel.showFullAircraftReg },
                        set: { viewModel.updateShowFullAircraftReg($0) }
                    ),
                    color: .orange,
                    icon: "airplane"
                )

                Divider()
                    .padding(.horizontal, 8)

                ModernToggleRow(
                    title: "Leading Zeros in Flt No",
                    subtitle: "0405 vs 405",
                    isOn: Binding(
                        get: { viewModel.includeLeadingZeroInFlightNumber },
                        set: { viewModel.updateIncludeLeadingZeroInFlightNumber($0) }
                    ),
                    color: .orange,
                    icon: "number"
                )

                // Airport ID Picker
                HStack(spacing: 12) {
                    Image(systemName: "airplane.circle")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Airport Code")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.useIATACodes ? "IATA - BNE" : "ICAO - YBBN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.useIATACodes },
                        set: { viewModel.updateUseIATACodes($0) }
                    )) {
                        Text("ICAO").tag(false)
                        Text("IATA").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)


                // Show Times In Picker
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dates & Times")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.displayFlightsInLocalTime ? "Local Time" : "UTC")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.displayFlightsInLocalTime },
                        set: { viewModel.updateDisplayFlightsInLocalTime($0) }
                    )) {
                        Text("UTC").tag(false)
                        Text("Local").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // Flight Times Format Picker
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flight Times")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.showTimesInHoursMinutes },
                        set: { viewModel.updateShowTimesInHoursMinutes($0) }
                    )) {
                        Text("Decimal").tag(false)
                        Text("Hrs:Min").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // Rounding Picker (only show when Decimal mode is selected)
                if !viewModel.showTimesInHoursMinutes {
                    HStack(spacing: 12) {
                        Image(systemName: "number")
                            .foregroundColor(.orange)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rounding")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text(roundingExampleText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { viewModel.decimalRoundingMode },
                            set: { viewModel.updateDecimalRoundingMode($0) }
                        )) {
                            ForEach(RoundingMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }

                ModernAirlinePrefixRow(
                    isEnabled: Binding(
                        get: { viewModel.includeAirlinePrefixInFlightNumber },
                        set: { viewModel.updateIncludeAirlinePrefixInFlightNumber($0) }
                    ),
                    prefix: Binding(
                        get: { viewModel.airlinePrefix },
                        set: { viewModel.updateAirlinePrefix($0) }
                    ),
                    isCustomSelected: Binding(
                        get: { viewModel.isCustomAirlinePrefix },
                        set: { viewModel.updateIsCustomAirlinePrefix($0) }
                    ),
                    color: .orange
                )

                Divider()
                    .padding(.horizontal, 8)

                // Instrument Time when PF
                HStack {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inst Time when PF")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("\(viewModel.pfAutoInstrumentMinutes) minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.pfAutoInstrumentMinutes },
                        set: { viewModel.updatePFAutoInstrumentMinutes($0) }
                    )) {
                        Text("None").tag(0)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("60 min").tag(60)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                Divider()
                    .padding(.horizontal, 8)

                // Log Approaches Toggle
                ModernToggleRow(
                    title: "Log Approaches",
                    subtitle: "ILS,GLS, AIII...",
                    isOn: Binding(
                        get: { viewModel.logApproaches },
                        set: { viewModel.updateLogApproaches($0) }
                    ),
                    color: .orange,
                    icon: "airplane.arrival"
                )

                // Default Approach Type Picker (only show when Log Approaches is enabled)
                if viewModel.logApproaches {
                    HStack {
                        Image(systemName: "location.north.line")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Approach")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text(viewModel.defaultApproachType ?? "Nil")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { viewModel.defaultApproachType },
                            set: { viewModel.updateDefaultApproachType($0) }
                        )) {
                            Text("Nil").tag(nil as String?)
                            Text("ILS").tag("ILS" as String?)
                            Text("GLS").tag("GLS" as String?)
                            Text("RNP").tag("RNP" as String?)
                            Text("AIII").tag("AIII" as String?)
                            Text("NPA").tag("NPA" as String?)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }

            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    // Computed property for rounding mode examples
    private var roundingExampleText: String {
        switch viewModel.decimalRoundingMode {
        case .standard:
            return "Round to Nearest"
        case .roundUp:
            return "Always Ruund Up"
        case .roundDown:
            return "Always Round Down"
        }
    }
}

struct ModernPhotoBackupCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "photo.badge.arrow.down")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Photo Backup")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            ModernToggleRow(
                title: "Save ACARS to Photos",
                subtitle: "Backup photos",
                isOn: Binding(
                    get: { viewModel.savePhotosToLibrary },
                    set: { viewModel.updateSavePhotosToLibrary($0) }
                ),
                color: .blue,
                icon: "photo.on.rectangle.angled"
            )
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}


private struct ModernDataImportCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @State private var showingFilePicker = false
    @State private var showingMappingSheet = false
    @State private var importData: ImportData?
    @State private var showingDeleteWarning = false
    @State private var showingDeleteResult = false
    @State private var deleteResultMessage = ""
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var showingExportSheet = false
    @State private var exportCSVData: URL?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(.red)
                    .font(.title3)

                Text("Logbook Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Importing…")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("Please wait...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }

                if isExporting {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exporting…")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("Please wait...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }

                Button(action: {
                    showingFilePicker = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Logbook Data")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text("CSV or Tab-Delimited file")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(16)
                    .background(Color.green.opacity(0.7))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: [UTType.commaSeparatedText, UTType.tabSeparatedText, UTType.plainText],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let files):
                        if let fileURL = files.first {
                            parseImportFile(fileURL)
                        }
                    case .failure(let error):
                        importResultMessage = "Error selecting file: \(error.localizedDescription)"
                        showingImportResult = true
                    }
                }
                .sheet(item: $importData) { data in
                    ImportMappingView(importData: data) { mappings, mode, regMappings in
                        performImport(data: data, mappings: mappings, mode: mode, registrationMappings: regMappings)
                    }
                }

                // Export Logbook Data Button
                Button(action: {
                    exportLogbookData()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Backup Logbook")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text("Save as CSV file")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .background(
                    Group {
                        if let fileURL = exportCSVData {
                            ShareSheetWrapper(isPresented: $showingExportSheet, items: [fileURL])
                        }
                    }
                )

                // Delete All Logbook Data Button
                Button(action: {
                    showingDeleteWarning = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete All Logbook Data")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text("This cannot be undone")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.7))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .alert("Delete All Logbook Data", isPresented: $showingDeleteWarning) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        let success = FlightDatabaseService.shared.clearAllFlights()
                        if success {
                            deleteResultMessage = "All flights have been deleted."
                        } else {
                            deleteResultMessage = "Failed to delete flights. Please try again."
                        }
                        showingDeleteResult = true
                    }
                } message: {
                    Text("This will permanently delete all data.")
                }
                .alert("Delete Logbook", isPresented: $showingDeleteResult) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(deleteResultMessage)
                }
                .alert("Import Complete", isPresented: $showingImportResult) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(importResultMessage)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helper Functions
    private func parseImportFile(_ url: URL) {
        do {
            let parsedData = try FileImportService.shared.parseFile(url: url)
            importData = parsedData
            showingMappingSheet = true
        } catch {
            importResultMessage = "Error parsing file: \(error.localizedDescription)"
            showingImportResult = true
        }
    }

    private func performImport(data: ImportData, mappings: [FieldMapping], mode: ImportMode, registrationMappings: [RegistrationTypeMapping]) {
        isImporting = true

        FileImportService.shared.importFlights(from: data, mapping: mappings, mode: mode, registrationMappings: registrationMappings) { result in
            isImporting = false

            switch result {
            case .success(let importResult):
                var message = "Import Summary\n\n"
                message += "✓ Successfully imported: \(importResult.successCount) flights\n"

                if importResult.duplicateCount > 0 {
                    message += "⊘ Skipped (already exists): \(importResult.duplicateCount) flights\n"
                }

                if importResult.failureCount > 0 {
                    message += "Failed to import: \(importResult.failureCount) flights\n\n"
                    message += "Failure Details:\n\n"

                    // Show failure breakdown
                    for (reason, count) in importResult.failureReasons.sorted(by: { $0.value > $1.value }) {
                        message += "• \(reason): \(count) occurrence(s)\n"
                    }

                    // Show sample failures
                    if !importResult.sampleFailures.isEmpty {
                        message += "\nSample Failures (first 5):\n"
                        for (row, reason) in importResult.sampleFailures.prefix(5) {
                            message += "  Row \(row): \(reason)\n"
                        }
                    }
                } else if importResult.duplicateCount == 0 {
                    message += "\n✓ All flights imported successfully with no errors!"
                }

                importResultMessage = message
                // Database service observers will automatically post debounced .flightDataChanged notification

                // Reload saved crew names after import
                viewModel.reloadSavedCrewNames()

            case .failure(let error):
                importResultMessage = "Import failed: \(error.localizedDescription)"
            }

            showingImportResult = true
        }
    }

    // MARK: - Export Functions
    private func exportLogbookData() {
        isExporting = true

        // Small delay to show the progress indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let flights = FlightDatabaseService.shared.fetchAllFlights()

            if flights.isEmpty {
                isExporting = false
                importResultMessage = "No flights to export. Your logbook is empty."
                showingImportResult = true
                return
            }

            // Sort by date (oldest first for export)
            let sortedFlights = flights.sorted { flight1, flight2 in
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                if let date1 = formatter.date(from: flight1.date),
                   let date2 = formatter.date(from: flight2.date) {
                    return date1 < date2
                }
                return flight1.date < flight2.date
            }

            let csvString = FileImportService.shared.exportToCSV(flights: sortedFlights)

            // Create the CSV file
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
            let timestamp = dateFormatter.string(from: Date())
            let fileName = "Logbook_Export_\(timestamp).csv"

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                isExporting = false
                exportCSVData = fileURL
                showingExportSheet = true
            } catch {
                isExporting = false
                importResultMessage = "Error creating export file: \(error.localizedDescription)"
                showingImportResult = true
            }
        }
    }
}

// MARK: - Modern Component Helpers

private struct ModernTextFieldRow: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.subheadline)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Airline Picker Sheet
private struct AirlinePickerSheet: View {
    @Binding var selectedPrefix: String
    @Binding var isCustomSelected: Bool
    @Binding var customPrefix: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Airline")) {
                    ForEach(Airline.airlines) { airline in
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            if airline.id == "CUSTOM" {
                                isCustomSelected = true
                                // Keep existing custom prefix if available
                                if customPrefix.isEmpty && !selectedPrefix.isEmpty {
                                    customPrefix = selectedPrefix
                                }
                            } else {
                                isCustomSelected = false
                                selectedPrefix = airline.prefix
                                customPrefix = ""
                            }
                            onDismiss()
                            dismiss()
                        }) {
                            HStack {
                                if !airline.iconName.isEmpty {
                                    Image(airline.iconName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 20)
                                } else {
                                    Image(systemName: "pencil.circle")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                        .frame(width: 20, height: 20)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(airline.name)
                                        .font(.body)
                                        .foregroundColor(.primary)

                                    if !airline.prefix.isEmpty {
                                        Text("Prefix: \(airline.prefix)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Enter your own prefix")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if airline.id == "CUSTOM" && isCustomSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                } else if selectedPrefix == airline.prefix && !isCustomSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Select Airline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ModernToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: color))
                .scaleEffect(0.9)
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

private struct ModernAirlinePrefixRow: View {
    @Binding var isEnabled: Bool
    @Binding var prefix: String
    @Binding var isCustomSelected: Bool
    let color: Color
    @State private var showingAirlinePicker = false
    @State private var customPrefix: String = ""

    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                if isEnabled {
                    showingAirlinePicker = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .foregroundColor(color)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Airline Prefix")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(isEnabled ? "\(prefix)405 vs 405" : "QF405 vs 405")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isEnabled {
                        HStack(spacing: 8) {
                            // Show airline icon if available and not custom
                            if let airline = Airline.getAirline(byPrefix: prefix), !isCustomSelected {
                                Image(airline.iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 16)
                            }

                            Text(isCustomSelected ? "Custom" : prefix)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: color))
                        .scaleEffect(0.9)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            // Show custom text field if custom is selected
            if isEnabled && isCustomSelected {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .foregroundColor(color)
                        .frame(width: 20)

                    TextField("Enter custom prefix", text: $customPrefix)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .onChange(of: customPrefix) { _, newValue in
                            prefix = newValue.uppercased()
                        }
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingAirlinePicker) {
            AirlinePickerSheet(
                selectedPrefix: $prefix,
                isCustomSelected: $isCustomSelected,
                customPrefix: $customPrefix,
                onDismiss: { showingAirlinePicker = false }
            )
        }
        .onAppear {
            // Initialize customPrefix if custom is selected
            if isCustomSelected && customPrefix.isEmpty {
                customPrefix = prefix
            }
        }
    }
}

// MARK: - Share Sheet Wrapper
struct ShareSheetWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let items: [Any]

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

            // Configure for iPad (popover)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = uiViewController.view
                popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX,
                                           y: uiViewController.view.bounds.midY,
                                           width: 0,
                                           height: 0)
                popover.permittedArrowDirections = []
            }

            activityVC.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                var topController = rootVC
                while let presented = topController.presentedViewController {
                    topController = presented
                }

                if topController.presentedViewController == nil {
                    topController.present(activityVC, animated: true)
                }
            }
        }
    }
}

// MARK: - Fleet Selector Row
private struct ModernFleetSelectorRow: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @StateObject private var fleetService = AircraftFleetService.shared
    @State private var availableFleets: [Fleet] = []
    @State private var selectedFleet: Fleet?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .foregroundColor(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fleet Selection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { viewModel.selectedFleetID },
                set: { newFleetID in
                    viewModel.updateSelectedFleetID(newFleetID)
                    selectedFleet = availableFleets.first(where: { $0.id == newFleetID })
                    HapticManager.shared.impact(.light)
                }
            )) {
                ForEach(availableFleets.sorted { $0.name < $1.name }, id: \.id) { fleet in
                    Text(fleet.name).tag(fleet.id)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
        .onAppear {
            loadFleets()
        }
    }

    private func loadFleets() {
        availableFleets = fleetService.getAvailableFleetsWithCustom()
        if selectedFleet == nil {
            selectedFleet = availableFleets.first(where: { $0.id == viewModel.selectedFleetID }) ?? availableFleets.first
        }
    }
}

// MARK: - FRMS Card
private struct ModernFRMSCard: View {
    @ObservedObject var viewModel: FRMSViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.green)
                    .font(.title3)

                Text("FRMS Configuration")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                // Fleet Picker
                    HStack(spacing: 12) {
                    Image(systemName: "airplane.departure")
                        .foregroundColor(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fleet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.configuration.fleet.fullDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $viewModel.configuration.fleet) {
                        ForEach(FRMSFleet.allCases, id: \.self) { fleet in
                            Text(fleet.shortName).tag(fleet)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.configuration.fleet) { _, _ in
                        viewModel.configuration.updateSignOffForFleet()
                    }
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // Home Base Picker
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home Base")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.configuration.homeBase)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $viewModel.configuration.homeBase) {
                        Text("SYD").tag("SYD")
                        Text("MEL").tag("MEL")
                        Text("BNE").tag("BNE")
                        Text("ADL").tag("ADL")
                        Text("PER").tag("PER")
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // Default Limits removed - always using operational limits
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - CloudKit Sync Card
struct ModernCloudKitSyncCard: View {
    @ObservedObject var databaseService = FlightDatabaseService.shared
    @ObservedObject var settingsService = CloudKitSettingsSyncService.shared
    @AppStorage("debugModeEnabled") private var debugModeEnabled = false

    @State private var showUUIDRegenerationAlert = false
    @State private var uuidRegenerationMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("iCloud Sync Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                // Debug mode indicator
                if debugModeEnabled {
                    Text("DEBUG")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if !settingsService.isCloudAvailable() {
                // iCloud not available message
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("iCloud Not Available")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Sign in to iCloud in Settings to sync your data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    // Database sync status
                    syncDetailRow(
                        title: "Flight Database",
                        icon: "airplane",
                        isSyncing: databaseService.isSyncing,
                        lastSync: databaseService.lastSyncDate,
                        lastChange: nil,
                        error: databaseService.lastSyncError
                    )

                    // Settings sync status
                    syncDetailRow(
                        title: "Settings",
                        icon: "gearshape",
                        isSyncing: settingsService.isSyncing,
                        lastSync: settingsService.lastSyncDate,
                        lastChange: settingsService.lastChangeDate,
                        error: settingsService.lastSyncError
                    )

//                    Divider()
//                        .padding(.horizontal, -4)
//
//                    // Info
//                    Text("Data will sync via iCloud automatically.")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                        .padding(.top, 4)

                    // Debug buttons (only visible when Debug Mode is enabled)
                    if debugModeEnabled {
                        Divider()
                            .padding(.horizontal, -4)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug: Error Simulation")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)

                            HStack(spacing: 8) {
                                Button(action: {
                                    databaseService.simulatePartialSyncFailure()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                        Text("Partial")
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)

                                Button(action: {
                                    databaseService.simulateNetworkError()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "wifi.slash")
                                            .font(.caption)
                                        Text("Network")
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)

                                Button(action: {
                                    databaseService.clearSimulatedErrors()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                        Text("Clear")
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)
                            }
                        }
                        .padding(.top, 4)

                        // Database Maintenance
                        Divider()
                            .padding(.horizontal, -4)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug: Database Maintenance")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)

                            Button(action: {
                                let result = databaseService.regenerateAllFlightUUIDs()
                                print("UUID Regeneration: Updated \(result.updatedCount) flights, removed \(result.duplicatesRemoved) duplicates")

                                // Build message with duplicate details
                                var message = "Updated \(result.updatedCount) flights\nRemoved \(result.duplicatesRemoved) duplicates"

                                if !result.duplicatesList.isEmpty {
                                    message += "\n\nDuplicates removed:"
                                    for duplicate in result.duplicatesList.prefix(10) {
                                        message += "\n• \(duplicate)"
                                    }
                                    if result.duplicatesList.count > 10 {
                                        message += "\n... and \(result.duplicatesList.count - 10) more"
                                    }
                                }

                                uuidRegenerationMessage = message
                                showUUIDRegenerationAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                    Text("Regenerate UUIDs & Remove Duplicates")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .alert("UUID Regeneration Complete", isPresented: $showUUIDRegenerationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uuidRegenerationMessage)
        }
    }

    @ViewBuilder
    private func syncDetailRow(title: String, icon: String, isSyncing: Bool, lastSync: Date?, lastChange: Date? = nil, error: Error?) -> some View {
        SyncDetailRowView(title: title, icon: icon, isSyncing: isSyncing, lastSync: lastSync, lastChange: lastChange, error: error, detailedSyncError: databaseService.detailedSyncError)
    }
}

// MARK: - Sync Detail Row with Expandable Error Details
private struct SyncDetailRowView: View {
    let title: String
    let icon: String
    let isSyncing: Bool
    let lastSync: Date?
    let lastChange: Date?
    let error: Error?
    let detailedSyncError: DetailedSyncError?

    @State private var showErrorDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let error = error {
                let errorInfo = CloudKitErrorHelper.userFriendlyMessage(for: error)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: errorInfo.isRetryable ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(errorInfo.isRetryable ? .orange : .red)
                            .font(.caption)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(errorInfo.message)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(errorInfo.isRetryable ? .orange : .red)

                            Text(errorInfo.suggestion)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Always show technical details button if we have detailed error information
                    if let detailedError = detailedSyncError {
                        Button(action: {
                            withAnimation {
                                showErrorDetails.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(showErrorDetails ? "Hide Technical Details" : "Show Technical Details")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                Image(systemName: showErrorDetails ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 2)

                        // Expandable error details
                        if showErrorDetails {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider()
                                    .padding(.vertical, 2)

                                // Show individual errors if available
                                if detailedError.hasIndividualErrors {
                                    Text("Failed Items (\(detailedError.individualErrors.count))")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)

                                    ForEach(Array(detailedError.individualErrors.enumerated()), id: \.offset) { index, errorItem in
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Record: \(errorItem.recordID)")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)

                                            let itemErrorInfo = CloudKitErrorHelper.userFriendlyMessage(for: errorItem.error)
                                        Text(itemErrorInfo.message)
                                            .font(.caption2)
                                            .foregroundColor(itemErrorInfo.isRetryable ? .orange : .red)

                                        Text(itemErrorInfo.suggestion)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.vertical, 3)

                                    if index < detailedError.individualErrors.count - 1 {
                                        Divider()
                                    }
                                }

                                    Divider()
                                        .padding(.vertical, 4)
                                }

                                // Always show technical error details
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Technical Details")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)

                                    Group {
                                        HStack(alignment: .top) {
                                            Text("Error Domain:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text(detailedError.errorDomain)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }

                                        HStack(alignment: .top) {
                                            Text("Error Code:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text("\(detailedError.errorCode)")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }

                                        HStack(alignment: .top) {
                                            Text("Operation:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text(detailedError.operation)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }

                                        HStack(alignment: .top) {
                                            Text("Timestamp:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text(detailedError.timestamp.formatted(date: .numeric, time: .standard))
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }

                                        HStack(alignment: .top) {
                                            Text("Description:")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            Text(errorInfo.suggestion)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Spacer()
                                        }

                                        // Show userInfo if available
                                        if !detailedError.errorUserInfo.isEmpty {
                                            Divider()
                                                .padding(.vertical, 2)

                                            Text("Additional Info:")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)

                                            ForEach(Array(detailedError.errorUserInfo.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                                HStack(alignment: .top) {
                                                    Text("\(key):")
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 100, alignment: .leading)
                                                    Text(value)
                                                        .font(.system(.caption2, design: .monospaced))
                                                        .foregroundColor(.primary)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(6)
                .background(errorInfo.isRetryable ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(4)
            } else if let date = lastSync {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("Last synced \(date.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let changeDate = lastChange, changeDate != date {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption2)
                            Text("Last changed \(changeDate.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                    Text("Not yet synced")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(6)
    }
}
