// Views/Screens/SettingsView.swift - Master-Detail Settings Design
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Category Enum
enum SettingsCategory: String, CaseIterable, Identifiable {
    case crew = "Crew & Ops Data"
    case flightInfo = "Flight Information"
    case frms = "FRMS"
    case backups = "Backup & Sync"
    case importExport = "Import & Export"
    case appearance = "Appearance"
    case about = "Support"

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
        case .crew: return "Crew Defaults & Operations"
        case .flightInfo: return "Flight Data Formatting"
        case .frms: return "Fatigue Risk Management System"
        case .backups: return "iCloud Sync & Backups"
        case .importExport: return "Import & Export Data"
        case .about: return "App Version & Support Links"
        }
    }
}

// MARK: - Main Settings View (iPhone/Portrait iPad)
struct SettingsView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var frmsViewModel: FRMSViewModel
    @Environment(ThemeService.self) private var themeService
    @Environment(PurchaseService.self) private var purchaseService
    @State private var navigateToBackups = false

    var body: some View {
        ZStack {
            themeService.getGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if !purchaseService.isPro {
                        TrialStatusCard()
                    }

                    BackupNudgeBannerView(navigateToBackups: $navigateToBackups)

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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToBackupSettings)) { _ in
            navigateToBackups = true
        }
        .navigationDestination(isPresented: $navigateToBackups) {
            BackupsView(viewModel: viewModel)
        }
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
            SupportView()
        }
    }
}

// MARK: - Appearance Settings Detail View
struct AppearanceSettingsView: View {
    @Environment(ThemeService.self) private var themeService

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
    @Environment(ThemeService.self) private var themeService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ModernDefaultCrewNamesCard(viewModel: viewModel)
                ModernOpsDataCard(viewModel: viewModel)
                ModernCrewNotesCard()
                ModernCustomFieldsCard()

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
        .navigationTitle("Crew & Ops Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Flight Information Settings Detail View
struct FlightInformationSettingsView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Environment(ThemeService.self) private var themeService

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
                        icon: "person"
                    )

                case .firstOfficer:
                    ModernTextFieldRow(
                        label: "Default F/O Name",
                        text: Binding(
                            get: { viewModel.defaultCoPilotName },
                            set: { viewModel.updateDefaultCoPilotName($0) }
                        ),
                        placeholder: "Enter default F/O name",
                        icon: "person"
                    )

                case .secondOfficer:
                    ModernTextFieldRow(
                        label: "Default S/O Name",
                        text: Binding(
                            get: { viewModel.defaultSOName },
                            set: { viewModel.updateDefaultSOName($0) }
                        ),
                        placeholder: "Enter default S/O name",
                        icon: "person"
                    )
                }

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                
                ModernToggleRow(
                    title: "Log S/O Names",
                    subtitle: "Show S/O Name Fields",
                    isOn: Binding(
                        get: { viewModel.showSONameFields },
                        set: { viewModel.updateShowSONameFields($0) }
                    ),
                    color: .blue,
                    icon: "person.2"
                )
                
                
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                ModernToggleRow(
                    title: "Log Instructor Time",
                    subtitle: "Log Trainer / Instructor Time",
                    isOn: Binding(
                        get: { viewModel.showSpInsSelector },
                        set: { viewModel.updateShowSpInsSelector($0) }
                    ),
                    color: .blue,
                    icon: "person.wave.2"
                )

                if viewModel.showSpInsSelector {
                    instructionEnvironmentPicker
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
    }

    @ViewBuilder
    private var instructionEnvironmentPicker: some View {
        let caption: String = viewModel.defaultInstructionEnvironment == .simulator
            ? "Sim instruction hours counted separately from SIM time."
            : "Aircraft instruction hours counted as P1 time by default."
        VStack(alignment: .leading, spacing: 6) {
            Text("Default instruction environment")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                ForEach([InstructionEnvironment.aircraft, .simulator], id: \.self) { env in
                    instructionEnvButton(env: env)
                }
            }
            .padding(3)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )

            Text(caption)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func instructionEnvButton(env: InstructionEnvironment) -> some View {
        let isSelected = viewModel.defaultInstructionEnvironment == env
        let icon = env == .simulator ? "desktopcomputer" : "airplane"
        let label = env == .simulator ? "Simulator" : "Aircraft"
        let activeColor: Color = env == .simulator ? .purple : .blue
        return Button {
            viewModel.updateDefaultInstructionEnvironment(env)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.footnote.bold())
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? activeColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ModernOpsDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Operations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                
                // Instrument Time when PF
                HStack {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .foregroundColor(.blue)
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
                    .padding(.vertical, 4)
                
                // Log Approaches Toggle
                ModernToggleRow(
                    title: "Log Approaches",
                    subtitle: "ILS, GLS, AIII...",
                    isOn: Binding(
                        get: { viewModel.logApproaches },
                        set: { viewModel.updateLogApproaches($0) }
                    ),
                    color: .blue,
                    icon: "airplane.arrival"
                )
                
                // Default Approach Type Picker (only show when Log Approaches is enabled)
                if viewModel.logApproaches {
                    HStack {
                        Image(systemName: "location.north.line")
                            .foregroundColor(.blue)
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
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct ModernCustomFieldsCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Custom Fields")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            InlineCustomFieldsView()
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

private struct ModernCrewNotesCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(.blue)
                    .font(.title3)

                Text("Crew Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()
            }

            NavigationLink(destination: CrewNotesManageView()) {
                HStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(.blue)
                        .frame(width: 20)

                    Text("Edit Notes")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 12))
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

                
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                
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
                
                
                ModernToggleRow(
                    title: "Full A/C Registration",
                    subtitle: "VH-ABC vs ABC",
                    isOn: Binding(
                        get: { viewModel.showFullAircraftReg },
                        set: { viewModel.updateShowFullAircraftReg($0) }
                    ),
                    color: .orange,
                    icon: "airplane"
                )


                ModernToggleRow(
                    title: "Leading Zeros in Flt No",
                    subtitle: "QF0405 vs QF405",
                    isOn: Binding(
                        get: { viewModel.includeLeadingZeroInFlightNumber },
                        set: { viewModel.updateIncludeLeadingZeroInFlightNumber($0) }
                    ),
                    color: .orange,
                    icon: "number"
                )

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                
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

                
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                // Enter Times In Local Time toggle
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Times Entered In")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.enterTimesInLocalTime ? "Enter times in LOCAL time" : "Enter times in UTC")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.enterTimesInLocalTime },
                        set: { viewModel.updateEnterTimesInLocalTime($0) }
                    )) {
                        Text("UTC").tag(false)
                        Text("Local").tag(true)
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
                        Text("Times Shown In")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.displayFlightsInLocalTime ? "Date & Times in Local Time" : "Date & Times in UTC")
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

                Divider()
                
                ModernToggleRow(
                    title: "Count SIM in Total",
                    subtitle: "Include SIM time in Total Time",
                    isOn: Binding(
                        get: { viewModel.countSimInTotal },
                        set: { viewModel.updateCountSimInTotal($0) }
                    ),
                    color: .orange,
                    icon: "desktopcomputer"
                )

                ModernToggleRow(
                    title: "Show OUT/IN Times",
                    subtitle: "Shows times in Logbook view",
                    isOn: Binding(
                        get: { viewModel.showOutInTimes },
                        set: { viewModel.updateShowOutInTimes($0) }
                    ),
                    color: .orange,
                    icon: "clock"
                )
               
                Divider()
                
                // Flight Times Format Picker
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block Times In")
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
                            Text("Decimal Rounding")
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
            return "03:57 Displays as 4.0"
        case .alternate:
            return "03:57 Displays as 3.9"
        }
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
                    ImportMappingView(importData: data) { mappings, mode, regMappings, timesAreLocal in
                        performImport(data: data, mappings: mappings, mode: mode, registrationMappings: regMappings, timesAreLocal: timesAreLocal)
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
                        FlightDatabaseService.shared.suspendUndoForBatchImport()
                        let success = FlightDatabaseService.shared.clearAllFlights()
                        FlightDatabaseService.shared.resumeUndoAfterBatchImport()
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

    private func performImport(data: ImportData, mappings: [FieldMapping], mode: ImportMode, registrationMappings: [RegistrationTypeMapping], timesAreLocal: Bool = false) {
        isImporting = true

        FileImportService.shared.importFlights(from: data, mapping: mappings, mode: mode, registrationMappings: registrationMappings, timesAreLocal: timesAreLocal) { result in
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

// MARK: - Airline Picker Sheet
private struct AirlinePickerSheet: View {
    @Binding var selectedPrefix: String
    @Binding var isCustomSelected: Bool
    @Binding var customPrefix: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .topBarTrailing) {
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


// MARK: - Fleet Selector Row
private struct ModernFleetSelectorRow: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
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
        availableFleets = AircraftFleetService.availableFleets.filter { !$0.aircraft.isEmpty }
        if selectedFleet == nil {
            if let match = availableFleets.first(where: { $0.id == viewModel.selectedFleetID }) {
                selectedFleet = match
            } else {
                selectedFleet = availableFleets.first
                if let fallback = availableFleets.first {
                    viewModel.updateSelectedFleetID(fallback.id)
                }
            }
        }
    }
}

