// Updated AddFlightView.swift with modern card design

import SwiftUI
import PhotosUI

struct AddFlightView: View {
    @ObservedObject private var themeService = ThemeService.shared
    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingSuccessAlert = false
    @State private var showSuccessNotification = false
    @State private var successMessage = ""

    var body: some View {


            GeometryReader { geometry in
                // Use horizontal size class instead of hardcoded width
                let useWideLayout = (horizontalSizeClass == .regular && geometry.size.width > 700) || geometry.size.width > 900

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        if useWideLayout {
                            WideLayoutView(viewModel: viewModel, showingSuccessAlert: $showingSuccessAlert, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage)
                                .id("top")
                        } else {
                            CompactLayoutView(viewModel: viewModel, showingSuccessAlert: $showingSuccessAlert, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage)
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
            }
            .navigationTitle(viewModel.isEditingMode ? "Edit Flight" : "Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
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
    @Binding var showingSuccessAlert: Bool
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
                // Photo Capture Card - only show when not editing and B737 or B787 fleet is selected
                if !viewModel.isEditingMode && (selectedFleetID == "B737" || selectedFleetID == "B787") {
                    ModernPhotoCaptureCard(viewModel: viewModel, fleetType: selectedFleetID)
                }
                
                // Captured Data Card
                ModernCapturedDataCard(viewModel: viewModel)
                
                // Manual Entry Card
                ModernManualEntryDataCard(viewModel: viewModel)
                
                // Action Buttons Card
                ModernActionButtonsCard(viewModel: viewModel, showingSuccessAlert: $showingSuccessAlert, showingDeleteAlert: $showingDeleteAlert, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage)
                
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

// MARK: Wide Layout View
private struct WideLayoutView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Binding var showingSuccessAlert: Bool
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

                        // Photo Capture Card - only show when not editing and B737 or B787 fleet is selected
                        if !viewModel.isEditingMode && (selectedFleetID == "B737" || selectedFleetID == "B787") {
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
                        ModernActionButtonsCard(viewModel: viewModel, showingSuccessAlert: $showingSuccessAlert, showingDeleteAlert: $showingDeleteAlert, showSuccessNotification: $showSuccessNotification, successMessage: $successMessage)
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
            Text("This action cannot be undone.")
        }
    }
}


// MARK: - Modern Photo Capture Card
private struct ModernPhotoCaptureCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var fleetType: String = "B737"

    private var cardTitle: String {
        fleetType == "B787" ? "Capture 787 Print Out" : "Capture 737 ACARS Data"
    }

    private var cameraButtonTitle: String {
        fleetType == "B787" ? "From PRINTER" : "From ACARS"
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.green)
                    .font(.title3)

                Text(cardTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            HStack(spacing: 12) {
                ModernButton(
                    title: cameraButtonTitle,
                    subtitle: "Camera",
                    icon: "camera",
                    color: .blue,
                    action: viewModel.showCamera
                )
                
                PhotosPicker(selection: $viewModel.selectedPhotoItem) {
                    ModernButtonContent(
                        title: "From Photos",
                        subtitle: "Library",
                        icon: "photo.on.rectangle",
                        color: .purple
                    )
                }
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

// MARK: - FlightAware Helper
extension String {
    /// Converts airline code to FlightAware format (e.g., QF -> QFA)
    static func toFlightAwareAirlineCode(_ code: String) -> String {
        let airlineMappings: [String: String] = [
            "QF": "QFA",
            "QFA": "QFA",  // Already in FlightAware format
            "VA": "VOZ",
            "VOZ": "VOZ",
            "JQ": "JST",
            "JST": "JST",
            "NZ": "ANZ",
            "ANZ": "ANZ",
            "SQ": "SIA",
            "SIA": "SIA",
            "BA": "BAW",
            "BAW": "BAW",
            "QR": "QTR",
            "QTR": "QTR",
            "EK": "UAE",
            "UAE": "UAE",
            "TG": "THA",
            "THA": "THA",
            // Add more mappings as needed
        ]

        return airlineMappings[code.uppercased()] ?? code.uppercased()
    }

    /// Converts a flight number to FlightAware URL format
    /// Handles various formats:
    /// - "QF933" or "QFA933" -> "QFA933"
    /// - "933" (with userAirlinePrefix "QF") -> "QFA933"
    /// - "0933" (with userAirlinePrefix "QF") -> "QFA933"
    func toFlightAwareFormat(userAirlinePrefix: String? = nil) -> String? {
        let cleaned = self.trimmingCharacters(in: .whitespaces).uppercased()

        // Pattern 1: Airline code (2-3 letters) followed by flight number
        let patternWithAirline = "^([A-Z]{2,3})(0?\\d+)$"
        if let regex = try? NSRegularExpression(pattern: patternWithAirline),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let airlineRange = Range(match.range(at: 1), in: cleaned),
           let numberRange = Range(match.range(at: 2), in: cleaned) {

            let airlineCode = String(cleaned[airlineRange])
            var flightNumber = String(cleaned[numberRange])

            // Remove leading zero if present
            if flightNumber.hasPrefix("0") {
                flightNumber = String(flightNumber.dropFirst())
            }

            return String.toFlightAwareAirlineCode(airlineCode) + flightNumber
        }

        // Pattern 2: Just numbers (e.g., "933" or "0933")
        let patternNumberOnly = "^(0?\\d+)$"
        if let regex = try? NSRegularExpression(pattern: patternNumberOnly),
           regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil,
           let userPrefix = userAirlinePrefix, !userPrefix.isEmpty {

            var flightNumber = cleaned

            // Remove leading zero if present
            if flightNumber.hasPrefix("0") {
                flightNumber = String(flightNumber.dropFirst())
            }

            return String.toFlightAwareAirlineCode(userPrefix) + flightNumber
        }

        return nil
    }
}

// MARK: - Modern Captured Data Card
private struct ModernCapturedDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject private var cloudKitService = CloudKitSettingsSyncService.shared

    private var flightNumberPlaceholder: String {
        let baseNumber = "123"
        let leadingZeroNumber = "0123"

        if viewModel.includeAirlinePrefixInFlightNumber {
            if viewModel.includeLeadingZeroInFlightNumber {
                return "\(viewModel.airlinePrefix)\(leadingZeroNumber)"
            } else {
                return "\(viewModel.airlinePrefix)\(baseNumber)"
            }
        } else {
            if viewModel.includeLeadingZeroInFlightNumber {
                return leadingZeroNumber
            } else {
                return baseNumber
            }
        }
    }

    private var flightAwareURL: URL? {
        guard !viewModel.flightNumber.isEmpty,
              let flightAwareCode = viewModel.flightNumber.toFlightAwareFormat(
                userAirlinePrefix: viewModel.includeAirlinePrefixInFlightNumber ? viewModel.airlinePrefix : nil
              ) else {
            return nil
        }
        return URL(string: "https://www.flightaware.com/live/flight/\(flightAwareCode)/history")
    }

    private var canSearchFlight: Bool {
        return flightAwareURL != nil && cloudKitService.isNetworkAvailable && !viewModel.flightDate.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.orange)
                    .font(.title3)

                Text("Flight Info")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 0) {
                    Button(action: {
                        if viewModel.isSimulator || viewModel.isPositioning {
                            viewModel.isSimulator = false
                            viewModel.isPositioning = false
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("FLT")
                            .font(.subheadline.bold())
                            .foregroundColor(!viewModel.isSimulator && !viewModel.isPositioning ? .white : .secondary)
                            .frame(width: 50, height: 30)
                            .background(!viewModel.isSimulator && !viewModel.isPositioning ? Color.blue : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if !viewModel.isPositioning {
                            viewModel.isPositioning = true
                            viewModel.isSimulator = false
                            viewModel.blockTime = ""  // Clear block time for positioning flights
                            viewModel.nightTime = ""  // Clear night time for positioning flights
                            viewModel.aircraftReg = ""  // Clear aircraft reg for positioning flights
                            viewModel.aircraftType = ""  // Clear aircraft type for positioning flights
                            viewModel.captainName = ""  // Clear captain name for positioning flights
                            viewModel.coPilotName = ""  // Clear F/O name for positioning flights
                            viewModel.so1Name = ""  // Clear SO1 name for positioning flights
                            viewModel.so2Name = ""  // Clear SO2 name for positioning flights
                            viewModel.isPilotFlying = false  // Clear PF for positioning flights
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("PAX")
                            .font(.subheadline.bold())
                            .foregroundColor(viewModel.isPositioning ? .white : .secondary)
                            .frame(width: 50, height: 30)
                            .background(viewModel.isPositioning ? Color.orange : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if !viewModel.isSimulator {
                            viewModel.isSimulator = true
                            viewModel.isPositioning = false
                            HapticManager.shared.impact(.light)
                        }
                    }) {
                        Text("SIM")
                            .font(.subheadline.bold())
                            .foregroundColor(viewModel.isSimulator ? .white : .secondary)
                            .frame(width: 50, height: 30)
                            .background(viewModel.isSimulator ? Color.purple : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.isPositioning ? Color.orange : (viewModel.isSimulator ? Color.purple : Color.blue), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(spacing: 12) {
                
                VStack(spacing: 8) {
                    
                    // Date picker
                    ModernDatePickerField(
                        label: "UTC DATE",
                        dateString: $viewModel.flightDate,
                        icon: "calendar",
                        airportCode: viewModel.fromAirport,
                        timeString: viewModel.outTime,
                        showLocalDate: viewModel.displayFlightsInLocalTime,
                        useIATACodes: viewModel.useIATACodes
                    )
                    
                    // Flight Number field with search button
                    ModernFlightNumberField(
                        label: "FLIGHT #",
                        value: Binding(
                            get: { viewModel.flightNumber },
                            set: { viewModel.updateFlightNumber($0) }
                        ),
                        placeholder: flightNumberPlaceholder,
                        icon: "airplane.ticket",
                        isUppercase: true,
                        keyboardType: (UIDevice.current.userInterfaceIdiom == .pad || viewModel.isSimulator) ? .numbersAndPunctuation : .numberPad,
                        canSearch: canSearchFlight,
                        onSearch: {
                            viewModel.fetchFlightAwareData()
                        },
                        onFocus: {
                            // Auto-insert airline prefix when field is tapped if empty
                            // But not for simulator flights (allows custom sim flight numbers like SIM06B)
                            if viewModel.flightNumber.isEmpty &&
                               viewModel.includeAirlinePrefixInFlightNumber &&
                               !viewModel.isSimulator {
                                viewModel.updateFlightNumber(viewModel.airlinePrefix)
                            }
                        }
                    )
                    
                    HStack(spacing: 8) {
                        ModernAirportField(
                            label: "FROM",
                            value: Binding(
                                get: { viewModel.fromAirport },
                                set: { viewModel.fromAirport = $0 }
                            ),
                            icon: "airplane.departure",
                            useIATACodes: viewModel.useIATACodes,
                            recentAirports: viewModel.recentAirports,
                            onAirportSelected: { airport in
                                viewModel.trackAirportUsage(airport)
                            }
                        )

                        ModernAirportField(
                            label: "TO",
                            value: Binding(
                                get: { viewModel.toAirport },
                                set: { viewModel.toAirport = $0 }
                            ),
                            icon: "airplane.arrival",
                            useIATACodes: viewModel.useIATACodes,
                            recentAirports: viewModel.recentAirports,
                            onAirportSelected: { airport in
                                viewModel.trackAirportUsage(airport)
                            }
                        )
                    }
                }
                
                // Flight Times section
                HStack {
                    Text("Flight Times (UTC)")
                        .font(.footnote.bold())
                        .foregroundColor(.primary.opacity(0.8))
                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ModernTimeField(
                            label: "STD",
                            value: Binding(
                                get: { viewModel.scheduledDeparture },
                                set: { viewModel.scheduledDeparture = $0 }
                            ),
                            icon: "calendar.badge.clock",
                            isReadOnly: false,
                            dateString: viewModel.flightDate,
                            airportCode: viewModel.fromAirport,
                            showLocalTime: viewModel.displayFlightsInLocalTime,
                            useIATACodes: viewModel.useIATACodes,
                            onSave: {
                                // No recalculation needed for scheduled times
                            }
                        )

                        ModernTimeField(
                            label: "STA",
                            value: Binding(
                                get: { viewModel.scheduledArrival },
                                set: { viewModel.scheduledArrival = $0 }
                            ),
                            icon: "calendar.badge.clock",
                            isReadOnly: false,
                            dateString: viewModel.flightDate,
                            airportCode: viewModel.toAirport,
                            showLocalTime: viewModel.displayFlightsInLocalTime,
                            useIATACodes: viewModel.useIATACodes,
                            onSave: {
                                // No recalculation needed for scheduled times
                            }
                        )
                    }

                    HStack(spacing: 8) {
                        ModernTimeField(
                            label: "OUT",
                            value: Binding(
                                get: { viewModel.outTime },
                                set: { viewModel.outTime = $0 }
                            ),
                            icon: "clock",
                            isReadOnly: false,
                            dateString: viewModel.flightDate,
                            airportCode: viewModel.fromAirport,
                            showLocalTime: viewModel.displayFlightsInLocalTime,
                            useIATACodes: viewModel.useIATACodes,
                            onSave: { viewModel.recalculateTimesAfterManualEdit() }
                        )

                        ModernTimeField(
                            label: "IN",
                            value: Binding(
                                get: { viewModel.inTime },
                                set: { viewModel.inTime = $0 }
                            ),
                            icon: "clock",
                            isReadOnly: false,
                            dateString: viewModel.flightDate,
                            airportCode: viewModel.toAirport,
                            showLocalTime: viewModel.displayFlightsInLocalTime,
                            useIATACodes: viewModel.useIATACodes,
                            onSave: { viewModel.recalculateTimesAfterManualEdit() }
                        )
                    }
                    
                    HStack{
                        ModernDecimalTimeField(
                            label: viewModel.isSimulator ? "SIM Time" : "BLOCK Time",
                            value: $viewModel.blockTime,
                            icon: viewModel.isSimulator ? "desktopcomputer" : "timer",
                            isReadOnly: viewModel.isPositioning,
                            showAsHHMM: viewModel.showTimesInHoursMinutes
                        )

                        ModernDecimalTimeField(
                            label: "NIGHT Time",
                            value: $viewModel.nightTime,
                            icon: "moon.stars",
                            isReadOnly: viewModel.isPositioning,
                            showAsHHMM: viewModel.showTimesInHoursMinutes
                        )
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
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            //viewModel.updateNightTime()
        }
        .onChange(of: viewModel.outTime) {
            // Only recalculate if not in editing mode and not a PAX flight
            if !viewModel.isEditingMode && !viewModel.isPositioning {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.inTime) {
            // Only recalculate if not in editing mode and not a PAX flight
            if !viewModel.isEditingMode && !viewModel.isPositioning {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.blockTime) {
            // Only recalculate if not in editing mode and not a PAX flight
            if !viewModel.isEditingMode && !viewModel.isPositioning {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.fromAirport) {
            // Recalculate night time when FROM airport changes (important for B787 ACARS)
            if !viewModel.isEditingMode && !viewModel.isPositioning && !viewModel.fromAirport.isEmpty && !viewModel.toAirport.isEmpty {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.toAirport) {
            // Recalculate night time when TO airport changes (important for B787 ACARS)
            if !viewModel.isEditingMode && !viewModel.isPositioning && !viewModel.fromAirport.isEmpty && !viewModel.toAirport.isEmpty {
                viewModel.updateNightTime()
            }
        }
        .onChange(of: viewModel.isPilotFlying) { viewModel.updateTakeoffsLandings() }
    }
}

// MARK: - Modern Manual Entry Data Card
private struct ModernManualEntryDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                    .font(.title3)
                
                Text("Flight Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                
                // Aircraft registration field - disabled for positioning flights
                ModernAircraftRegField(viewModel: viewModel, isDisabled: viewModel.isPositioning)

                // All crew fields on separate lines - disabled for positioning flights
                VStack(spacing: 8) {
                    ModernCrewField(
                        label: "CAPTAIN",
                        value: Binding(
                            get: { viewModel.captainName },
                            set: { viewModel.updateCaptainName($0) }
                        ),
                        savedNames: viewModel.savedCaptainNames,
                        recentNames: viewModel.recentCaptainNames,
                        onNameAdded: viewModel.addCaptainName,
                        onNameRemoved: viewModel.removeCaptainName,
                        icon: "person.badge.shield.checkmark",
                        isDisabled: viewModel.isPositioning
                    )

                    ModernCrewField(
                        label: "F/O",
                        value: Binding(
                            get: { viewModel.coPilotName },
                            set: { viewModel.updateCoPilotName($0) }
                        ),
                        savedNames: viewModel.savedCoPilotNames,
                        recentNames: viewModel.recentCoPilotNames,
                        onNameAdded: viewModel.addCoPilotName,
                        onNameRemoved: viewModel.removeCoPilotName,
                        icon: "person.badge.clock",
                        isDisabled: viewModel.isPositioning
                    )

                    // Conditionally show SO fields
                    if viewModel.showSONameFields {
                        ModernCrewField(
                            label: "S/O 1",
                            value: Binding(
                                get: { viewModel.so1Name },
                                set: { viewModel.updateSO1Name($0) }
                            ),
                            savedNames: viewModel.savedSONames,
                            recentNames: viewModel.recentSONames,
                            onNameAdded: viewModel.addSOName,
                            onNameRemoved: viewModel.removeSOName,
                            icon: "person.badge.key",
                            isDisabled: viewModel.isPositioning
                        )

                        ModernCrewField(
                            label: "S/O 2",
                            value: Binding(
                                get: { viewModel.so2Name },
                                set: { viewModel.updateSO2Name($0) }
                            ),
                            savedNames: viewModel.savedSONames,
                            recentNames: viewModel.recentSONames,
                            onNameAdded: viewModel.addSOName,
                            onNameRemoved: viewModel.removeSOName,
                            icon: "person.badge.key.fill",
                            isDisabled: viewModel.isPositioning
                        )
                    }
                }
                
                ModernRemarksField(
                    label: "REMARKS",
                    value: Binding(
                        get: { viewModel.remarks },
                        set: { viewModel.remarks = $0 }
                    ),
                    icon: "note.text"
                )
                
                // Toggles section
                ModernTogglesSection(viewModel: viewModel)
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}


// MARK: - Modern Action Buttons Card
private struct ModernActionButtonsCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Binding var showingSuccessAlert: Bool
    @Binding var showingDeleteAlert: Bool
    @Binding var showSuccessNotification: Bool
    @Binding var successMessage: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Check if we're in iPad split view mode
    private var isInSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.red)
                    .font(.title3)

                Text("Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                // Show different buttons based on editing mode
                if viewModel.isEditingMode {
                    // Update button for editing mode
                    ModernActionButton(
                        title: "Update Flight",
                        subtitle: "Save changes",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        isEnabled: viewModel.hasUnsavedChanges,
                        action: {
                            if viewModel.updateExistingFlight() {
                                // Show success notification
                                successMessage = "Flight Updated"
                                withAnimation {
                                    showSuccessNotification = true
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation {
                                        showSuccessNotification = false
                                    }
                                }

                                // Only exit editing mode and dismiss on iPhone
                                // On iPad split view, stay in edit mode to continue viewing/editing
                                if !isInSplitView {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        viewModel.exitEditingMode()
                                        dismiss()
                                    }
                                }
                            }
                        }
                    )

                    // Delete button
                    ModernActionButton(
                        title: "Delete Flight",
                        subtitle: "Remove from logbook",
                        icon: "trash.fill",
                        color: .red,
                        isEnabled: true,
                        action: {
                            print("🗑️ Delete button tapped")
                            showingDeleteAlert = true
                            print("🗑️ showingDeleteAlert set to: \(showingDeleteAlert)")
                        }
                    )

                    // Cancel button - only show on iPhone (not in iPad split view)
                    if !isInSplitView {
                        ModernActionButton(
                            title: "Cancel",
                            subtitle: "Discard changes",
                            icon: "xmark.circle",
                            color: .gray,
                            isEnabled: true,
                            action: {
                                viewModel.exitEditingMode()
                                dismiss()
                            }
                        )
                    }
                } else {
                    // Add to internal logbook button
                    ModernActionButton(
                        title: "Add to Logbook",
                        subtitle: "Save to internal logbook",
                        icon: "plus.circle.fill",
                        color: .green,
                        isEnabled: viewModel.canSendToLogTen,
                        action: {
                            HapticManager.shared.notification(.success)
                            viewModel.addToInternalLogbook()
                            successMessage = "Flight Added"
                            withAnimation {
                                showSuccessNotification = true
                            }
                            // Reset fields after showing notification
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                viewModel.resetAllFields()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    showSuccessNotification = false
                                }
                            }
                        }
                    )

                    // Clear button
                    ModernActionButton(
                        title: "Clear All Entries",
                        subtitle: "Clear form",
                        icon: "arrow.clockwise",
                        color: .red,
                        isEnabled: true,
                        action: viewModel.resetAllFields
                    )
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
}

// MARK: - Modern Component Helpers

private struct ModernButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernButtonContent(title: title, subtitle: subtitle, icon: icon, color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ModernButtonContent: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct ModernActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isEnabled ? .white : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isEnabled ? .white : .gray)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isEnabled ? .white.opacity(0.8) : .gray)
                }
                
                Spacer()
            }
            .padding(16)
            .background(isEnabled ? color.opacity(0.8) : Color.gray.opacity(0.3))
            .cornerRadius(10)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ModernDatePickerField: View {
    let label: String
    @Binding var dateString: String
    let icon: String
    var airportCode: String = ""
    var timeString: String = ""
    var showLocalDate: Bool = false
    var useIATACodes: Bool = false
    @State private var selectedDate = Date()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC timezone
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // Calculate local date for display
    private var localDate: Date? {
        guard showLocalDate,
              !dateString.isEmpty,
              !airportCode.isEmpty else {
            return nil
        }

        // Use the provided time, or a time near midnight to show potential date changes
        // Using 01:00 instead of 12:00 to better show date differences across timezones
        let timeToUse = !timeString.isEmpty ? timeString : "01:00"

        let localDateString = AirportService.shared.convertToLocalDate(
            utcDateString: dateString,
            utcTimeString: timeToUse,
            airportICAO: airportCode
        )

        return dateFormatter.date(from: localDateString)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            // UTC Date
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.primary.opacity(0.8))

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "en_AU"))
                    .onChange(of: selectedDate) { _, newDate in
                        dateString = dateFormatter.string(from: newDate)
                    }
            }

            Spacer()

            // Local Date (side by side) - read-only display
            if let localDateValue = localDate {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Date")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    DatePicker("", selection: .constant(localDateValue), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "en_AU"))
                        .disabled(true)
                }
            }
        }
        .padding(12)
        //.background(Color(.systemGray6).opacity(0.7))
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .onAppear {
            if !dateString.isEmpty, let date = dateFormatter.date(from: dateString) {
                selectedDate = date
            } else {
                // Set to today's UTC date if empty
                let utcDateFormatter = DateFormatter()
                utcDateFormatter.dateFormat = "dd/MM/yyyy"
                utcDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                let utcDate = Date()
                selectedDate = utcDate
                dateString = utcDateFormatter.string(from: utcDate)
            }
        }
        .onChange(of: dateString) { _, newDateString in
            // Sync selectedDate when dateString changes externally (e.g., from ACARS)
            if let date = dateFormatter.date(from: newDateString) {
                selectedDate = date
            }
        }
    }
}

private struct ModernAircraftRegField: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @State private var showingPicker = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: {
            if !isDisabled {
                showingPicker = true
            }
        }) {
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(isDisabled ? .gray : .blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("A/C REGISTRATION")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack(alignment: .bottom, spacing: 8) {
                        Text(viewModel.aircraftReg.isEmpty ? "Select aircraft" : viewModel.aircraftReg)
                            .font(.subheadline.bold())
                            .foregroundColor(viewModel.aircraftReg.isEmpty ? .secondary : .primary)

                        if !viewModel.aircraftReg.isEmpty && !viewModel.aircraftType.isEmpty {
                            Text(viewModel.aircraftType)
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if isDisabled {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.75))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .sheet(isPresented: $showingPicker) {
            AircraftRegPickerSheet(
                selectedReg: Binding(
                    get: { viewModel.aircraftReg },
                    set: { viewModel.updateAircraftReg($0) }
                ),
                selectedType: Binding(
                    get: { viewModel.aircraftType },
                    set: { viewModel.updateAircraftType($0) }
                ),
                showFullReg: viewModel.showFullAircraftReg,
                recentAircraftRegs: viewModel.recentAircraftRegs,
                onDismiss: { showingPicker = false }
            )
        }
    }
}

private struct ModernAirportField: View {
    let label: String
    @Binding var value: String
    let icon: String
    let useIATACodes: Bool
    let recentAirports: [String]
    let onAirportSelected: (String) -> Void
    @State private var showingPicker = false
    @State private var searchText = ""

    private var displayCode: String {
        guard !value.isEmpty else { return "" }
        if useIATACodes, let iataCode = AirportService.shared.convertToIATA(value) {
            return iataCode
        }
        return value
    }

    private var placeholderText: String {
        if useIATACodes {
            return "IATA"
        } else {
            return "ICAO"
        }
    }

    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text(displayCode.isEmpty ? placeholderText : displayCode)
                        .font(.subheadline.bold())
                        .foregroundColor(displayCode.isEmpty ? .secondary.opacity(0.5) : .primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.75))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingPicker) {
            AirportPickerSheet(
                title: "\(label) Airport",
                selectedAirport: Binding(
                    get: { value },
                    set: { newValue in
                        value = newValue
                        if !newValue.isEmpty {
                            onAirportSelected(newValue)
                        }
                    }
                ),
                searchText: $searchText,
                recentAirports: recentAirports,
                onDismiss: {
                    showingPicker = false
                    searchText = ""
                }
            )
        }
    }
}

private struct ModernCrewField: View {
    let label: String
    @Binding var value: String
    let savedNames: [String]
    var recentNames: [String] = []
    let onNameAdded: (String) -> Void
    let onNameRemoved: ((String) -> Void)?
    let icon: String
    var isDisabled: Bool = false
    @State private var showingPicker = false
    @State private var searchText = ""

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isDisabled ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text(value.isEmpty ? "Select crew" : value)
                    .font(.subheadline.bold())
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
            }

            Spacer()

            if isDisabled {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled {
                searchText = value  // Pre-populate with current value
                showingPicker = true
            }
        }
        .sheet(isPresented: $showingPicker) {
            CrewNamePickerSheet(
                title: label,
                selectedName: $value,
                searchText: $searchText,
                savedNames: savedNames,
                recentNames: recentNames,
                onNameAdded: onNameAdded,
                onNameRemoved: onNameRemoved,
                onDismiss: {
                    showingPicker = false
                    searchText = ""  // Clear after dismissing
                }
            )
        }
    }
}

private struct ModernTogglesSection: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 12) {
//            HStack {
//                Text("Operations")
//                    .font(.caption.bold())
//                    .foregroundColor(.secondary)
//                Spacer()
//            }

            VStack(spacing: 8) {
                // First row: PF, ICUS (when F/O), APP
                HStack(spacing: 12) {
                    ModernToggle(
                        title: "PF",
                        isOn: $viewModel.isPilotFlying,
                        color: .green,
                        isDisabled: viewModel.isPositioning
                    )
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .onChange(of: viewModel.isPilotFlying) { oldValue, newValue in
                        // When PF is turned off, also turn off ICUS
                        if !newValue && viewModel.flightTimePosition == .firstOfficer {
                            viewModel.isICUS = false
                        }

                        // When PF is turned back on, restore default approach type if set
                        // BUT only if NOT in editing mode (to preserve loaded flight's approach type)
                        if newValue && !viewModel.isEditingMode && viewModel.logApproaches && viewModel.defaultApproachType != nil {
                            viewModel.updateSelectedApproachType(viewModel.defaultApproachType)
                        }
                    }

                    if viewModel.flightTimePosition == .firstOfficer {
                        ModernToggle(
                            title: "ICUS",
                            isOn: $viewModel.isICUS,
                            color: .blue,
                            isDisabled: !viewModel.isPilotFlying
                        )
                        .frame(minWidth: 0, maxWidth: .infinity)
                    }

                    if viewModel.logApproaches {
                        ModernApproachToggle(
                            selectedApproachType: Binding(
                                get: { viewModel.selectedApproachType },
                                set: { newValue in
                                    viewModel.updateSelectedApproachType(newValue)
                                }
                            ),
                            isDisabled: !viewModel.isPilotFlying
                        )
                        .frame(minWidth: 0, maxWidth: .infinity)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.75))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }

            // Takeoffs and Landings section - only show when Pilot Flying is selected
            if viewModel.isPilotFlying {
                HStack {
                    Text("Takeoffs & Landings")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ModernIntegerField(
                            label: "Day T/O",
                            value: $viewModel.dayTakeoffs,
                            icon: "airplane.departure",
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )

                        ModernIntegerField(
                            label: "Day Ldg",
                            value: $viewModel.dayLandings,
                            icon: "airplane.arrival",
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )
                    }

                    HStack(spacing: 8) {
                        ModernIntegerField(
                            label: "Night T/O",
                            value: $viewModel.nightTakeoffs,
                            icon: "moon.fill",
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )

                        ModernIntegerField(
                            label: "Night Ldg",
                            value: $viewModel.nightLandings,
                            icon: "moon.stars.fill",
                            onValueChanged: {
                                viewModel.markTakeoffsLandingsAsManuallyEdited()
                            }
                        )
                    }
                }
            }
        }
    }
}

private struct ModernToggle: View {
    let title: String
    @Binding var isOn: Bool
    let color: Color
    var isDisabled: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: color))
                .scaleEffect(0.8)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.5 : 1.0)
                .onChange(of: isOn) {
                    HapticManager.shared.impact(.light) // Light haptic for toggle
                }
        }
    }
}

private struct ModernApproachToggle: View {
    @Binding var selectedApproachType: String?
    var isDisabled: Bool = false
    @State private var showingPicker = false

    private var isOn: Bool {
        selectedApproachType != nil
    }

    private var displayText: String {
        selectedApproachType ?? "Nil"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Appr")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            Button(action: {
                if !isDisabled {
                    showingPicker = true
                    HapticManager.shared.impact(.light)
                }
            }) {
                Text(displayText)
                    .font(.caption.bold())
                    .foregroundColor(isOn ? .white : .orange)
                    .frame(width: 50, height: 28)
                    .background(isOn ? Color.orange : Color.clear)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange, lineWidth: 2)
                    )
            }
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
            .confirmationDialog("Select Approach Type", isPresented: $showingPicker, titleVisibility: .visible) {
                Button("Nil") {
                    selectedApproachType = nil
                }
                Button("ILS") {
                    selectedApproachType = "ILS"
                }
                Button("GLS") {
                    selectedApproachType = "GLS"
                }
                Button("RNP") {
                    selectedApproachType = "RNP"
                }
                Button("AIII") {
                    selectedApproachType = "AIII"
                }
                Button("NPA") {
                    selectedApproachType = "NPA"
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

// MARK: - Modern Editable Fields

private struct ModernFlightNumberField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    let icon: String
    var isUppercase: Bool = false
    var keyboardType: UIKeyboardType = .default
    var canSearch: Bool = false
    var onSearch: (() -> Void)? = nil
    var onCommit: (() -> Void)? = nil
    var onFocus: (() -> Void)? = nil
    @FocusState private var textFieldFocused: Bool
    @State private var useAlphanumericKeyboard: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $value)
                    .font(.subheadline.bold())
                    .textInputAutocapitalization(isUppercase ? .characters : .words)
                    .autocorrectionDisabled(true)
                    .keyboardType(useAlphanumericKeyboard ? .default : keyboardType)
                    .focused($textFieldFocused)
                    .onChange(of: value) { _, newValue in
                        if isUppercase {
                            value = newValue.uppercased()
                        }
                    }
                    .onChange(of: textFieldFocused) { _, isFocused in
                        if isFocused {
                            onFocus?()
                        } else {
                            onCommit?()
                        }
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        onCommit?()
                    }
            }

            // Search button with FlightAware logo
            Button(action: {
                textFieldFocused = false  // Dismiss keyboard
                onSearch?()
                HapticManager.shared.impact(.light)
            }) {
                ZStack {
                    VStack{

                        Image(systemName: "airplane.path.dotted")
                            .font(.system(size: 25))
                            .foregroundColor(.blue)
                            .opacity(canSearch ? 1.0 : 0.4)

                        Text("Online Search")
                            .font(.caption.bold())
                            //.foregroundColor(.primary)
                            .foregroundColor(.blue)
                            .opacity(canSearch ? 1.0 : 0.4)


                        //                    Image("FlightAwareLogo")
                        //                        .resizable()
                        //                        .aspectRatio(contentMode: .fill)
                        //                        .frame(width: 100, height: 50)
                        //                        .cornerRadius(6)
                        //                        .opacity(canSearch ? 1.0 : 0.4)
                    }
                }
            }
            .disabled(!canSearch)
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            textFieldFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if textFieldFocused {
                    // Keyboard switcher button - only show on iPhone when number pad is the base keyboard
                    if UIDevice.current.userInterfaceIdiom == .phone && keyboardType == .numberPad {
                        Button(action: {
                            useAlphanumericKeyboard.toggle()
                            HapticManager.shared.impact(.light)
                            // Refocus to apply keyboard change
                            textFieldFocused = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                textFieldFocused = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                //Image(systemName: useAlphanumericKeyboard ? "textformat.123" : "textformat.abc")
                                Text(useAlphanumericKeyboard ? "123" : "ABC")
                            }
                            .fontWeight(.semibold)
                        }
                    }

                    Spacer()

                    Button("Done") {
                        textFieldFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct ModernEditableField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    let icon: String
    var isUppercase: Bool = false
    var keyboardType: UIKeyboardType = .default
    var onCommit: (() -> Void)? = nil
    var onFocus: (() -> Void)? = nil
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $value)
                    .font(.subheadline.bold())
                    .textInputAutocapitalization(isUppercase ? .characters : .words)
                    .autocorrectionDisabled(true)
                    .keyboardType(keyboardType)
                    .focused($textFieldFocused)
                    .onChange(of: value) { _, newValue in
                        if isUppercase {
                            value = newValue.uppercased()
                        }
                    }
                    .onChange(of: textFieldFocused) { _, isFocused in
                        if isFocused {
                            onFocus?()
                        } else {
                            onCommit?()
                        }
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        onCommit?()
                    }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            textFieldFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if textFieldFocused && keyboardType == .numberPad {
                    Spacer()
                    Button("Done") {
                        textFieldFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct ModernTimeField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var isReadOnly: Bool = false
    var dateString: String = ""
    var airportCode: String = ""
    var showLocalTime: Bool = false
    var useIATACodes: Bool = false
    @FocusState private var timeFieldFocused: Bool
    var onSave: (() -> Void)? = nil

    private func applyFormatting(_ input: String) -> String {
        // Allow only digits and colon; auto-insert colon for 4 digits
        let filtered = input.filter { $0.isNumber || $0 == ":" }
        if filtered.count == 4 && !filtered.contains(":") {
            let hours = String(filtered.prefix(2))
            let minutes = String(filtered.suffix(2))
            return "\(hours):\(minutes)"
        }
        return String(filtered.prefix(5))
    }

    private func formatWithLeadingZeros(_ input: String) -> String {
        // Parse and reformat to ensure HH:MM format with leading zeros
        if input.contains(":") {
            let components = input.split(separator: ":")
            if components.count == 2,
               let hours = Int(components[0]),
               let minutes = Int(components[1]),
               hours < 24, minutes < 60 {
                return String(format: "%02d:%02d", hours, minutes)
            }
        }
        // If already valid or can't parse, return as-is
        return input
    }

    // Calculate local time for display
    private var localTimeText: String? {
        guard showLocalTime,
              !value.isEmpty,
              !dateString.isEmpty,
              !airportCode.isEmpty else {
            return nil
        }

        let localTime = AirportService.shared.convertToLocalTime(
            utcDateString: dateString,
            utcTimeString: value,
            airportICAO: airportCode
        )

        // Format as HH:MM for display with airport code
        let airportDisplay = AirportService.shared.getDisplayCode(airportCode, useIATA: useIATACodes)
        if localTime.count == 4 {
            let hours = String(localTime.prefix(2))
            let minutes = String(localTime.suffix(2))
            return "\(hours):\(minutes) \(airportDisplay)"
        }
        return "\(localTime) \(airportDisplay)"
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isReadOnly ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                if isReadOnly {
                    HStack {
                        Text(value.isEmpty ? "--:--" : value)
                            .font(.subheadline.bold())
                            .foregroundColor(value.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    TextField("HH:MM", text: $value)
                        .font(.subheadline.bold())
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)
                        .focused($timeFieldFocused)
                        .onChange(of: value) { _, newValue in
                            value = applyFormatting(newValue)
                        }
                        .onChange(of: timeFieldFocused) { _, isFocused in
                            if !isFocused {
                                // Format with leading zeros when user finishes editing
                                value = formatWithLeadingZeros(value)
                                onSave?()
                            }
                        }
                        .submitLabel(.done)
                }

                // Show local time if available
                if let localTime = localTimeText {
                    Text(localTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(1.0))
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly {
                timeFieldFocused = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if timeFieldFocused {
                    Spacer()
                    Button("Done") {
                        timeFieldFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct ModernDecimalTimeField: View {
    let label: String
    @Binding var value: String
    let icon: String
    var isReadOnly: Bool = false
    var showAsHHMM: Bool = false  // NEW: Whether to display/accept HH:MM format
    @FocusState private var decimalFieldFocused: Bool
    var onSave: (() -> Void)? = nil

    @EnvironmentObject var viewModel: FlightTimeExtractorViewModel

    private func sanitize(_ input: String) -> String {
        if showAsHHMM {
            // Allow digits and colon for HH:MM format
            return input.filter { $0.isNumber || $0 == ":" }
        } else {
            // Allow digits, decimal point, and comma for decimal format
            var result = ""
            var hasSeparator = false
            for ch in input {
                if ch.isNumber {
                    result.append(ch)
                } else if ch == "." || ch == "," {
                    if !hasSeparator {
                        result.append(".")
                        hasSeparator = true
                    }
                }
            }
            return result
        }
    }

    private func formatOnBlur(_ input: String) -> String {
        if showAsHHMM {
            // Convert to HH:MM format
            if input.contains(":") {
                // Already in HH:MM, validate and reformat
                let components = input.split(separator: ":")
                if components.count == 2,
                   let hours = Int(components[0]),
                   let minutes = Int(components[1]),
                   hours >= 0, minutes >= 0, minutes < 60 {
                    return String(format: "%d:%02d", hours, minutes)
                }
            } else if let decimalValue = Double(input) {
                // Convert decimal to HH:MM
                return FlightSector.decimalToHHMM(decimalValue)
            }
            return input.isEmpty ? "0:00" : input
        } else {
            // Format as decimal
            let cleaned = input.replacingOccurrences(of: ",", with: ".")
            if let d = Double(cleaned) {
                return String(format: "%.1f", d)
            }
            return input.isEmpty ? "0.0" : input
        }
    }

    private func convertToDecimalForStorage(_ input: String) -> String {
        if showAsHHMM && input.contains(":") {
            // Convert HH:MM to decimal for storage
            if let decimal = FlightSector.hhmmToDecimal(input) {
                return String(format: "%.2f", decimal)
            }
        }
        return input
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isReadOnly ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                if isReadOnly {
                    HStack {
                        Text(displayValue)
                            .font(.subheadline.bold())
                            .foregroundColor(value.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    TextField(showAsHHMM ? "0:00" : "0.0", text: Binding(
                        get: {
                            // When field is focused or empty, show raw value
                            // When not focused, show formatted value
                            if decimalFieldFocused || value.isEmpty {
                                return value
                            } else {
                                return displayValue
                            }
                        },
                        set: { newValue in
                            value = sanitize(newValue)
                        }
                    ))
                        .font(.subheadline.bold())
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .focused($decimalFieldFocused)
                        .onChange(of: decimalFieldFocused) { _, isFocused in
                            if !isFocused {
                                // Convert to decimal for storage, then format for display
                                let decimalValue = convertToDecimalForStorage(value)
                                value = decimalValue
                                onSave?()
                            }
                        }
                        .submitLabel(.done)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly {
                decimalFieldFocused = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if decimalFieldFocused {
                    Spacer()
                    Button("Done") {
                        decimalFieldFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var displayValue: String {
        guard !value.isEmpty, let decimalValue = Double(value) else {
            return showAsHHMM ? "0:00" : "0.0"
        }

        if showAsHHMM {
            return FlightSector.decimalToHHMM(decimalValue)
        } else {
            return String(format: "%.1f", decimalValue)
        }
    }
}

private struct ModernIntegerField: View {
    let label: String
    @Binding var value: Int
    let icon: String
    var onValueChanged: (() -> Void)? = nil
    @State private var editingText: String = ""
    @FocusState private var integerFieldFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField("0", text: $editingText)
                    .font(.subheadline.bold())
                    .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad)
                    .focused($integerFieldFocused)
                    .onChange(of: editingText) { _, newValue in
                        // Only allow digits
                        let filtered = newValue.filter { $0.isNumber }
                        editingText = filtered
                    }
                    .onChange(of: integerFieldFocused) { _, isFocused in
                        if isFocused {
                            editingText = value == 0 ? "" : "\(value)"
                        } else {
                            let oldValue = value
                            if let intValue = Int(editingText) {
                                value = max(0, intValue)
                            } else {
                                value = 0
                            }
                            // Trigger callback if value changed
                            if oldValue != value {
                                onValueChanged?()
                            }
                        }
                    }
                    .submitLabel(.done)
                    .onAppear {
                        editingText = value == 0 ? "" : "\(value)"
                    }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            integerFieldFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if integerFieldFocused {
                    Spacer()
                    Button("Done") {
                        integerFieldFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct ModernRemarksField: View {
    let label: String
    @Binding var value: String
    let icon: String
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if value.isEmpty {
                    Text("Add remarks...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $value)
                    .font(.subheadline)
                    .frame(minHeight: 40)
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            editorFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if editorFocused {
                    Spacer()
                    Button("Done") {
                        editorFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}


// MARK: - Success Notification Banner
private struct SuccessNotificationBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.green)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - FlightAware Lookup Progress View
private struct FlightAwareLookupProgressView: View {
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: 16) {
                // FlightAware logo or airplane icon
                Image(systemName: "airplane.path.dotted")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

//                Image("FlightAwareLogo")
//                    .resizable()
//                    .aspectRatio(contentMode: .fill)
//                    .frame(width: 100, height: 50)
//                    .cornerRadius(6)
                
                // Loading indicator
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.blue)

                // Status text
//                Text("Looking up flight data...")
//                    .font(.headline)
//                    .foregroundColor(.primary)

                Text("Searching online...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity)
    }
}

// MARK: - Previews
#Preview {
    //AddFlightView()
      //  .environmentObject(FlightTimeExtractorViewModel())
    MainTabView()
}

