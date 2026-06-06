// Views/Screens/SettingsView.swift - Master-Detail Settings Design
import SwiftUI

// MARK: - Settings Category Enum
enum SettingsCategory: String, CaseIterable, Identifiable {
    case crew = "Crew & Ops Data"
    case flightInfo = "Flight Information"
    case frms = "FRMS"
    case backups = "Backup & Sync"
    case importExport = "Import & Export"
    case appearance = "Appearance"
    case userGuide = "User Guide"
    case about = "Support"

    var id: String { rawValue }

    enum Section: String {
        case configure = "Configure"
        case data = "Data"
        case other = "Help"
    }

    var section: Section {
        switch self {
        case .crew, .flightInfo, .frms, .appearance: return .configure
        case .importExport, .backups: return .data
        case .userGuide, .about: return .other
        }
    }

    static var configureCases: [SettingsCategory] { allCases.filter { $0.section == .configure } }
    static var dataCases: [SettingsCategory] { allCases.filter { $0.section == .data } }
    static var otherCases: [SettingsCategory] { allCases.filter { $0.section == .other } }

    var icon: String {
        switch self {
        case .appearance: return "moonphase.first.quarter"
        case .crew: return "person.2.fill"
        case .flightInfo: return "scribble.variable"
        case .frms: return "clock.badge.exclamationmark"
        case .backups: return "arrow.clockwise.icloud"
        case .importExport: return "arrow.up.arrow.down.circle"
        case .userGuide: return "book.fill"
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
        case .userGuide: return .teal
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
        case .userGuide: return "How to use Block-Time"
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

                    settingsSection(title: "Configure", categories: SettingsCategory.configureCases)
                    settingsSection(title: "Data", categories: SettingsCategory.dataCases)
                    settingsSection(title: "Help", categories: SettingsCategory.otherCases)

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
    private func settingsSection(title: String, categories: [SettingsCategory]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(categories) { category in
                    NavigationLink(destination: categoryDetailView(for: category)) {
                        HStack(spacing: 16) {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                                .font(.title3)
                                .frame(width: 32, height: 32)
                                .background(category.color.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.rawValue)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text(category.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
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
        case .userGuide:
            UserGuideView()
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
                // Appearance & Theme Card
                VStack(spacing: 16) {
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

