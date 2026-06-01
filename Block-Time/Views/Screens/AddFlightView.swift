// AddFlightView.swift
// Nelson

import SwiftUI
import PhotosUI

struct AddFlightView: View {
    @Environment(ThemeService.self) private var themeService
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hidePhotoCapture) private var hidePhotoCapture
    @State private var showSuccessNotification = false
    @State private var successMessage = ""
    @State private var keyboardToolbar = KeyboardToolbarState()

    private var isInSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {

            GeometryReader { geometry in
                // Use horizontal size class instead of hardcoded width
                let useWideLayout = (horizontalSizeClass == .regular && geometry.size.width > 700) || geometry.size.width > 900

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        if useWideLayout {
                            WideLayoutView(viewModel: viewModel, keyboardToolbar: keyboardToolbar, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage, hidePhotoCapture: hidePhotoCapture)
                                .id("top")
                        } else {
                            CompactLayoutView(viewModel: viewModel, keyboardToolbar: keyboardToolbar, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage, hidePhotoCapture: hidePhotoCapture)
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
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            if keyboardToolbar.isAnyFieldFocused {
                                Button("Clear") {
                                    keyboardToolbar.onClear?()
                                }
                                .foregroundColor(.red)
                                Spacer()
                                Button("Done") {
                                    UIApplication.shared.sendAction(
                                        #selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil
                                    )
                                    keyboardToolbar.isAnyFieldFocused = false
                                }
                                .font(.subheadline.bold())
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isEditingMode ? "Edit Flight" : "Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if !viewModel.isEditingMode && !isInSplitView {
                    ToolbarItem(placement: .navigationBarLeading) {
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
            .alert("Capture Not Complete", isPresented: $viewModel.showingCaptureError) {
                Button("Try Again") {
                    viewModel.showingCamera = true
                }
                Button("Enter Manually", role: .cancel) { }
            } message: {
                Text(viewModel.captureErrorMessage)
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
                if AppState.shared.triggerCamera {
                    AppState.shared.triggerCamera = false
                    viewModel.showCamera()
                }
            }
        }
    }

// MARK: - Modern Compact Layout
private struct CompactLayoutView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var keyboardToolbar: KeyboardToolbarState
    @Binding var showSuccessNotification: Bool
    @Binding var successMessage: String
    var hidePhotoCapture: Bool
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
                if !hidePhotoCapture && (selectedFleetID == "B737" || selectedFleetID == "A330" || selectedFleetID == "B787" || selectedFleetID == "A320" || selectedFleetID == "A380") {
                    ModernPhotoCaptureCard(viewModel: viewModel, fleetType: selectedFleetID)
                }

                // Captured Data Card
                ModernCapturedDataCard(viewModel: viewModel, keyboardToolbar: keyboardToolbar)

                // Manual Entry Card
                ModernManualEntryDataCard(viewModel: viewModel, keyboardToolbar: keyboardToolbar)

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
                    ToolbarItem(placement: .navigationBarLeading) {
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
                Text("This will permanently delete this flight entry.")
            }
        }
    }

// MARK: Wide Layout View
private struct WideLayoutView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var keyboardToolbar: KeyboardToolbarState
    @Binding var showSuccessNotification: Bool
    @Binding var successMessage: String
    var hidePhotoCapture: Bool
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
                        if !hidePhotoCapture && (selectedFleetID == "B737" || selectedFleetID == "A330" || selectedFleetID == "B787" || selectedFleetID == "A320" || selectedFleetID == "A380") {
                            ModernPhotoCaptureCard(viewModel: viewModel, fleetType: selectedFleetID)
                        }

                        // Captured Data Card
                        ModernCapturedDataCard(viewModel: viewModel, keyboardToolbar: keyboardToolbar)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 16) {

                        // Manual Entry Card
                        ModernManualEntryDataCard(viewModel: viewModel, keyboardToolbar: keyboardToolbar)

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
                ToolbarItem(placement: .navigationBarLeading) {
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
            Text("This will permanently delete this flight entry.")
        }
    }
}
