// AddFlightView.swift
// Nelson

import SwiftUI
import PhotosUI

struct AddFlightView: View {
    @Environment(ThemeService.self) private var themeService
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessNotification = false
    @State private var successMessage = ""

    private var isInSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {

            ScrollViewReader { scrollProxy in
                ScrollView {
                    if horizontalSizeClass == .regular {
                        WideLayoutView(viewModel: viewModel, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage)
                            .id("top")
                    } else {
                        CompactLayoutView(viewModel: viewModel, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage)
                            .id("top")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(
                    ZStack {
                        themeService.getGradient()
                            .ignoresSafeArea()
                    }
                )
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { _ in
                    withAnimation {
                        scrollProxy.scrollTo("top", anchor: .top)
                    }
                }
            }
            .navigationTitle(viewModel.isEditingMode ? "Edit Flight" : "Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if !viewModel.isEditingMode && !isInSplitView {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCamera) {
                CameraView(onImageSelected: viewModel.handleCameraImage)
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $viewModel.showingSegmentSelection) {
                FlightSegmentSelectionSheet(
                    flightSegments: viewModel.flightSegments,
                    onSelect: { segment in
                        viewModel.populateFieldsWithFlightData(segment)
                        viewModel.statusMessage = "Flight data retrieved successfully!"
                        viewModel.statusColor = .green
                        HapticManager.shared.notification(.success)
                    },
                    onDismiss: {
                        viewModel.showingSegmentSelection = false
                    }
                )
            }
            .onChange(of: viewModel.selectedPhotoItem) { _, item in
                viewModel.loadSelectedPhoto()
            }
            .overlay(alignment: .top) {
                if showSuccessNotification {
                    SuccessNotificationBanner(message: successMessage)
                        .padding(.top, 50)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                }
            }
            .overlay {
                if viewModel.isFetchingFlightAware {
                    FlightAwareLookupProgressView()
                }
            }
            .onAppear {
                viewModel.setupInitialData()
            }
        }
    }

// MARK: - Modern Compact Layout
private struct CompactLayoutView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Binding var showSuccessNotification: Bool
    @Binding var successMessage: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingDiscardAlert = false
    @State private var showingDeleteAlert = false
    @AppStorage("selectedFleetID") private var selectedFleetID: String = "B737"

    // Check if we're in iPad split view mode
    private var isInSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
            LazyVStack(spacing: 16) {
                // Photo Capture Card - show for supported fleets in both add and edit mode
                if selectedFleetID == "B737" || selectedFleetID == "A330" || selectedFleetID == "B787" {
                    ModernPhotoCaptureCard(viewModel: viewModel, fleetType: selectedFleetID)
                }

                // Captured Data Card
                ModernCapturedDataCard(viewModel: viewModel)

                // Manual Entry Card
                ModernManualEntryDataCard(viewModel: viewModel)

                // Action Buttons Card
                ModernActionButtonsCard(viewModel: viewModel, showingDeleteAlert: $showingDeleteAlert, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage)

                // Bottom spacer
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarBackButtonHidden(viewModel.isEditingMode)
            .toolbar {
                // Only show back button when editing AND not in split view
                if viewModel.isEditingMode && !isInSplitView {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            if viewModel.hasUnsavedChanges {
                                showingDiscardAlert = true
                            } else {
                                viewModel.exitEditingMode()
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").imageScale(.medium)
                                Text("Flights")
                            }
                        }
                    }
                }
            }
            .alert("Save Changes?", isPresented: $showingDiscardAlert) {
                Button("Save", role: .none) {
                    if viewModel.updateExistingFlight() {
                        viewModel.exitEditingMode()
                        dismiss()
                    }
                }
                Button("Discard", role: .destructive) {
                    viewModel.exitEditingMode()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(viewModel.changesSummary)
            }
            .alert("Delete Flight?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if viewModel.deleteCurrentFlight() {
                        viewModel.exitEditingMode()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

// MARK: Wide Layout View
private struct WideLayoutView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Binding var showSuccessNotification: Bool
    @Binding var successMessage: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingDiscardAlert = false
    @State private var showingDeleteAlert = false
    @AppStorage("selectedFleetID") private var selectedFleetID: String = "B737"

    // Check if we're in iPad split view mode
    private var isInSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {

                        // Photo Capture Card - show for supported fleets in both add and edit mode
                        if selectedFleetID == "B737" || selectedFleetID == "A330" || selectedFleetID == "B787" {
                            ModernPhotoCaptureCard(viewModel: viewModel, fleetType: selectedFleetID)
                        }

                        // Captured Data Card
                        ModernCapturedDataCard(viewModel: viewModel)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 16) {

                        // Manual Entry Card
                        ModernManualEntryDataCard(viewModel: viewModel)

                        // Action Buttons Card
                        ModernActionButtonsCard(viewModel: viewModel, showingDeleteAlert: $showingDeleteAlert, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(viewModel.isEditingMode)
        .toolbar {
            // Only show back button when editing AND not in split view
            if viewModel.isEditingMode && !isInSplitView {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        if viewModel.hasUnsavedChanges {
                            showingDiscardAlert = true
                        } else {
                            viewModel.exitEditingMode()
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Flights")
                        }
                    }
                }
            }
        }
        .alert("Save Changes?", isPresented: $showingDiscardAlert) {
            Button("Save", role: .none) {
                if viewModel.updateExistingFlight() {
                    viewModel.exitEditingMode()
                    dismiss()
                }
            }
            Button("Discard", role: .destructive) {
                viewModel.exitEditingMode()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(viewModel.changesSummary)
        }
        .alert("Delete Flight?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if viewModel.deleteCurrentFlight() {
                    viewModel.exitEditingMode()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}
