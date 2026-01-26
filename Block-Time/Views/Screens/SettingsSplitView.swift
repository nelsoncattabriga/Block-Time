//
//  SettingsSplitView.swift
//  Block-Time
//
//  Created for iPad split-view Settings experience
//  Displays Settings categories on the left, detail view on the right
//

import SwiftUI

struct SettingsSplitView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var frmsViewModel: FRMSViewModel
    @State private var selectedCategory: SettingsCategory? = .crew
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    // Determine if we should use split view based on device and size class
    private var shouldUseSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        if shouldUseSplitView {
            // iPad landscape: Split view
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Left pane: Settings categories list
                SettingsCategoriesListContent(
                    selectedCategory: $selectedCategory,
                    viewModel: viewModel
                )
                .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 450)
            } detail: {
                // Right pane: Category detail view
                NavigationStack {
                    if let category = selectedCategory {
                        categoryDetailView(for: category)
                    } else {
                        // Empty state
                        EmptySettingsDetailView()
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Force sidebar to show when app becomes active
                if newPhase == .active && shouldUseSplitView {
                    columnVisibility = .doubleColumn
                }
            }
        } else {
            // iPhone or iPad portrait: Standard navigation stack
            NavigationStack {
                SettingsView(viewModel: viewModel, frmsViewModel: frmsViewModel)
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
        case .about:
            AboutView()
        }
    }
}

// MARK: - Settings Categories List Content (Extracted for reuse)
private struct SettingsCategoriesListContent: View {
    @Binding var selectedCategory: SettingsCategory?
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        List(selection: $selectedCategory) {
            ForEach(SettingsCategory.allCases, id: \.self) { category in
                HStack(spacing: 0) {
                    
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.rawValue)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(category.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: category.icon)
                            .foregroundColor(category.color)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(category.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.leading, 8)
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 6, bottom: 16, trailing: 6))
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedCategory == category ? category.color.opacity(0.1) : Color.clear)
                        .padding(.vertical, 2)
                        .padding(.leading, 4)
                )
                .tag(category)
            }
        }
        .onChange(of: selectedCategory) { oldValue, newValue in
            if newValue != nil {
                HapticManager.shared.impact(.light)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Empty Settings Detail View
private struct EmptySettingsDetailView: View {
    @ObservedObject private var themeService = ThemeService.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            Text("Select a Setting")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Choose a category from the sidebar")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            themeService.getGradient()
                .ignoresSafeArea()
        )
    }
}

#Preview {
    SettingsSplitView(viewModel: FlightTimeExtractorViewModel(), frmsViewModel: FRMSViewModel())
}
