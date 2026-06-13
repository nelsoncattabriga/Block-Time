// AddFlightView.swift
// Nelson

import SwiftUI
import PhotosUI

struct AddFlightView: View {
    var onNextSector: (() -> Void)? = nil
    var onNextSectorFromEdit: (() -> Void)? = nil
    @Environment(ThemeService.self) private var themeService
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hidePhotoCapture) private var hidePhotoCapture
    @State private var showSuccessNotification = false
    @State private var successMessage = ""
    @State private var keyboardToolbar = KeyboardToolbarState()
    /// Container width, read via onGeometryChange (NOT GeometryReader, which
    /// re-proposes child size every keyboard-animation frame → relayout hang).
    /// onGeometryChange only fires when the value actually changes.
    @State private var containerWidth: CGFloat = 0

    private var isInSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {

            // Wide layout needs the actual CONTAINER width, not just the size
            // class: on iPad the Add Flight panel can sit in a narrow column
            // (alongside the Logbook) while horizontalSizeClass is still
            // .regular — using the size class alone forced two columns into too
            // little space and overlapped the list. We read width via
            // onGeometryChange (below) instead of GeometryReader, which avoided
            // the per-frame relayout that caused the keyboard-show hang.
            let useWideLayout = (horizontalSizeClass == .regular && containerWidth > 700) || containerWidth > 900

            ScrollViewReader { scrollProxy in
                    ScrollView {
                        if useWideLayout {
                            WideLayoutView(viewModel: viewModel, keyboardToolbar: keyboardToolbar, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage, hidePhotoCapture: hidePhotoCapture, onNextSector: onNextSector, onNextSectorFromEdit: onNextSectorFromEdit)
                                .id("top")
                        } else {
                            CompactLayoutView(viewModel: viewModel, keyboardToolbar: keyboardToolbar, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage, hidePhotoCapture: hidePhotoCapture, onNextSector: onNextSector, onNextSectorFromEdit: onNextSectorFromEdit)
                                .id("top")
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newWidth in
                        containerWidth = newWidth
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
                viewModel.formDidAppear()
                viewModel.setupInitialData()
                if AppState.shared.triggerCamera {
                    AppState.shared.triggerCamera = false
                    viewModel.showCamera()
                }
            }
            .onDisappear {
                viewModel.formDidDisappear()
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
    var onNextSector: (() -> Void)? = nil
    var onNextSectorFromEdit: (() -> Void)? = nil
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
            // VStack (not LazyVStack): only ~4 fixed cards. LazyVStack does
            // incremental measurement passes that re-run under changing size
            // proposals (keyboard animation) for no benefit at this small count.
            VStack(spacing: 16) {
                // Photo Capture Card - show for supported fleets in both add and edit mode
                if !hidePhotoCapture && (selectedFleetID == "B737" || selectedFleetID == "A330" || selectedFleetID == "B787" || selectedFleetID == "A320" || selectedFleetID == "A380") {
                    ModernPhotoCaptureCard(viewModel: viewModel, fleetType: selectedFleetID)
                }

                // Captured Data Card
                ModernCapturedDataCard(viewModel: viewModel, keyboardToolbar: keyboardToolbar)

                // Manual Entry Card
                ModernManualEntryDataCard(viewModel: viewModel, keyboardToolbar: keyboardToolbar)

                // Action Buttons Card
                ModernActionButtonsCard(
                    viewModel: viewModel,
                    showingDeleteAlert: $showingDeleteAlert,
                    showSuccessNotification: $showSuccessNotification,
                    successMessage: $successMessage,
                    onNextSector: {
                        if viewModel.nextSector() {
                            NotificationCenter.default.post(name: .flightAdded, object: nil)
                            onNextSector?()
                            if !isInSplitView { dismiss() }
                        }
                    },
                    onNextSectorFromEdit: {
                        let saveFirst = viewModel.hasUnsavedChanges
                        if viewModel.nextSectorFromEdit(saveFirst: saveFirst) {
                            onNextSectorFromEdit?()
                            if !isInSplitView { dismiss() }
                        }
                    }
                )

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
                Text("This will delete this entry.")
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
    var onNextSector: (() -> Void)? = nil
    var onNextSectorFromEdit: (() -> Void)? = nil
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
                        ModernActionButtonsCard(
                            viewModel: viewModel,
                            showingDeleteAlert: $showingDeleteAlert,
                            showSuccessNotification: $showSuccessNotification,
                            successMessage: $successMessage,
                            onNextSector: {
                                if viewModel.nextSector() {
                                    NotificationCenter.default.post(name: .flightAdded, object: nil)
                                    onNextSector?()
                                    if !isInSplitView { dismiss() }
                                }
                            },
                            onNextSectorFromEdit: {
                                let saveFirst = viewModel.hasUnsavedChanges
                                if viewModel.nextSectorFromEdit(saveFirst: saveFirst) {
                                    onNextSectorFromEdit?()
                                    if !isInSplitView { dismiss() }
                                }
                            }
                        )
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
            Text("This will delete this entry.")
        }
    }
}
