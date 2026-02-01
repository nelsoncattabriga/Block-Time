// FlightTimeExtractorViewModel.swift - Updated with Photo Saving
//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//


import SwiftUI
import Combine
import PhotosUI

// MARK: - Draft Flight Data
/// Codable structure to persist in-progress flight data
struct DraftFlightData: Codable {
    let timestamp: Date
    let flightDate: String
    let aircraftReg: String
    let aircraftType: String
    let fromAirport: String
    let toAirport: String
    let flightNumber: String
    let blockTime: String
    let nightTime: String
    let captainName: String
    let coPilotName: String
    let so1Name: String
    let so2Name: String
    let isPilotFlying: Bool
    let selectedApproachType: String?
    let isSimulator: Bool
    let isPositioning: Bool
    let outTime: String
    let inTime: String
    let scheduledDeparture: String
    let scheduledArrival: String
    let isICUS: Bool
    let remarks: String
    let dayTakeoffs: Int
    let dayLandings: Int
    let nightTakeoffs: Int
    let nightLandings: Int
    let hasManuallyEditedTakeoffsLandings: Bool

    var isExpired: Bool {
        // Draft expires after 24 hours
        Date().timeIntervalSince(timestamp) > 24 * 60 * 60
    }
}

@MainActor
class FlightTimeExtractorViewModel: ObservableObject {
    // MARK: - Services
    private let textRecognitionService = TextRecognitionService()
//    private let logTenProService = LogTenProService()
    internal let userDefaultsService = UserDefaultsService()
    private let photoSavingService = PhotoSavingService()
    private let nightCalcService = NightCalcService()
    private let timeCalculationManager: TimeCalculationManager
    private let logbookImportService: LogbookImportService
    private let flightAwareService = FlightAwareService.shared
    
    // MARK: - Published Properties
    @Published var selectedImage: UIImage?
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var isExtracting = false
    @Published var showingCamera = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var statusMessage = ""
    @Published var statusColor: Color = .primary

    // Import result state
    @Published var importCompleted: Bool = false
    @Published var lastImportSuccessCount: Int = 0
    @Published var lastImportFailureCount: Int = 0
    @Published var isImporting: Bool = false

    // FlightAware state
    @Published var isFetchingFlightAware: Bool = false
    @Published var flightSegments: [FlightAwareData] = []
    @Published var showingSegmentSelection: Bool = false

    @Published var logbookDestination = LogbookDestination.internalLogbook
    @Published var displayFlightsInLocalTime = false

    // Editing mode
    @Published var isEditingMode = false
    var editingSectorID: UUID?
    private var originalFlightData: FlightSector?
    private var originalIsICUS: Bool = false  // Stored separately since not in FlightSector model

    // Form fields
    @Published var flightDate = ""
    @Published var aircraftReg = ""
    @Published var aircraftType = ""
    @Published var fromAirport = ""
    @Published var toAirport = ""
    @Published var flightNumber = ""
    @Published var blockTime = ""
    @Published var nightTime = ""
    @Published var captainName = ""
    @Published var coPilotName = ""
    @Published var so1Name = ""
    @Published var so2Name = ""
    @Published var isPilotFlying = false
    @Published var isAIII = false
    @Published var isRNP = false
    @Published var isILS = false
    @Published var isGLS = false
    @Published var isNPA = false
    @Published var selectedApproachType: String? = nil  // "AIII", "RNP", "ILS", "GLS", "NPA", or nil
    @Published var isSimulator = false
    @Published var isPositioning = false
    @Published var outTime = ""
    @Published var inTime = ""
    @Published var scheduledDeparture = ""  // STD - Scheduled Time of Departure
    @Published var scheduledArrival = ""     // STA - Scheduled Time of Arrival
    @Published var isICUS = false
    @Published var remarks = ""
    @Published var dayTakeoffs = 0
    @Published var dayLandings = 0
    @Published var nightTakeoffs = 0
    @Published var nightLandings = 0

    // Manual edit tracking flags for takeoffs/landings
    @Published var hasManuallyEditedTakeoffsLandings = false

    // Settings properties
    @Published var defaultCaptainName = ""
    @Published var defaultCoPilotName = ""
    @Published var defaultSOName = ""
    @Published var flightTimePosition = FlightTimePosition.captain
    @Published var includeLeadingZeroInFlightNumber = false
    @Published var includeAirlinePrefixInFlightNumber = false
    @Published var airlinePrefix = "QF"
    @Published var showFullAircraftReg = true
    @Published var savePhotosToLibrary = false  // NEW SETTING
    @Published var showSONameFields = false  // Show/hide SO 1 and SO 2 fields
    @Published var pfAutoInstrumentMinutes: Int = 30
    @Published var useIATACodes = false  // Display airport codes in IATA format
    @Published var logApproaches = false  // Auto-log approaches toggle
    @Published var defaultApproachType: String? = nil  // Default approach type
    @Published var showTimesInHoursMinutes = false  // Show times in HH:MM format
    @Published var selectedFleetID = "All Aircraft"  // Selected fleet for filtering
    @Published var decimalRoundingMode: RoundingMode = .standard  // Rounding mode for decimal times

    // Saved crew names
    @Published var savedCaptainNames: [String] = []
    @Published var savedCoPilotNames: [String] = []
    @Published var savedSONames: [String] = []  // Shared list for both SO 1 and SO 2

    // Recent crew names
    @Published var recentCaptainNames: [String] = []
    @Published var recentCoPilotNames: [String] = []
    @Published var recentSONames: [String] = []

    // Recent aircraft
    @Published var recentAircraftRegs: [String] = []

    // Recent airports
    @Published var recentAirports: [String] = []
    
    // MARK: - Computed Properties
    var canSendToLogTen: Bool {
        // For simulator flights, only require block time and date (OUT/IN times optional)
        if isSimulator {
            return !blockTime.isEmpty && !flightDate.isEmpty && !fromAirport.isEmpty && !toAirport.isEmpty
        }
        // For regular flights, require OUT, IN, date, and airports
        return !outTime.isEmpty && !inTime.isEmpty && !flightDate.isEmpty && !fromAirport.isEmpty && !toAirport.isEmpty
    }

    var formattedFlightNumber: String {
        // Don't format flight numbers for simulator flights
        if isSimulator {
            return flightNumber
        }
        return formatFlightNumber(flightNumber)
    }

    // MARK: - Initialization & Settings Management
    private var hasLoadedSettings = false

    init() {
        // Initialize extracted services
        self.timeCalculationManager = TimeCalculationManager(nightCalcService: nightCalcService)
        self.logbookImportService = LogbookImportService()

        // Observe CloudKit settings changes from other devices
        NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract Sendable data immediately
            let changedKeys = notification.userInfo?["changedKeys"] as? [String]

            // Isolate to main actor for calling main actor-isolated methods
            Task { @MainActor [weak self] in
                // Check if notification includes changed keys for targeted update
                if let keys = changedKeys {
                    LogManager.shared.debug("Received CloudKit sync notification with \(keys.count) changed key(s): \(keys)")
                    self?.updateChangedSettings(keys)
                } else {
                    // Fallback to full reload for backwards compatibility
                    LogManager.shared.debug("Received CloudKit sync notification without changedKeys - performing full reload")
                    self?.loadAllSettings()
                }
            }
        }

        // Observe app lifecycle to save/restore draft flight data
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Isolate to main actor for calling main actor-isolated methods
            Task { @MainActor [weak self] in
                self?.saveDraftFlightData()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Isolate to main actor for calling main actor-isolated methods
            Task { @MainActor [weak self] in
                // Only restore if we have draft data and are not in editing mode
                if self?.hasDraftFlightData == true && self?.isEditingMode == false {
                    self?.restoreDraftFlightData()
                }
            }
        }

        // Observe flight data changes to refresh crew names (e.g., after CSV import)
        NotificationCenter.default.addObserver(
            forName: .flightDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Isolate to main actor for calling main actor-isolated methods
            Task { @MainActor [weak self] in
                self?.reloadSavedCrewNames()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setupInitialData() {
        if !hasLoadedSettings {
            loadAllSettings()
            hasLoadedSettings = true
        }

        // Try to restore draft data first (if not in editing mode)
        if !isEditingMode && hasDraftFlightData {
            restoreDraftFlightData()
            return  // Draft data restored, skip default initialization
        }

        // Set to today's UTC date if empty, otherwise preserve existing date
        if flightDate.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            flightDate = dateFormatter.string(from: Date())
        }

        // Populate the appropriate field with default name based on position
        if !isEditingMode {
            switch flightTimePosition {
            case .captain:
                if captainName.isEmpty {
                    captainName = defaultCaptainName
                }
            case .firstOfficer:
                if coPilotName.isEmpty {
                    coPilotName = defaultCoPilotName
                }
            case .secondOfficer:
                if so1Name.isEmpty {
                    so1Name = defaultSOName
                }
            }
        }
    }
    
    private func loadAllSettings() {
        let settings = userDefaultsService.loadSettings()

        // Auto-migrate away from LogTen Pro (no longer supported)
        if settings.logbookDestination == .logTenPro || settings.logbookDestination == .both {
            updateLogbookDestination(.internalLogbook)
        } else {
            logbookDestination = settings.logbookDestination
        }

        savedSONames = settings.savedSONames
        defaultCaptainName = settings.defaultCaptainName
        defaultCoPilotName = settings.defaultCoPilotName
        defaultSOName = settings.defaultSOName
        flightTimePosition = settings.flightTimePosition
        includeLeadingZeroInFlightNumber = settings.includeLeadingZeroInFlightNumber
        includeAirlinePrefixInFlightNumber = settings.includeAirlinePrefixInFlightNumber
        airlinePrefix = settings.airlinePrefix
        showFullAircraftReg = settings.showFullAircraftReg
        savedCaptainNames = settings.savedCaptainNames
        savedCoPilotNames = settings.savedCoPilotNames
        savePhotosToLibrary = settings.savePhotosToLibrary  // NEW SETTING LOAD
        showSONameFields = settings.showSONameFields  // Load SO fields visibility setting
        pfAutoInstrumentMinutes = settings.pfAutoInstrumentMinutes
        displayFlightsInLocalTime = settings.displayFlightsInLocalTime
        useIATACodes = settings.useIATACodes
        logApproaches = settings.logApproaches
        defaultApproachType = settings.defaultApproachType
        showTimesInHoursMinutes = settings.showTimesInHoursMinutes
        selectedFleetID = settings.selectedFleetID
        decimalRoundingMode = settings.decimalRoundingMode
        recentCaptainNames = settings.recentCaptainNames
        recentCoPilotNames = settings.recentCoPilotNames
        recentSONames = settings.recentSONames
        recentAircraftRegs = settings.recentAircraftRegs
        recentAirports = userDefaultsService.getRecentAirports()

        // Merge saved crew names with database crew names (includes CSV imported names)
        reloadSavedCrewNames()
    }

    /// Selective settings update - only reloads settings that changed from CloudKit sync
    /// This is significantly faster than reloading all 30+ settings
    private func updateChangedSettings(_ changedKeys: [String]) {
        guard !changedKeys.isEmpty else {
                        LogManager.shared.debug("updateChangedSettings called with empty changedKeys array")
            return
        }

        let settings = userDefaultsService.loadSettings()
//        LogManager.shared.debug("Loading settings for selective update...")

        // Only update the settings that actually changed
        for key in changedKeys {
            switch key {
            case "logbookDestination":
                logbookDestination = settings.logbookDestination
            case "savedSONames":
                savedSONames = settings.savedSONames
            case "defaultCaptainName":
                defaultCaptainName = settings.defaultCaptainName
            case "defaultCoPilotName":
                defaultCoPilotName = settings.defaultCoPilotName
            case "defaultSOName":
                defaultSOName = settings.defaultSOName
            case "flightTimePosition":
                flightTimePosition = settings.flightTimePosition
            case "includeLeadingZeroInFlightNumber":
                includeLeadingZeroInFlightNumber = settings.includeLeadingZeroInFlightNumber
            case "includeAirlinePrefixInFlightNumber":
                includeAirlinePrefixInFlightNumber = settings.includeAirlinePrefixInFlightNumber
            case "airlinePrefix":
                airlinePrefix = settings.airlinePrefix
            case "showFullAircraftReg":
                showFullAircraftReg = settings.showFullAircraftReg
            case "savedCaptainNames":
                savedCaptainNames = settings.savedCaptainNames
            case "savedCoPilotNames":
                savedCoPilotNames = settings.savedCoPilotNames
            case "savePhotosToLibrary":
                savePhotosToLibrary = settings.savePhotosToLibrary
            case "showSONameFields":
                showSONameFields = settings.showSONameFields
            case "pfAutoInstrumentMinutes":
                pfAutoInstrumentMinutes = settings.pfAutoInstrumentMinutes
            case "displayFlightsInLocalTime":
                displayFlightsInLocalTime = settings.displayFlightsInLocalTime
            case "useIATACodes":
                            LogManager.shared.debug("  ✏️ Updating useIATACodes: \(useIATACodes) -> \(settings.useIATACodes)")
                useIATACodes = settings.useIATACodes
            case "logApproaches":
                logApproaches = settings.logApproaches
            case "defaultApproachType":
                defaultApproachType = settings.defaultApproachType
            case "showTimesInHoursMinutes":
                showTimesInHoursMinutes = settings.showTimesInHoursMinutes
            case "selectedFleetID":
                selectedFleetID = settings.selectedFleetID
            case "decimalRoundingMode":
                decimalRoundingMode = settings.decimalRoundingMode
            case "recentCaptainNames":
                recentCaptainNames = settings.recentCaptainNames
            case "recentCoPilotNames":
                recentCoPilotNames = settings.recentCoPilotNames
            case "recentSONames":
                recentSONames = settings.recentSONames
            case "recentAircraftRegs":
                recentAircraftRegs = settings.recentAircraftRegs
            case "recentAirports":
                recentAirports = userDefaultsService.getRecentAirports()
            default:
                            LogManager.shared.debug("Unknown setting key from CloudKit sync: \(key)")
            }
        }

        LogManager.shared.debug("Updated \(changedKeys.count) setting(s) from CloudKit: \(changedKeys.sorted().joined(separator: ", "))")
    }
    
    // MARK: - Settings Update Methods
    
    func updateLogbookDestination(_ value: LogbookDestination) {
        logbookDestination = value
        userDefaultsService.setLogbookDestination(value)
    }
    
    func updateAircraftReg(_ value: String) {
                    LogManager.shared.debug("ViewModel updateAircraftReg called with: \(value)")
        aircraftReg = value
        userDefaultsService.setAircraftReg(value)

        // Track as recent aircraft if not empty
        if !value.isEmpty {
            userDefaultsService.trackRecentAircraftReg(value)
            recentAircraftRegs = userDefaultsService.getRecentAircraftRegs()
        }

        // Automatically update aircraft type based on registration
        if let aircraft = AircraftFleetService.getAircraft(byRegistration: value) {
                        LogManager.shared.debug("Found aircraft: \(aircraft.registration), type: \(aircraft.type)")
            aircraftType = aircraft.type
            userDefaultsService.setAircraftType(aircraft.type)
        } else {
                        LogManager.shared.debug("No aircraft found for registration: \(value)")
        }
                    LogManager.shared.debug("Final aircraftReg: \(aircraftReg), aircraftType: \(aircraftType)")
    }

    func trackAirportUsage(_ airport: String) {
        guard !airport.isEmpty else { return }
        userDefaultsService.trackRecentAirport(airport)
        recentAirports = userDefaultsService.getRecentAirports()
    }
    
    func updateAircraftType(_ value: String) {
        aircraftType = value
        userDefaultsService.setAircraftType(value)
    }

    func updateFlightNumber(_ value: String) {
        // Store raw value, don't format on every keystroke to allow editing
        flightNumber = value
    }

    func updateCaptainName(_ value: String) {
        captainName = value
        userDefaultsService.setCaptainName(value)
        if !value.isEmpty {
            userDefaultsService.trackRecentCaptainName(value)
            recentCaptainNames = userDefaultsService.getRecentCaptainNames()
        }
    }

    func updateCoPilotName(_ value: String) {
        coPilotName = value
        userDefaultsService.setCoPilotName(value)
        if !value.isEmpty {
            userDefaultsService.trackRecentCoPilotName(value)
            recentCoPilotNames = userDefaultsService.getRecentCoPilotNames()
        }
    }
    func addSOName(_ name: String) {
        savedSONames = userDefaultsService.addSOName(name)
    }
    
    func updateSO1Name(_ value: String) {
        so1Name = value
        if !value.isEmpty {
            userDefaultsService.trackRecentSOName(value)
            recentSONames = userDefaultsService.getRecentSONames()
        }
    }

    func updateSO2Name(_ value: String) {
        so2Name = value
        if !value.isEmpty {
            userDefaultsService.trackRecentSOName(value)
            recentSONames = userDefaultsService.getRecentSONames()
        }
    }
    
    func updateDefaultCaptainName(_ value: String) {
        defaultCaptainName = value
        userDefaultsService.setDefaultCaptainName(value)
    }
    
    func updateDefaultCoPilotName(_ value: String) {
        defaultCoPilotName = value
        userDefaultsService.setDefaultCoPilotName(value)
    }

    func updateDefaultSOName(_ value: String) {
        defaultSOName = value
        userDefaultsService.setDefaultSOName(value)
    }

    func updateFlightTimePosition(_ value: FlightTimePosition) {
        flightTimePosition = value
        userDefaultsService.setFlightTimePosition(value)

        // Set the appropriate default name to "Self" based on position
        switch value {
        case .captain:
            defaultCaptainName = "Self"
            userDefaultsService.setDefaultCaptainName("Self")

            // Update crew fields if not in editing mode
            if !isEditingMode {
                // Clear other "Self" values and set captain to Self
                if coPilotName == "Self" || coPilotName == defaultCoPilotName {
                    coPilotName = ""
                }
                if so1Name == "Self" || so1Name == defaultSOName {
                    so1Name = ""
                }
                captainName = defaultCaptainName
            }

        case .firstOfficer:
            defaultCoPilotName = "Self"
            userDefaultsService.setDefaultCoPilotName("Self")

            // Update crew fields if not in editing mode
            if !isEditingMode {
                // Clear other "Self" values and set F/O to Self
                if captainName == "Self" || captainName == defaultCaptainName {
                    captainName = ""
                }
                if so1Name == "Self" || so1Name == defaultSOName {
                    so1Name = ""
                }
                coPilotName = defaultCoPilotName
            }

        case .secondOfficer:
            defaultSOName = "Self"
            userDefaultsService.setDefaultSOName("Self")
            showSONameFields = true
            userDefaultsService.setShowSONameFields(true)

            // Update crew fields if not in editing mode
            if !isEditingMode {
                // Clear other "Self" values and set SO 1 to Self
                if captainName == "Self" || captainName == defaultCaptainName {
                    captainName = ""
                }
                if coPilotName == "Self" || coPilotName == defaultCoPilotName {
                    coPilotName = ""
                }
                so1Name = defaultSOName
            }
        }
    }
    
    func updateIncludeLeadingZeroInFlightNumber(_ value: Bool) {
        includeLeadingZeroInFlightNumber = value
        userDefaultsService.setIncludeLeadingZeroInFlightNumber(value)
    }
    
    func updateIncludeAirlinePrefixInFlightNumber(_ value: Bool) {
        includeAirlinePrefixInFlightNumber = value
        userDefaultsService.setIncludeAirlinePrefixInFlightNumber(value)
    }

    func updateAirlinePrefix(_ value: String) {
        airlinePrefix = value
        userDefaultsService.setAirlinePrefix(value)
    }

    func updateShowFullAircraftReg(_ value: Bool) {
        showFullAircraftReg = value
        userDefaultsService.setShowFullAircraftReg(value)
    }
    
    func updateSavePhotosToLibrary(_ value: Bool) {
        savePhotosToLibrary = value
        userDefaultsService.setSavePhotosToLibrary(value)
    }
    
    func updateShowSONameFields(_ value: Bool) {
        showSONameFields = value
        userDefaultsService.setShowSONameFields(value)
    }
    
    func updatePFAutoInstrumentMinutes(_ value: Int) {
        let clamped = max(0, min(120, value))
        pfAutoInstrumentMinutes = clamped
        userDefaultsService.setPFAutoInstrumentMinutes(clamped)
    }

    func updateDisplayFlightsInLocalTime(_ value: Bool) {
        displayFlightsInLocalTime = value
        userDefaultsService.setDisplayFlightsInLocalTime(value)
    }

    func updateUseIATACodes(_ value: Bool) {
        useIATACodes = value
        userDefaultsService.setUseIATACodes(value)
    }

    func updateShowTimesInHoursMinutes(_ value: Bool) {
        showTimesInHoursMinutes = value
        userDefaultsService.setShowTimesInHoursMinutes(value)
    }

    func updateDecimalRoundingMode(_ value: RoundingMode) {
        decimalRoundingMode = value
        userDefaultsService.setDecimalRoundingMode(value)
    }

    func updateSelectedFleetID(_ value: String) {
        selectedFleetID = value
        userDefaultsService.setSelectedFleetID(value)

        // Automatically update FRMS Fleet based on selected fleet
        // B737 or A321 → Shorthaul (A320/B737)
        // Everything else → Longhaul (A380/A330/B787)
        updateFRMSFleetBasedOnSelectedFleet(value)
    }

    private func updateFRMSFleetBasedOnSelectedFleet(_ fleetID: String) {
        // Determine FRMS fleet based on selected fleet
        let frmsFleet: FRMSFleet
        if fleetID == "B737" || fleetID == "A321" {
            frmsFleet = .a320B737  // Shorthaul
        } else {
            frmsFleet = .a380A330B787  // Longhaul
        }

        // Load current FRMS configuration
        let userDefaultsKey = "FRMSConfiguration"
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           var config = try? JSONDecoder().decode(FRMSConfiguration.self, from: savedData) {

            // Only update if the fleet is different
            if config.fleet != frmsFleet {
                config.fleet = frmsFleet

                // Save updated configuration
                if let encoded = try? JSONEncoder().encode(config) {
                    UserDefaults.standard.set(encoded, forKey: userDefaultsKey)

                    // Sync to iCloud
                    CloudKitSettingsSyncService.shared.syncToCloud()

                    // Post notification so FRMSViewModel picks up the change
                    NotificationCenter.default.post(
                        name: .settingsDidChange,
                        object: nil,
                        userInfo: ["changedKeys": ["frmsFleet"]]
                    )
                }
            }
        }
    }

    func updateLogApproaches(_ value: Bool) {
        logApproaches = value
        userDefaultsService.setLogApproaches(value)

        // If turned off, clear the default approach type
        if !value {
            defaultApproachType = nil
            userDefaultsService.setDefaultApproachType(nil)
        }

        
    }

    func updateDefaultApproachType(_ value: String?) {
        defaultApproachType = value
        userDefaultsService.setDefaultApproachType(value)
        
        // Reset all fields to apply/remove default approach
        resetAllFields()
    }

    // MARK: - Airport Code Conversion Helpers

    /// Convert user input to ICAO for storage (accepts both IATA and ICAO)
    func normalizeAirportCode(_ code: String) -> String {
        return AirportService.shared.convertToICAO(code)
    }

    /// Get display code based on user preference
    func getDisplayAirportCode(_ icaoCode: String) -> String {
        return AirportService.shared.getDisplayCode(icaoCode, useIATA: useIATACodes)
    }

    func updateSelectedApproachType(_ value: String?) {
//        print("DEBUG: updateSelectedApproachType called with: \(value ?? "nil")")

        // Only allow approach type selection if PF
        guard isPilotFlying else {
            selectedApproachType = nil
            isAIII = false
            isRNP = false
            isILS = false
            isGLS = false
            isNPA = false
                        LogManager.shared.debug("DEBUG: Approach type cleared - not PF")
            return
        }

        selectedApproachType = value

        // Reset all approach booleans
        isAIII = false
        isRNP = false
        isILS = false
        isGLS = false
        isNPA = false

        // Set the selected one to true
        switch value {
        case "AIII":
            isAIII = true
        case "RNP":
            isRNP = true
        case "ILS":
            isILS = true
        case "GLS":
            isGLS = true
        case "NPA":
            isNPA = true
        default:
            break
        }

//        print("DEBUG: After update - AIII: \(isAIII), RNP: \(isRNP), ILS: \(isILS), GLS: \(isGLS), NPA: \(isNPA)")
    }


    // MARK: - Image Handling (Updated with Photo Saving)
    
    func showCamera() {
        HapticManager.shared.impact(.medium) // Haptic for camera action
        showingCamera = true
    }
    
    func handleCameraImage(_ image: UIImage) {
        selectedImage = image
        statusMessage = "Photo captured - extracting times..."
        statusColor = .blue
        
        // Save photo to library if setting is enabled
        if savePhotosToLibrary {
            Task {
                await saveImageToPhotoLibrary(image)
            }
        }
        
        extractTimes()
    }
    
    func loadSelectedPhoto() {
        guard let item = selectedPhotoItem else { return }

        item.loadTransferable(type: Data.self) { result in
            Task { @MainActor in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        HapticManager.shared.impact(.medium) // Haptic for photo load
                        self.selectedImage = image
                        self.statusMessage = "Photo loaded - extracting times..."
                        self.statusColor = .blue
                        self.extractTimes()
                    }
                case .failure(let error):
                    // Reset photo picker state on load failure
                    self.selectedPhotoItem = nil
                    self.showError("Failed to load image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Photo Saving Methods
    
    /// Save the currently selected image to photo library
    func saveCurrentImageToPhotoLibrary() {
        guard let image = selectedImage else {
            showError("No image to save")
            return
        }
        
        Task {
            await saveImageToPhotoLibrary(image)
        }
    }
    
    /// Internal method to save image with proper error handling
    private func saveImageToPhotoLibrary(_ image: UIImage) async {
        let result = await photoSavingService.saveImageWithMetadata(
            image,
            metadata: createPhotoMetadata()
        )
        
        await MainActor.run {
            switch result {
            case .success:
                self.statusMessage = "Photo saved to library successfully!"
                self.statusColor = .green
                            LogManager.shared.debug("Photo saved to photo library")
                
            case .failure(let error):
                if photoSavingService.shouldShowSettingsAlert() {
                    self.showError("Permission denied. Please enable photo library access in Settings app.")
                } else {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Create metadata for saved photos
    private func createPhotoMetadata() -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        if !flightNumber.isEmpty {
            metadata["flightNumber"] = flightNumber
        }
        
        if !flightDate.isEmpty {
            metadata["date"] = flightDate
        }
        
        if !fromAirport.isEmpty && !toAirport.isEmpty {
            metadata["route"] = "\(fromAirport)-\(toAirport)"
        }
        
        return metadata
    }
    
    /// Get photo library permission status for UI display
    func getPhotoPermissionStatus() -> String {
        return photoSavingService.permissionStatusDescription()
    }
    
    /// Check if photo library permission is available
    func hasPhotoPermission() -> Bool {
        return photoSavingService.hasPermissionToSave()
    }
    
    /// Check if we have full photo permission (not limited)
    func hasFullPhotoPermission() -> Bool {
        return photoSavingService.hasFullPermission()
    }
    
    /// Check if we have limited photo permission
    func hasLimitedPhotoPermission() -> Bool {
        return photoSavingService.hasLimitedPermission()
    }
    
    /// Get debug info for photo permissions
    func getPhotoPermissionDebugInfo() -> String {
        return photoSavingService.getDetailedPermissionInfo()
    }
    
    // MARK: - Text Recognition (unchanged)
    
    func extractTimes() {
        guard let image = selectedImage else { return }

        isExtracting = true
        statusMessage = "Extracting times from image..."
        statusColor = .blue

        // Determine fleet type based on selected fleet
        let fleetType: FleetType = selectedFleetID == "B787" ? .b787 : .b737

        Task {
            do {
                let flightData = try await textRecognitionService.extractFlightData(from: image, fleetType: fleetType)

                await MainActor.run {
                    self.updateFieldsWithFlightData(flightData)
                    self.isExtracting = false
                    // Reset image state after successful extraction to allow fresh retry
                    self.selectedImage = nil
                    self.selectedPhotoItem = nil
                    self.statusMessage = "Times extracted successfully!"
                    self.statusColor = .green
                }

            } catch let error as PartialExtractionError {
                // Handle partial extraction - populate what we have and show warning
                await MainActor.run {
                    self.updateFieldsWithFlightData(error.partialData)
                    self.isExtracting = false
                    // Reset image state to allow retry
                    self.selectedImage = nil
                    self.selectedPhotoItem = nil
                    self.statusMessage = "Partial extraction"
                    self.statusColor = .orange
                    // Show warning with specific missing fields
                    self.showError(error.localizedDescription)
                }
            } catch {
                await MainActor.run {
                    self.isExtracting = false
                    // Reset image state on failure to allow fresh retry
                    self.selectedImage = nil
                    self.selectedPhotoItem = nil
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func updateFieldsWithFlightData(_ flightData: FlightData) {
        outTime = flightData.outTime
        inTime = flightData.inTime

        // Convert OCR block time (HH:mm) to decimal for storage; if empty, compute from OUT/IN
        if !flightData.blockTime.isEmpty {
            blockTime = Self.hhmmToDecimal(flightData.blockTime)
        } else {
            blockTime = calculateFlightTime() // already returns decimal string
        }

        if !flightData.flightNumber.isEmpty {
            // Don't format flight numbers for simulator flights
            flightNumber = isSimulator ? flightData.flightNumber : formatFlightNumber(flightData.flightNumber)
        }

        if !flightData.fromAirport.isEmpty {
            fromAirport = normalizeAirportCode(flightData.fromAirport)
        }

        if !flightData.toAirport.isEmpty {
            toAirport = normalizeAirportCode(flightData.toAirport)
        }

        // Update date - B787 provides full date, B737 provides day only
        if let fullDateString = flightData.fullDate, !fullDateString.isEmpty {
            // B787: full date in DD/MM/YYYY format
            flightDate = fullDateString
                        LogManager.shared.debug("Updated flight date from B787 ACARS: \(fullDateString)")
        } else if let dayString = flightData.dayOfMonth {
            // B737: day only, infer month/year
            updateFlightDateWithDay(dayString)
        }

        // Update aircraft registration if extracted (B787 ACARS)
        if let registration = flightData.aircraftRegistration, !registration.isEmpty {
            updateAircraftReg(registration)
        }

        // Update night time (which will also update takeoffs/landings) after all fields are set
        // For B787, defer night calculation until airports are manually entered (since ACARS doesn't include them)
        let isB787Extraction = flightData.fullDate != nil && flightData.aircraftRegistration != nil
        if !isB787Extraction {
            updateNightTime()
        } else {
                        LogManager.shared.debug("ℹ️ Deferring night time calculation for B787 - airports need to be entered manually")
        }

        // After populating ACARS data, check for a matching scheduled/future flight
        // and pre-fill empty fields with data from the roster
        prefillFromMatchingScheduledFlight()
    }

    /// Search for a matching scheduled flight and pre-fill empty form fields with its data
    private func prefillFromMatchingScheduledFlight() {
        // Need at least date and flight number to attempt matching
        guard !flightDate.isEmpty, !flightNumber.isEmpty else {
            LogManager.shared.debug("ℹ️ Not enough data to search for matching scheduled flight (need date and flight number)")
            return
        }

        let databaseService = FlightDatabaseService.shared
        var scheduledFlight: FlightEntity?

        // Try to find a matching scheduled flight
        if !fromAirport.isEmpty && !toAirport.isEmpty {
            // Have airports - use full matching (more precise)
            let fromICAO = AirportService.shared.convertToICAO(fromAirport)
            let toICAO = AirportService.shared.convertToICAO(toAirport)

            scheduledFlight = databaseService.findScheduledFlight(
                date: flightDate,
                flightNumber: formattedFlightNumber,
                fromAirport: fromICAO,
                toAirport: toICAO
            )
        } else {
            // No airports (e.g., B787 ACARS) - search by date and flight number only
            // Will only return a match if exactly one scheduled flight matches
            LogManager.shared.debug("ℹ️ Airports not available - searching by date and flight number only")
            scheduledFlight = databaseService.findScheduledFlightByDateAndFlightNumber(
                date: flightDate,
                flightNumber: formattedFlightNumber
            )
        }

        guard let scheduledFlight = scheduledFlight else {
            LogManager.shared.debug("ℹ️ No matching scheduled flight found for pre-fill")
            return
        }

        LogManager.shared.info("✈️ Found matching scheduled flight - pre-filling form with roster data")

        // Pre-fill empty fields from the scheduled flight
        // Only update if current field is empty and scheduled flight has data

        // Pre-fill airports (especially useful for B787 where ACARS doesn't include them)
        if fromAirport.isEmpty, let scheduledFrom = scheduledFlight.fromAirport, !scheduledFrom.isEmpty {
            fromAirport = scheduledFrom
            LogManager.shared.debug("   Pre-filled From: \(scheduledFrom)")
        }

        if toAirport.isEmpty, let scheduledTo = scheduledFlight.toAirport, !scheduledTo.isEmpty {
            toAirport = scheduledTo
            LogManager.shared.debug("   Pre-filled To: \(scheduledTo)")
        }

        if captainName.isEmpty, let scheduledCaptain = scheduledFlight.captainName, !scheduledCaptain.isEmpty {
            captainName = scheduledCaptain
            LogManager.shared.debug("   Pre-filled Captain: \(scheduledCaptain)")
        }

        if coPilotName.isEmpty, let scheduledFO = scheduledFlight.foName, !scheduledFO.isEmpty {
            coPilotName = scheduledFO
            LogManager.shared.debug("   Pre-filled F/O: \(scheduledFO)")
        }

        if so1Name.isEmpty, let scheduledSO1 = scheduledFlight.so1Name, !scheduledSO1.isEmpty {
            so1Name = scheduledSO1
            LogManager.shared.debug("   Pre-filled S/O 1: \(scheduledSO1)")
        }

        if so2Name.isEmpty, let scheduledSO2 = scheduledFlight.so2Name, !scheduledSO2.isEmpty {
            so2Name = scheduledSO2
            LogManager.shared.debug("   Pre-filled S/O 2: \(scheduledSO2)")
        }

        if aircraftReg.isEmpty, let scheduledReg = scheduledFlight.aircraftReg, !scheduledReg.isEmpty {
            aircraftReg = scheduledReg
            LogManager.shared.debug("   Pre-filled Aircraft Reg: \(scheduledReg)")
        }

        if aircraftType.isEmpty, let scheduledType = scheduledFlight.aircraftType, !scheduledType.isEmpty {
            aircraftType = scheduledType
            LogManager.shared.debug("   Pre-filled Aircraft Type: \(scheduledType)")
        }

        // Pre-fill scheduled times if available
        if scheduledDeparture.isEmpty, let scheduledSTD = scheduledFlight.scheduledDeparture, !scheduledSTD.isEmpty {
            scheduledDeparture = scheduledSTD
            LogManager.shared.debug("   Pre-filled STD: \(scheduledSTD)")
        }

        if scheduledArrival.isEmpty, let scheduledSTA = scheduledFlight.scheduledArrival, !scheduledSTA.isEmpty {
            scheduledArrival = scheduledSTA
            LogManager.shared.debug("   Pre-filled STA: \(scheduledSTA)")
        }

        // If we pre-filled airports, update night time calculation
        if !fromAirport.isEmpty && !toAirport.isEmpty {
            updateNightTime()
        }
    }
    
    private func formatFlightNumber(_ flightNumber: String) -> String {
        var formatted = flightNumber

        if includeAirlinePrefixInFlightNumber {
            // Only add prefix if it's not already there
            if !formatted.hasPrefix(airlinePrefix) {
                formatted = airlinePrefix + formatted
            }
        }

        if formatted.contains(airlinePrefix) && !includeLeadingZeroInFlightNumber {
            if formatted.hasPrefix(airlinePrefix + "0") {
                formatted = airlinePrefix + String(formatted.dropFirst(airlinePrefix.count + 1))
            }
        } else if !formatted.contains(airlinePrefix) && !includeLeadingZeroInFlightNumber {
            if formatted.hasPrefix("0") {
                formatted = String(formatted.dropFirst())
            }
        }

        return formatted
    }
    
    // MARK: - Crew Name Management (unchanged)

    func addCaptainName(_ name: String) {
        savedCaptainNames = userDefaultsService.addCaptainName(name)
    }

    func addCoPilotName(_ name: String) {
        savedCoPilotNames = userDefaultsService.addCoPilotName(name)
    }

    func removeCaptainName(_ name: String) {
        savedCaptainNames = userDefaultsService.removeCaptainName(name)
    }

    func removeCoPilotName(_ name: String) {
        savedCoPilotNames = userDefaultsService.removeCoPilotName(name)
    }

    func removeSOName(_ name: String) {
        savedSONames = userDefaultsService.removeSOName(name)
    }

    func reloadSavedCrewNames() {
        let settings = userDefaultsService.loadSettings()
        let databaseService = FlightDatabaseService.shared

        // Merge UserDefaults saved names with database crew names
        let userCaptainNames = Set(settings.savedCaptainNames)
        let dbCaptainNames = Set(databaseService.getAllCaptainNames())
        savedCaptainNames = Array(userCaptainNames.union(dbCaptainNames)).sorted()

        let userCoPilotNames = Set(settings.savedCoPilotNames)
        let dbFONames = Set(databaseService.getAllFONames())
        savedCoPilotNames = Array(userCoPilotNames.union(dbFONames)).sorted()

        let userSONames = Set(settings.savedSONames)
        let dbSONames = Set(databaseService.getAllSONames())
        savedSONames = Array(userSONames.union(dbSONames)).sorted()
    }
    
    // MARK: - LogTen Pro Integration (unchanged except updated `sendToLogTenPro`)
    
//    func sendToLogTenPro() {
//        HapticManager.shared.impact(.medium) // Haptic for action start
//        statusMessage = "Sending to LogTen Pro..."
//        statusColor = .blue
//
//        let flightEntry = LogTenProService.createFlightEntry(
//            flightDate: flightDate,
//            aircraftReg: aircraftReg,
//            outTime: outTime,
//            inTime: inTime,
//            flightNumber: formattedFlightNumber.isEmpty ? nil : formattedFlightNumber,
//            fromAirport: fromAirport.isEmpty ? nil : AirportService.shared.convertToICAO(fromAirport),
//            toAirport: toAirport.isEmpty ? nil : AirportService.shared.convertToICAO(toAirport),
//            captainName: captainName,
//            coPilotName: coPilotName,
//            so1Name: so1Name,
//            so2Name: so2Name,
//            flightTimePosition: flightTimePosition,
//            isPilotFlying: isPilotFlying,
//            isAIII: isPilotFlying && isAIII,
//            isRNP: isPilotFlying && isRNP,
//            isILS: isPilotFlying && isILS,
//            isGLS: isPilotFlying && isGLS,
//            isNPA: isPilotFlying && isNPA,
//            isICUS: isICUS,
//            isSimulator: isSimulator,
//            isPositioning: isPositioning,
//            instrumentTimeMinutes: isPilotFlying ? pfAutoInstrumentMinutes : nil,
//            remarks: remarks.isEmpty ? nil : remarks
//        )
//
//        Task {
//            let result = await logTenProService.sendFlightToLogTenPro(flightEntry)
//
//            await MainActor.run {
//                switch result {
//                case .success:
//                    HapticManager.shared.notification(.success) // Success haptic
//                    self.statusMessage = "Successfully sent to LogTen Pro!"
//                    self.statusColor = .green
//
//                case .failure(let error):
//                    HapticManager.shared.notification(.error) // Error haptic
//                    self.showError(error.localizedDescription)
//                }
//            }
//        }
//    }
    
    
    // MARK: - Add to internal Logbook
    
    func saveToLogbook() {
        // For simulator flights, allow missing OUT/IN times if block time is present
        if isSimulator {
            guard !blockTime.isEmpty else { return }
        } else {
            guard !outTime.isEmpty && !inTime.isEmpty else { return }
        }

        HapticManager.shared.impact(.medium) // Haptic for save action

        // For simulator flights without OUT/IN times, use the blockTime field directly
        let blockTimeCalculated = (isSimulator && (outTime.isEmpty || inTime.isEmpty)) ? blockTime : calculateFlightTime()
        if nightTime.isEmpty { updateNightTime() }

        // Calculate time credits based on position
        let p1TimeValue: String
        let p1usTimeValue: String
        let p2TimeValue: String

        // Positioning flights don't log any time credits
        if isPositioning {
            p1TimeValue = "0.0"
            p1usTimeValue = "0.0"
            p2TimeValue = "0.0"
        } else {
            switch flightTimePosition {
            case .captain:
                p1TimeValue = blockTimeCalculated
                p1usTimeValue = "0.0"
                p2TimeValue = "0.0"
            case .firstOfficer:
                if isICUS && isPilotFlying {
                    // First Officer with ICUS and PF gets P1US credit
                    p1TimeValue = "0.0"
                    p1usTimeValue = blockTimeCalculated
                    p2TimeValue = "0.0"
                } else {
                    // First Officer without ICUS gets P2 credit
                    p1TimeValue = "0.0"
                    p1usTimeValue = "0.0"
                    p2TimeValue = blockTimeCalculated
                }
            case .secondOfficer:
                // Second Officer gets P2 credit
                p1TimeValue = "0.0"
                p1usTimeValue = "0.0"
                p2TimeValue = blockTimeCalculated
            }
        }

        let instrumentTimeValue = isPilotFlying ? String(format: "%.1f", Double(pfAutoInstrumentMinutes) / 60.0) : "0.0"
        let simTimeValue = isSimulator ? blockTimeCalculated : "0.0"
                    LogManager.shared.debug("DEBUG: saveToLogbook PF=\(isPilotFlying), isSimulator=\(isSimulator), simTime=\(simTimeValue), block=\(isSimulator ? "0.0" : blockTimeCalculated), p1=\(p1TimeValue)")

        // Create database service instance or inject it
        let databaseService = FlightDatabaseService.shared  // Use singleton

        let newFlight = FlightSector(
            date: flightDate,
            flightNumber: formattedFlightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType, //"B738", // Default - you might want to make this configurable
            fromAirport: AirportService.shared.convertToICAO(fromAirport),
            toAirport: AirportService.shared.convertToICAO(toAirport),
            captainName: captainName,
            foName: coPilotName,
            so1Name: so1Name.isEmpty ? nil : so1Name,  // Add SO1
            so2Name: so2Name.isEmpty ? nil : so2Name,  // Add SO2
            blockTime: isSimulator ? "0.0" : blockTimeCalculated,
            nightTime: nightTime,
            p1Time: p1TimeValue,
            p1usTime: p1usTimeValue,
            p2Time: p2TimeValue,
            instrumentTime: instrumentTimeValue,
            simTime: simTimeValue,
            isPilotFlying: isPilotFlying,
            isPositioning: isPositioning,
            isAIII: isPilotFlying && isAIII,
            isRNP: isPilotFlying && isRNP,
            isILS: isPilotFlying && isILS,
            isGLS: isPilotFlying && isGLS,
            isNPA: isPilotFlying && isNPA,
            remarks: remarks,
            dayTakeoffs: dayTakeoffs,
            dayLandings: dayLandings,
            nightTakeoffs: nightTakeoffs,
            nightLandings: nightLandings,
            outTime: outTime,
            inTime: inTime,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival
        )
                    LogManager.shared.debug("DEBUG: New FlightSector instrumentTime=\(newFlight.instrumentTime), PF=\(newFlight.isPilotFlying), date=\(newFlight.date), flt=\(newFlight.flightNumber), p2Time=\(newFlight.p2Time)")
        
        if databaseService.saveFlight(newFlight) {
                        LogManager.shared.debug("DEBUG: Saved sector with instrumentTime=\(newFlight.instrumentTime)")
            statusMessage = "Flight saved to logbook!"
            statusColor = .green
        } else {
                        LogManager.shared.debug("DEBUG: Failed to save sector (instrumentTime was \(newFlight.instrumentTime))")
            showError("Failed to save flight to logbook")
        }
    }

    // MARK: - Flight Editing

    func loadFlightForEditing(_ sector: FlightSector) {
        isEditingMode = true
        editingSectorID = sector.id

        flightDate = sector.date
        flightNumber = sector.flightNumber
        aircraftReg = sector.aircraftReg
        aircraftType = sector.aircraftType
        fromAirport = sector.fromAirport
        toAirport = sector.toAirport
        captainName = sector.captainName
        coPilotName = sector.foName
        so1Name = sector.so1Name ?? ""
        so2Name = sector.so2Name ?? ""

        // Determine if this is a simulator flight
        let simTimeValue = Double(sector.simTime) ?? 0.0
        isSimulator = simTimeValue > 0.0

        // For future flights (imported rosters) with empty crew names,
        // populate with default names based on position
        let blockTimeValue = Double(sector.blockTime) ?? 0.0
        let isFutureFlight = blockTimeValue == 0 && simTimeValue == 0

        if isFutureFlight {
            switch flightTimePosition {
            case .captain:
                if captainName.isEmpty {
                    captainName = defaultCaptainName
                }
            case .firstOfficer:
                if coPilotName.isEmpty {
                    coPilotName = defaultCoPilotName
                }
            case .secondOfficer:
                // SO typically doesn't need default name population
                break
            }
        }

        // Load positioning flag
        isPositioning = sector.isPositioning

        // Infer ICUS status from time credits
        // If position is First Officer and p1usTime > 0, then ICUS was enabled
        let p1usTimeValue = Double(sector.p1usTime) ?? 0.0
        isICUS = (flightTimePosition == .firstOfficer && p1usTimeValue > 0.0)

        // For simulator flights, load simTime into blockTime field (since the UI shows "Sim Time" when isSimulator is true)
        // For regular flights, load blockTime as usual
        if isSimulator {
            if let simValue = Double(sector.simTime) {
                blockTime = String(format: "%.2f", simValue)
            } else {
                blockTime = sector.simTime
            }
        } else {
            if let blockValue = Double(sector.blockTime) {
                blockTime = String(format: "%.2f", blockValue)
            } else {
                blockTime = sector.blockTime
            }
        }

        if let nightValue = Double(sector.nightTime) {
            nightTime = String(format: "%.2f", nightValue)
        } else {
            nightTime = sector.nightTime
        }
        isPilotFlying = sector.isPilotFlying
        isAIII = sector.isAIII
        isRNP = sector.isRNP
        isILS = sector.isILS
        isGLS = sector.isGLS
        isNPA = sector.isNPA

//        print("DEBUG: Loaded approach booleans - AIII: \(isAIII), RNP: \(isRNP), ILS: \(isILS), GLS: \(isGLS), NPA: \(isNPA)")

        // Set selectedApproachType based on which approach boolean is true
        if isAIII {
            selectedApproachType = "AIII"
        } else if isRNP {
            selectedApproachType = "RNP"
        } else if isILS {
            selectedApproachType = "ILS"
        } else if isGLS {
            selectedApproachType = "GLS"
        } else if isNPA {
            selectedApproachType = "NPA"
        } else {
            selectedApproachType = nil
        }

//        print("DEBUG: Set selectedApproachType to: \(selectedApproachType ?? "nil")")

        remarks = sector.remarks
        dayTakeoffs = sector.dayTakeoffs
        dayLandings = sector.dayLandings
        nightTakeoffs = sector.nightTakeoffs
        nightLandings = sector.nightLandings
        outTime = sector.outTime
        inTime = sector.inTime
        scheduledDeparture = sector.scheduledDeparture
        scheduledArrival = sector.scheduledArrival

        // If the loaded flight has any non-zero takeoff/landing values,
        // mark as manually edited to prevent automatic recalculation.
        // To allow automatic updating, set each of the takeoff/landing values to 0.
        hasManuallyEditedTakeoffsLandings = (dayTakeoffs != 0 || dayLandings != 0 || nightTakeoffs != 0 || nightLandings != 0)

        // Store originalFlightData that matches what's displayed in the UI
        // For simulator flights, the blockTime field shows simTime, so we need to reflect that
        var modifiedSector = sector
        if isSimulator {
            // Replace blockTime with simTime for comparison purposes
            modifiedSector.blockTime = sector.simTime
        }

        // Update crew names in modifiedSector to match what was auto-populated above (lines 1311-1325)
        // This prevents change detection from flagging crew names as changed when they were just auto-filled
        modifiedSector.captainName = captainName
        modifiedSector.foName = coPilotName
        modifiedSector.so1Name = so1Name.isEmpty ? nil : so1Name
        modifiedSector.so2Name = so2Name.isEmpty ? nil : so2Name

        originalFlightData = modifiedSector

        // Store original ICUS value (inferred from time credits)
        originalIsICUS = isICUS

//        print("DEBUG: Loaded flight for editing: \(sector.flightNumber)")
    }

    func updateExistingFlight() -> Bool {
        guard let sectorID = editingSectorID else { return false }

        HapticManager.shared.impact(.medium)

        // Calculate time credits based on position
        let p1TimeValue: String
        let p1usTimeValue: String
        let p2TimeValue: String

        // Positioning flights don't log any time credits
        if isPositioning {
            p1TimeValue = "0.0"
            p1usTimeValue = "0.0"
            p2TimeValue = "0.0"
        } else {
            switch flightTimePosition {
            case .captain:
                p1TimeValue = blockTime
                p1usTimeValue = "0.0"
                p2TimeValue = "0.0"
            case .firstOfficer:
                if isICUS && isPilotFlying {
                    // First Officer with ICUS and PF gets P1US credit
                    p1TimeValue = "0.0"
                    p1usTimeValue = blockTime
                    p2TimeValue = "0.0"
                } else {
                    // First Officer without ICUS gets P2 credit
                    p1TimeValue = "0.0"
                    p1usTimeValue = "0.0"
                    p2TimeValue = blockTime
                }
            case .secondOfficer:
                // Second Officer gets P2 credit
                p1TimeValue = "0.0"
                p1usTimeValue = "0.0"
                p2TimeValue = blockTime
            }
        }

        let instrumentTimeValue = isPilotFlying ? String(format: "%.1f", Double(pfAutoInstrumentMinutes) / 60.0) : "0.0"
        let simTimeValue = isSimulator ? blockTime : "0.0"

//        print("DEBUG: Saving flight with approach - AIII: \(isAIII), RNP: \(isRNP), ILS: \(isILS), GLS: \(isGLS), NPA: \(isNPA)")

        let updatedFlight = FlightSector(
            id: sectorID,
            date: flightDate,
            flightNumber: formattedFlightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: AirportService.shared.convertToICAO(fromAirport),
            toAirport: AirportService.shared.convertToICAO(toAirport),
            captainName: captainName,
            foName: coPilotName,
            so1Name: so1Name.isEmpty ? nil : so1Name,
            so2Name: so2Name.isEmpty ? nil : so2Name,
            blockTime: blockTime,
            nightTime: nightTime,
            p1Time: p1TimeValue,
            p1usTime: p1usTimeValue,
            p2Time: p2TimeValue,
            instrumentTime: instrumentTimeValue,
            simTime: simTimeValue,
            isPilotFlying: isPilotFlying,
            isPositioning: isPositioning,
            isAIII: isPilotFlying && isAIII,
            isRNP: isPilotFlying && isRNP,
            isILS: isPilotFlying && isILS,
            isGLS: isPilotFlying && isGLS,
            isNPA: isPilotFlying && isNPA,
            remarks: remarks,
            dayTakeoffs: dayTakeoffs,
            dayLandings: dayLandings,
            nightTakeoffs: nightTakeoffs,
            nightLandings: nightLandings,
            outTime: outTime,
            inTime: inTime,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival
        )

        let databaseService = FlightDatabaseService.shared
        let success = databaseService.updateFlight(updatedFlight)

        if success {
            statusMessage = "Flight updated successfully!"
            statusColor = .green
            HapticManager.shared.notification(.success)

            // Update originalFlightData so hasUnsavedChanges returns false
            // This is important for iPad split view where we stay in edit mode after save
            originalFlightData = updatedFlight

            // Database service observers will automatically post .flightDataChanged notification
        } else {
            statusMessage = "Failed to update flight"
            statusColor = .red
            HapticManager.shared.notification(.error)
        }

        return success
    }

    var hasUnsavedChanges: Bool {
        guard let original = originalFlightData else { return false }

        // Helper to compare time values numerically (ignoring precision differences like "4.5" vs "4.50")
        func timeValuesEqual(_ a: String, _ b: String) -> Bool {
            guard let aVal = Double(a), let bVal = Double(b) else {
                return a == b // Fall back to string comparison if not numeric
            }
            return abs(aVal - bVal) < 0.01 // Consider equal if within 0.01 hours (~36 seconds)
        }

        // Check if original flight was a simulator flight
        let originalWasSimulator = (Double(original.simTime) ?? 0.0) > 0.0

        return flightDate != original.date ||
               flightNumber != original.flightNumber ||
               aircraftReg != original.aircraftReg ||
               aircraftType != original.aircraftType ||
               fromAirport != original.fromAirport ||
               toAirport != original.toAirport ||
               captainName != original.captainName ||
               coPilotName != original.foName ||
               (so1Name != (original.so1Name ?? "")) ||
               (so2Name != (original.so2Name ?? "")) ||
               !timeValuesEqual(blockTime, original.blockTime) ||
               !timeValuesEqual(nightTime, original.nightTime) ||
               isPilotFlying != original.isPilotFlying ||
               isAIII != original.isAIII ||
               isRNP != original.isRNP ||
               isILS != original.isILS ||
               isGLS != original.isGLS ||
               isNPA != original.isNPA ||
               isICUS != originalIsICUS ||
               isSimulator != originalWasSimulator ||
               isPositioning != original.isPositioning ||
               remarks != original.remarks ||
               dayTakeoffs != original.dayTakeoffs ||
               dayLandings != original.dayLandings ||
               nightTakeoffs != original.nightTakeoffs ||
               nightLandings != original.nightLandings ||
               outTime != original.outTime ||
               inTime != original.inTime ||
               scheduledDeparture != original.scheduledDeparture ||
               scheduledArrival != original.scheduledArrival
    }

    var changesSummary: String {
        guard let original = originalFlightData else { return "" }

        var changes: [String] = []

        if flightDate != original.date {
            changes.append("Date: \(original.date) → \(flightDate)")
        }

        if flightNumber != original.flightNumber {
            changes.append("Flight: \(original.flightNumber) → \(flightNumber)")
        }

        if aircraftReg != original.aircraftReg {
            changes.append("Aircraft: \(original.aircraftReg) → \(aircraftReg)")
        }

        if fromAirport != original.fromAirport {
            changes.append("From: \(original.fromAirport) → \(fromAirport)")
        }

        if toAirport != original.toAirport {
            changes.append("To: \(original.toAirport) → \(toAirport)")
        }

        if captainName != original.captainName {
            changes.append("Captain: \(original.captainName) → \(captainName)")
        }

        if coPilotName != original.foName {
            changes.append("F/O: \(original.foName) → \(coPilotName)")
        }

        if so1Name != (original.so1Name ?? "") {
            changes.append("SO1: \(original.so1Name ?? "empty") → \(so1Name)")
        }

        if so2Name != (original.so2Name ?? "") {
            changes.append("SO2: \(original.so2Name ?? "empty") → \(so2Name)")
        }

        if outTime != original.outTime {
            changes.append("Out: \(original.outTime) → \(outTime)")
        }

        if inTime != original.inTime {
            changes.append("In: \(original.inTime) → \(inTime)")
        }

        if scheduledDeparture != original.scheduledDeparture {
            changes.append("STD: \(original.scheduledDeparture) → \(scheduledDeparture)")
        }

        if scheduledArrival != original.scheduledArrival {
            changes.append("STA: \(original.scheduledArrival) → \(scheduledArrival)")
        }

        if blockTime != original.blockTime {
            changes.append("Block: \(original.blockTime) → \(blockTime)")
        }

        if nightTime != original.nightTime {
            changes.append("Night: \(original.nightTime) → \(nightTime)")
        }

        if isPilotFlying != original.isPilotFlying {
            changes.append("PF: \(original.isPilotFlying ? "Yes" : "No") → \(isPilotFlying ? "Yes" : "No")")
        }

        // Approach type changes
        let originalApproach = getApproachType(from: original)
        let currentApproach = selectedApproachType ?? "VFR"
        if originalApproach != currentApproach {
            changes.append("App: \(originalApproach) → \(currentApproach)")
        }

        // Simulator/Flight type changes
        let originalWasSimulator = (Double(original.simTime) ?? 0.0) > 0.0
        if isSimulator != originalWasSimulator {
            changes.append("Type: \(originalWasSimulator ? "SIM" : "FLT") → \(isSimulator ? "SIM" : "FLT")")
        }

        // Positioning flight changes
        if isPositioning != original.isPositioning {
            changes.append("Type: \(original.isPositioning ? "PAX" : "FLT") → \(isPositioning ? "PAX" : "FLT")")
        }

        if dayTakeoffs != original.dayTakeoffs {
            changes.append("Day T/O: \(original.dayTakeoffs) → \(dayTakeoffs)")
        }

        if dayLandings != original.dayLandings {
            changes.append("Day Ldg: \(original.dayLandings) → \(dayLandings)")
        }

        if nightTakeoffs != original.nightTakeoffs {
            changes.append("Night T/O: \(original.nightTakeoffs) → \(nightTakeoffs)")
        }

        if nightLandings != original.nightLandings {
            changes.append("Night Ldg: \(original.nightLandings) → \(nightLandings)")
        }

        if remarks != original.remarks {
            changes.append("Remarks updated")
        }

        return changes.isEmpty ? "No changes detected" : changes.joined(separator: "\n")
    }

    private func getApproachType(from sector: FlightSector) -> String {
        if sector.isAIII { return "AIII" }
        if sector.isRNP { return "RNP" }
        if sector.isILS { return "ILS" }
        if sector.isGLS { return "GLS" }
        if sector.isNPA { return "NPA" }
        return "VFR"
    }

    func exitEditingMode() {
        // Only reset if we were actually in editing mode
        let wasEditingMode = isEditingMode

        isEditingMode = false
        editingSectorID = nil
        originalFlightData = nil

        // Only reset fields if we were actually editing a flight
        // This preserves draft data when just ensuring edit mode is off
        if wasEditingMode {
            resetAllFields()
        }
    }

    func deleteCurrentFlight() -> Bool {
        guard let sectorID = editingSectorID else { return false }

        HapticManager.shared.impact(.medium)

        // Create a temporary FlightSector object with just the ID for deletion
        let tempSector = FlightSector(
            id: sectorID,
            date: flightDate,
            flightNumber: formattedFlightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: AirportService.shared.convertToICAO(fromAirport),
            toAirport: AirportService.shared.convertToICAO(toAirport),
            captainName: captainName,
            foName: coPilotName,
            so1Name: so1Name.isEmpty ? nil : so1Name,
            so2Name: so2Name.isEmpty ? nil : so2Name,
            blockTime: blockTime,
            nightTime: nightTime,
            p1Time: "0.0",
            p1usTime: "0.0",
            p2Time: "0.0",
            instrumentTime: "0.0",
            simTime: "0.0",
            isPilotFlying: isPilotFlying,
            isPositioning: isPositioning,
            isAIII: isPilotFlying && isAIII,
            isRNP: isPilotFlying && isRNP,
            isILS: isPilotFlying && isILS,
            isGLS: isPilotFlying && isGLS,
            isNPA: isPilotFlying && isNPA,
            remarks: remarks
        )

        let databaseService = FlightDatabaseService.shared
        let success = databaseService.deleteFlight(tempSector)

        if success {
            HapticManager.shared.notification(.success)
        } else {
            HapticManager.shared.notification(.error)
        }

        return success
    }


    // MARK: - Takeoff/Landing Calculation
    func updateTakeoffsLandings(using context: FlightCalculationContext? = nil) {
        // Skip automatic calculation if user has manually edited these fields
        if hasManuallyEditedTakeoffsLandings {
            return
        }

        // Only log takeoffs/landings when pilot flying
        guard isPilotFlying else {
            dayTakeoffs = 0
            dayLandings = 0
            nightTakeoffs = 0
            nightLandings = 0
            // Clear approach type when not PF
            selectedApproachType = nil
            isAIII = false
            isRNP = false
            isILS = false
            isGLS = false
            isNPA = false
            return
        }

        // PERFORMANCE OPTIMIZATION: Use provided context if available
        if let context = context {
            // Context already contains all parsed values - no need to re-parse!
            let checkInterval: TimeInterval = 180 // 3 minutes before arrival
            let arrivalCheckTime = context.departureTime.addingTimeInterval(max(0, context.blockTimeHours * 3600 - checkInterval))

            LogManager.shared.debug("updateTakeoffsLandings (CACHED): Using pre-built context")
            LogManager.shared.debug("updateTakeoffsLandings: flightDate=\(flightDate), parsedFlightDate=\(context.flightDate)")
            LogManager.shared.debug("updateTakeoffsLandings: outTime=\(outTime), arrivalTime=\(context.arrivalTime)")
            LogManager.shared.debug("updateTakeoffsLandings: blockTime=\(blockTime), blockTimeValue=\(context.blockTimeHours)")
            LogManager.shared.debug("updateTakeoffsLandings: from=\(context.fromAirport) to=\(context.toAirport)")

            // Check if departure is at night (using cached coordinates)
            let isDepartureNight = nightCalcService.isNight(
                at: context.fromCoordinates.latitude,
                lon: context.fromCoordinates.longitude,
                time: context.departureTime
            )

            // Check if arrival is at night (using cached coordinates)
            let isArrivalNight = nightCalcService.isNight(
                at: context.toCoordinates.latitude,
                lon: context.toCoordinates.longitude,
                time: arrivalCheckTime
            )

            LogManager.shared.debug("updateTakeoffsLandings: isDepartureNight=\(isDepartureNight), isArrivalNight=\(isArrivalNight)")

            // Set takeoff values
            if isDepartureNight {
                nightTakeoffs = 1
                dayTakeoffs = 0
            } else {
                nightTakeoffs = 0
                dayTakeoffs = 1
            }

            // Set landing values
            if isArrivalNight {
                nightLandings = 1
                dayLandings = 0
            } else {
                nightLandings = 0
                dayLandings = 1
            }

            return
        }

        // FALLBACK: Original logic for when context is not available
        // Need valid airports and times
        guard !fromAirport.isEmpty, !toAirport.isEmpty,
              !outTime.isEmpty, !blockTime.isEmpty else {
            // If in editing mode, keep existing values since we don't have outTime/inTime
            if !isEditingMode {
                dayTakeoffs = 0
                dayLandings = 0
                nightTakeoffs = 0
                nightLandings = 0
            }
            return
        }

        // Get airport coordinates
        guard let fromCoords = nightCalcService.getAirportCoordinates(for: fromAirport),
              let toCoords = nightCalcService.getAirportCoordinates(for: toAirport) else {
            // Default to all zeros if we can't lookup airports
            dayTakeoffs = 0
            dayLandings = 0
            nightTakeoffs = 0
            nightLandings = 0
            return
        }

        // Parse the flight date from DD/MM/YYYY format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let parsedFlightDate = dateFormatter.date(from: flightDate) ?? Date()

        // Parse departure time using the actual flight date
        guard let departureTime = parseUTCTimeOnDate(outTime, on: parsedFlightDate) else {
            dayTakeoffs = 0
            dayLandings = 0
            nightTakeoffs = 0
            nightLandings = 0
            return
        }

        // Parse block time to calculate arrival time (handle both decimal and HH:MM format)
        let blockTimeValue: Double
        if blockTime.contains(":") {
            // HH:MM format
            let components = blockTime.split(separator: ":")
            guard components.count == 2,
                  let hours = Double(components[0]),
                  let minutes = Double(components[1]) else {
                dayTakeoffs = 0
                dayLandings = 0
                nightTakeoffs = 0
                nightLandings = 0
                return
            }
            blockTimeValue = hours + (minutes / 60.0)
        } else {
            // Decimal format
            guard let value = Double(blockTime), value > 0 else {
                dayTakeoffs = 0
                dayLandings = 0
                nightTakeoffs = 0
                nightLandings = 0
                return
            }
            blockTimeValue = value
        }

        guard blockTimeValue > 0 else {
            dayTakeoffs = 0
            dayLandings = 0
            nightTakeoffs = 0
            nightLandings = 0
            return
        }

        // Calculate arrival time, but check 3 minutes before actual arrival
        // to be consistent with how night time is calculated (which uses 200 segments)
        // This avoids edge cases where the very last minute transitions from night to twilight
        let checkInterval: TimeInterval = 180 // 3 minutes before arrival
        let arrivalTime = departureTime.addingTimeInterval(blockTimeValue * 3600)
        let arrivalCheckTime = departureTime.addingTimeInterval(max(0, blockTimeValue * 3600 - checkInterval))

                    LogManager.shared.debug("updateTakeoffsLandings (FALLBACK): Building context from scratch")
                    LogManager.shared.debug("updateTakeoffsLandings: flightDate=\(flightDate), parsedFlightDate=\(parsedFlightDate)")
                    LogManager.shared.debug("updateTakeoffsLandings: outTime=\(outTime), departureTime=\(departureTime)")
                    LogManager.shared.debug("updateTakeoffsLandings: blockTime=\(blockTime), blockTimeValue=\(blockTimeValue), arrivalTime=\(arrivalTime)")
                    LogManager.shared.debug("updateTakeoffsLandings: from=\(fromAirport) (\(fromCoords.latitude), \(fromCoords.longitude)), to=\(toAirport) (\(toCoords.latitude), \(toCoords.longitude))")

        // Check if departure is at night
        let isDepartureNight = nightCalcService.isNight(
            at: fromCoords.latitude,
            lon: fromCoords.longitude,
            time: departureTime
        )

        // Check if arrival is at night (check slightly before actual arrival for consistency)
        let isArrivalNight = nightCalcService.isNight(
            at: toCoords.latitude,
            lon: toCoords.longitude,
            time: arrivalCheckTime
        )

                    LogManager.shared.debug("updateTakeoffsLandings: isDepartureNight=\(isDepartureNight), isArrivalNight=\(isArrivalNight)")

        // Set takeoff values
        if isDepartureNight {
            nightTakeoffs = 1
            dayTakeoffs = 0
        } else {
            nightTakeoffs = 0
            dayTakeoffs = 1
        }

        // Set landing values
        if isArrivalNight {
            nightLandings = 1
            dayLandings = 0
        } else {
            nightLandings = 0
            dayLandings = 1
        }

                    LogManager.shared.debug("updateTakeoffsLandings: final values - dayT/O=\(dayTakeoffs), nightT/O=\(nightTakeoffs), dayLdg=\(dayLandings), nightLdg=\(nightLandings)")
    }

    // MARK: - Manual Edit Tracking
    func markTakeoffsLandingsAsManuallyEdited() {
        // Check if all fields are zero - if so, reset the flag to allow auto-calculation
        if dayTakeoffs == 0 && dayLandings == 0 && nightTakeoffs == 0 && nightLandings == 0 {
            hasManuallyEditedTakeoffsLandings = false
        } else {
            hasManuallyEditedTakeoffsLandings = true
        }
    }

    // MARK: - Night Time Calculation (moved from View)
    func updateNightTime() {
        // PERFORMANCE OPTIMIZATION: Build context once and reuse for both calculations
        // This eliminates duplicate airport lookups and date parsing
        if let context = timeCalculationManager.buildCalculationContext(
            fromAirport: fromAirport,
            toAirport: toAirport,
            outTime: outTime,
            blockTime: blockTime,
            flightDate: flightDate
        ) {
            // Use cached context for both calculations
            nightTime = timeCalculationManager.calculateNightTime(using: context)
            updateTakeoffsLandings(using: context)
        } else {
            // Fallback for cases where context can't be built (missing data, editing mode, etc.)
            if isEditingMode && outTime.isEmpty {
                // Preserve existing night time in edit mode
                nightTime = nightTime
            } else {
                nightTime = ""
            }
            // Still need to update takeoffs/landings even if context fails
            updateTakeoffsLandings(using: nil)
        }
    }
    
    // MARK: - Utility Methods
    
    func resetAllFields() {
        HapticManager.shared.impact(.light) // Light haptic for reset action
        selectedImage = nil
        selectedPhotoItem = nil

        // Clear draft data when manually resetting
        clearDraftFlightData()

        // Set date to today's UTC date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        flightDate = dateFormatter.string(from: Date())

        // Reload settings to ensure we have the latest values
        let settings = userDefaultsService.loadSettings()
        logApproaches = settings.logApproaches
        defaultApproachType = settings.defaultApproachType
        aircraftReg = ""

        // Set crew names based on current position
        switch flightTimePosition {
        case .captain:
            captainName = settings.defaultCaptainName
            coPilotName = ""

        case .firstOfficer:
            captainName = ""
            coPilotName = settings.defaultCoPilotName

        case .secondOfficer:
            captainName = ""
            coPilotName = ""
        }

        so1Name = flightTimePosition == .secondOfficer ? settings.defaultSOName : ""
        so2Name = ""
        flightNumber = ""
        fromAirport = ""
        toAirport = ""
        outTime = ""
        inTime = ""
        scheduledDeparture = ""
        scheduledArrival = ""
        blockTime = ""
        isPilotFlying = false

        // Clear approach types when PF is off
        selectedApproachType = nil
        isAIII = false
        isRNP = false
        isILS = false
        isGLS = false
        isNPA = false

        isICUS = false
        isSimulator = false
        isPositioning = false
        remarks = ""
        dayTakeoffs = 0
        dayLandings = 0
        nightTakeoffs = 0
        nightLandings = 0
        hasManuallyEditedTakeoffsLandings = false
        statusMessage = ""
        statusColor = .primary
        aircraftReg = ""

        // Post notification to scroll view to top
        NotificationCenter.default.post(name: .scrollToTop, object: nil)
    }
    
    private func updateFlightDateWithDay(_ dayString: String) {
        guard let day = Int(dayString), day >= 1 && day <= 31 else {
                        LogManager.shared.error("Invalid day extracted: \(dayString)")
            return
        }

        // Use UTC calendar to match the UTC date format used elsewhere
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!

        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = currentMonth
        dateComponents.year = currentYear
        dateComponents.timeZone = TimeZone(abbreviation: "UTC")

        if let newDate = calendar.date(from: dateComponents) {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            let newDateString = formatter.string(from: newDate)

                        LogManager.shared.info("Updated flight date from '\(self.flightDate)' to '\(newDateString)' (day \(day))")
            self.flightDate = newDateString
        }
    }
    
    private func showError(_ message: String) {
        HapticManager.shared.notification(.error) // Error haptic
        errorMessage = message
        showingError = true
        statusMessage = "Error: \(message)"
        statusColor = .red
    }
    
    /// Convert a string in HH:mm to decimal hours string (e.g., "01:30" -> "1.5"). Returns input if parsing fails.
    static func hhmmToDecimal(_ hhmm: String) -> String {
        let trimmed = hhmm.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]) else {
            return trimmed
        }
        let decimal = hours + minutes / 60.0
        return validateTimeString(String(format: "%.1f", decimal))
    }

    /// Convert a decimal hours string to HH:mm (e.g., "1.5" -> "01:30"). Returns empty on invalid input.
    static func decimalToHHMM(_ decimalString: String) -> String {
        let trimmed = decimalString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let decimal = Double(normalized), decimal.isFinite, decimal >= 0 else { return "" }
        var hours = Int(decimal)
        var minutes = Int(round((decimal - Double(hours)) * 60.0))
        if minutes >= 60 {
            hours += 1
            minutes -= 60
        }
        return String(format: "%02d:%02d", hours, minutes)
    }

    /// Parse a UTC time string (HH:MM or HHMM) and combine with a specific date
    /// Delegated to TimeCalculationManager
    private func parseUTCTimeOnDate(_ timeStr: String, on date: Date) -> Date? {
        return timeCalculationManager.parseUTCTimeOnDate(timeStr, on: date)
    }

    /// Calculate flight time from OUT and IN times
    /// Delegated to TimeCalculationManager
    private func calculateFlightTime() -> String {
        return timeCalculationManager.calculateFlightTime(outTime: outTime, inTime: inTime)
    }
    
    // Recalculate block time whenever OUT/IN change and are valid (HH:mm)
    /// Delegated to TimeCalculationManager
    private func recalculateBlockTimeIfPossible() {
        let result = timeCalculationManager.recalculateBlockTime(outTime: outTime, inTime: inTime)
        blockTime = result.blockTime
        updateNightTime()
    }

    /// Validate time in HH:mm (24-hour) format
    /// Delegated to TimeCalculationManager
    private func isValidTimeHHmm(_ s: String) -> Bool {
        return timeCalculationManager.isValidTimeHHmm(s)
    }
  
    /// Recalculate block and night time explicitly after manual edits (called on Save)
    /// Delegated to TimeCalculationManager
    func recalculateTimesAfterManualEdit() {
        // Don't recalculate for PAX (positioning) flights - these should remain blank
        guard !isPositioning else { return }

        let times = timeCalculationManager.recalculateTimes(
            outTime: outTime,
            inTime: inTime,
            fromAirport: fromAirport,
            toAirport: toAirport,
            flightDate: flightDate,
            isEditingMode: isEditingMode,
            existingNightTime: nightTime
        )
        blockTime = times.blockTime
        nightTime = times.nightTime
    }
  
    func addToInternalLogbook() {
        // For simulator flights, allow missing OUT/IN times if block time is present
        if isSimulator {
            guard !blockTime.isEmpty else {
                showError("Block time is required for simulator flights")
                return
            }
        } else {
            guard !outTime.isEmpty && !inTime.isEmpty else {
                showError("No times extracted yet")
                return
            }
        }

        guard !flightDate.isEmpty else {
            showError("Please set flight date")
            return
        }

        statusMessage = "Saving to logbook..."
        statusColor = .blue

        // For simulator flights without OUT/IN times, use the blockTime field directly
        let blockTimeCalculated = (isSimulator && (outTime.isEmpty || inTime.isEmpty)) ? blockTime : calculateFlightTime()
        if nightTime.isEmpty { updateNightTime() }

        // Calculate time credits based on position
        let p1TimeValue: String
        let p1usTimeValue: String
        let p2TimeValue: String

        switch flightTimePosition {
        case .captain:
            p1TimeValue = blockTimeCalculated
            p1usTimeValue = "0.0"
            p2TimeValue = "0.0"
        case .firstOfficer:
            if isICUS && isPilotFlying {
                // First Officer with ICUS and PF gets P1US credit
                p1TimeValue = "0.0"
                p1usTimeValue = blockTimeCalculated
                p2TimeValue = "0.0"
            } else {
                // First Officer without ICUS gets P2 credit
                p1TimeValue = "0.0"
                p1usTimeValue = "0.0"
                p2TimeValue = blockTimeCalculated
            }
        case .secondOfficer:
            // Second Officer gets P2 credit
            p1TimeValue = "0.0"
            p1usTimeValue = "0.0"
            p2TimeValue = blockTimeCalculated
        }

        let instrumentTimeValue = isPilotFlying ? String(format: "%.1f", Double(pfAutoInstrumentMinutes) / 60.0) : "0.0"
        let simTimeValue = isSimulator ? blockTimeCalculated : "0.0"
                    LogManager.shared.debug("DEBUG: addToInternalLogbook PF=\(isPilotFlying), isSimulator=\(isSimulator), instrumentTimeValue=\(instrumentTimeValue), simTime=\(simTimeValue), block=\(blockTimeCalculated), p1=\(p1TimeValue), p1us=\(p1usTimeValue), p2=\(p2TimeValue)")

        let databaseService = FlightDatabaseService.shared

        // Convert airports to ICAO for matching
        let fromICAO = AirportService.shared.convertToICAO(fromAirport)
        let toICAO = AirportService.shared.convertToICAO(toAirport)

        // Check if there's a scheduled flight that matches this actual flight
        if let scheduledFlight = databaseService.findScheduledFlight(
            date: flightDate,
            flightNumber: formattedFlightNumber,
            fromAirport: fromICAO,
            toAirport: toICAO
        ) {
            // Found a matching scheduled flight - update it with actual data
                        LogManager.shared.debug("📋 Found scheduled flight to update")

            let actualFlightData = FlightSector(
                date: flightDate,
                flightNumber: formattedFlightNumber,
                aircraftReg: aircraftReg,
                aircraftType: aircraftType,
                fromAirport: fromICAO,
                toAirport: toICAO,
                captainName: captainName,
                foName: coPilotName,
                so1Name: so1Name.isEmpty ? nil : so1Name,
                so2Name: so2Name.isEmpty ? nil : so2Name,
                blockTime: blockTimeCalculated,
                nightTime: nightTime,
                p1Time: p1TimeValue,
                p1usTime: p1usTimeValue,
                p2Time: p2TimeValue,
                instrumentTime: instrumentTimeValue,
                simTime: simTimeValue,
                isPilotFlying: isPilotFlying,
                isPositioning: isPositioning,
                isAIII: isPilotFlying && isAIII,
                isRNP: isPilotFlying && isRNP,
                isILS: isPilotFlying && isILS,
                isGLS: isPilotFlying && isGLS,
                isNPA: isPilotFlying && isNPA,
                remarks: remarks,
                dayTakeoffs: dayTakeoffs,
                dayLandings: dayLandings,
                nightTakeoffs: nightTakeoffs,
                nightLandings: nightLandings,
                outTime: outTime,
                inTime: inTime,
                scheduledDeparture: scheduledDeparture,
                scheduledArrival: scheduledArrival
            )

            if databaseService.updateScheduledFlightWithActualData(scheduledFlight, actualData: actualFlightData) {
                            LogManager.shared.debug("Successfully updated scheduled flight with ACARS data")
                statusMessage = "Flight updated from roster to actual!"
                statusColor = .green

                // Clear draft data after successful save
                clearDraftFlightData()

                // Database service observers will automatically post .flightDataChanged notification
            } else {
                            LogManager.shared.debug("Failed to update scheduled flight")
                showError("Failed to update scheduled flight")
            }
        } else {
            // No matching scheduled flight found - create new flight as normal
                        LogManager.shared.debug("ℹ️ No scheduled flight found - creating new flight")

            let newFlight = FlightSector(
                date: flightDate,
                flightNumber: formattedFlightNumber,
                aircraftReg: aircraftReg,
                aircraftType: aircraftType,
                fromAirport: fromICAO,
                toAirport: toICAO,
                captainName: captainName,
                foName: coPilotName,
                so1Name: so1Name.isEmpty ? nil : so1Name,
                so2Name: so2Name.isEmpty ? nil : so2Name,
                blockTime: blockTimeCalculated,
                nightTime: nightTime,
                p1Time: p1TimeValue,
                p1usTime: p1usTimeValue,
                p2Time: p2TimeValue,
                instrumentTime: instrumentTimeValue,
                simTime: simTimeValue,
                isPilotFlying: isPilotFlying,
                isPositioning: isPositioning,
                isAIII: isPilotFlying && isAIII,
                isRNP: isPilotFlying && isRNP,
                isILS: isPilotFlying && isILS,
                isGLS: isPilotFlying && isGLS,
                isNPA: isPilotFlying && isNPA,
                remarks: remarks,
                dayTakeoffs: dayTakeoffs,
                dayLandings: dayLandings,
                nightTakeoffs: nightTakeoffs,
                nightLandings: nightLandings,
                outTime: outTime,
                inTime: inTime,
                scheduledDeparture: scheduledDeparture,
                scheduledArrival: scheduledArrival
            )
                        LogManager.shared.debug("DEBUG: New FlightSector instrumentTime=\(newFlight.instrumentTime), PF=\(newFlight.isPilotFlying), date=\(newFlight.date), flt=\(newFlight.flightNumber), isSimulator=\(isSimulator), simTime=\(newFlight.simTime), blockTime=\(newFlight.blockTime), p2Time=\(newFlight.p2Time)")

            if databaseService.saveFlight(newFlight) {
                            LogManager.shared.debug("DEBUG: Saved sector successfully with instrumentTime=\(newFlight.instrumentTime)")
                statusMessage = "Flight saved to logbook!"
                statusColor = .green

                // Clear draft data after successful save
                clearDraftFlightData()

                // Database service observers will automatically post .flightDataChanged notification
            } else {
                            LogManager.shared.debug("DEBUG: Failed to save sector (instrumentTime was \(newFlight.instrumentTime))")
                showError("Failed to save flight to logbook")
            }
        }
    }


    // MARK: - CSV Import Methods
        
        /// Import logbook data from a CSV file
        /// Delegated to LogbookImportService
        func importLogbookData(from fileURL: URL) {
            statusMessage = "Importing logbook data..."
            statusColor = .blue
            isImporting = true
            importCompleted = false

            Task {
                let result = await logbookImportService.importLogbookData(from: fileURL)

                await MainActor.run {
                    switch result {
                    case .success(let importResult):
                        self.lastImportSuccessCount = importResult.successCount
                        self.lastImportFailureCount = importResult.failureCount

                        if importResult.isFullSuccess {
                            self.statusMessage = "Successfully imported \(importResult.successCount) flights!"
                            self.statusColor = .green
                        } else {
                            self.statusMessage = "Imported \(importResult.successCount) flights, \(importResult.failureCount) failed"
                            self.statusColor = .orange
                        }
                        self.isImporting = false
                        self.importCompleted = true

                    case .failure(let error):
                        self.isImporting = false
                        self.showError(error.localizedDescription)
                    }
                }
            }
        }

        /// Handle import errors
        func handleImportError(_ error: Error) {
            showError("File selection failed: \(error.localizedDescription)")
        }

        /// Import logbook data from a tab-delimited file
        /// Delegated to LogbookImportService
        func importTabDelimitedLogbookData(from fileURL: URL) {
            statusMessage = "Importing tab-delimited logbook data..."
            statusColor = .blue
            isImporting = true
            importCompleted = false

            Task {
                let result = await logbookImportService.importTabDelimitedLogbookData(from: fileURL)

                await MainActor.run {
                    switch result {
                    case .success(let importResult):
                        self.lastImportSuccessCount = importResult.successCount
                        self.lastImportFailureCount = importResult.failureCount

                        if importResult.isFullSuccess {
                            self.statusMessage = "Successfully imported \(importResult.successCount) flights!"
                            self.statusColor = .green
                        } else {
                            self.statusMessage = "Imported \(importResult.successCount) flights, \(importResult.failureCount) failed"
                            self.statusColor = .orange
                        }
                        self.isImporting = false
                        self.importCompleted = true

                    case .failure(let error):
                        self.isImporting = false
                        self.showError(error.localizedDescription)
                    }
                }
            }
        }

    
    
    func debugTogglePhotoSaving(_ newValue: Bool) {
                    LogManager.shared.debug("🔧 DEBUG: Toggle called with value: \(newValue)")
                    LogManager.shared.debug("🔧 DEBUG: Current savePhotosToLibrary: \(savePhotosToLibrary)")
                    LogManager.shared.debug("🔧 DEBUG: Has photo permission: \(hasPhotoPermission())")
                    LogManager.shared.debug("🔧 DEBUG: Photo permission status: \(getPhotoPermissionStatus())")

        // Force update the setting regardless of permission (for testing)
        savePhotosToLibrary = newValue
        userDefaultsService.setSavePhotosToLibrary(newValue)

                    LogManager.shared.debug("🔧 DEBUG: After update - savePhotosToLibrary: \(savePhotosToLibrary)")
    }

    // MARK: - FlightAware Integration

    /// Fetch flight data from FlightAware for the current flight number and date
    func fetchFlightAwareData() {
        // Validate we have required data
        guard !flightNumber.isEmpty else {
            showError("Please enter a flight number first")
            return
        }

        guard !flightDate.isEmpty else {
            showError("Please select a flight date first")
            return
        }

        // Convert flight number to FlightAware format
        guard let flightAwareCode = flightNumber.toFlightAwareFormat(
            userAirlinePrefix: includeAirlinePrefixInFlightNumber ? nil : airlinePrefix
        ) else {
            showError("Invalid flight number format")
            return
        }

        isFetchingFlightAware = true
        statusMessage = "Fetching flight data from FlightAware..."
        statusColor = .blue
        HapticManager.shared.impact(.medium)

        Task {
            do {
                let flightDataArray = try await flightAwareService.fetchFlightData(
                    flightNumber: flightAwareCode,
                    date: flightDate
                )

                // print("ViewModel: Received \(flightDataArray.count) flight segment(s)")

                await MainActor.run {
                    self.isFetchingFlightAware = false

                    if flightDataArray.isEmpty {
                        self.showError("No flights found for this date")
                        HapticManager.shared.notification(.error)
                    } else if flightDataArray.count == 1 {
                        // Single flight - populate directly
                        let flightData = flightDataArray[0]
                        //print("📝 ViewModel: Populating form with single flight: \(flightData.origin) → \(flightData.destination)")
                        self.populateFieldsWithFlightData(flightData)
                        self.statusMessage = "Flight data retrieved successfully!"
                        self.statusColor = .green
                        HapticManager.shared.notification(.success)
                    } else {
                        // Multiple flights - show selection sheet
                        //print("📋 ViewModel: Multiple segments found - showing selection sheet")
                        self.flightSegments = flightDataArray
                        self.showingSegmentSelection = true
                        self.statusMessage = "Multiple segments found - select one"
                        self.statusColor = .orange
                        HapticManager.shared.impact(.light)
                    }
                }

            } catch {
                            LogManager.shared.debug("ViewModel: Error fetching flight data - \(error.localizedDescription)")
                await MainActor.run {
                    self.isFetchingFlightAware = false
                    self.showError(error.localizedDescription)
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    /// Populate form fields with selected flight data
    func populateFieldsWithFlightData(_ flightData: FlightAwareData) {
        self.fromAirport = self.normalizeAirportCode(flightData.origin)
        self.toAirport = self.normalizeAirportCode(flightData.destination)
        self.outTime = flightData.departureTime
        self.inTime = flightData.arrivalTime

        // Populate scheduled times if available
        if let std = flightData.scheduledDepartureTime {
            self.scheduledDeparture = std
        }
        if let sta = flightData.scheduledArrivalTime {
            self.scheduledArrival = sta
        }

        // Recalculate block time and night time
        self.recalculateTimesAfterManualEdit()
    }

    // MARK: - Draft Flight Data Persistence

    private static let draftFlightDataKey = "draftFlightData"

    /// Save current form state as draft (called when app backgrounds)
    func saveDraftFlightData() {
        // Don't save drafts when in editing mode - we don't want to overwrite an existing flight's data
        guard !isEditingMode else {
                        LogManager.shared.debug("📝 Skipping draft save - in editing mode")
            return
        }

        // Check if there's any meaningful data to save
        let hasData = !flightNumber.isEmpty ||
                      !fromAirport.isEmpty ||
                      !toAirport.isEmpty ||
                      !outTime.isEmpty ||
                      !inTime.isEmpty ||
                      !aircraftReg.isEmpty ||
                      !remarks.isEmpty

        guard hasData else {
                        LogManager.shared.debug("📝 Skipping draft save - no data entered")
            return
        }

        let draft = DraftFlightData(
            timestamp: Date(),
            flightDate: flightDate,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: fromAirport,
            toAirport: toAirport,
            flightNumber: flightNumber,
            blockTime: blockTime,
            nightTime: nightTime,
            captainName: captainName,
            coPilotName: coPilotName,
            so1Name: so1Name,
            so2Name: so2Name,
            isPilotFlying: isPilotFlying,
            selectedApproachType: selectedApproachType,
            isSimulator: isSimulator,
            isPositioning: isPositioning,
            outTime: outTime,
            inTime: inTime,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival,
            isICUS: isICUS,
            remarks: remarks,
            dayTakeoffs: dayTakeoffs,
            dayLandings: dayLandings,
            nightTakeoffs: nightTakeoffs,
            nightLandings: nightLandings,
            hasManuallyEditedTakeoffsLandings: hasManuallyEditedTakeoffsLandings
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(draft)
            UserDefaults.standard.set(data, forKey: Self.draftFlightDataKey)
                        LogManager.shared.debug("💾 Draft flight data saved successfully")
        } catch {
                        LogManager.shared.debug("Failed to save draft flight data: \(error)")
        }
    }

    /// Restore draft flight data if available and not expired
    func restoreDraftFlightData() {
        guard let data = UserDefaults.standard.data(forKey: Self.draftFlightDataKey) else {
                        LogManager.shared.debug("📝 No draft flight data found")
            return
        }

        do {
            let decoder = JSONDecoder()
            let draft = try decoder.decode(DraftFlightData.self, from: data)

            // Check if draft is expired
            if draft.isExpired {
                            LogManager.shared.debug("📝 Draft flight data expired (older than 24 hours) - clearing")
                clearDraftFlightData()
                return
            }

            // Restore all fields from draft
                        LogManager.shared.debug("💾 Restoring draft flight data from \(draft.timestamp)")
            flightDate = draft.flightDate
            aircraftReg = draft.aircraftReg
            aircraftType = draft.aircraftType
            fromAirport = draft.fromAirport
            toAirport = draft.toAirport
            flightNumber = draft.flightNumber
            blockTime = draft.blockTime
            nightTime = draft.nightTime
            captainName = draft.captainName
            coPilotName = draft.coPilotName
            so1Name = draft.so1Name
            so2Name = draft.so2Name
            isPilotFlying = draft.isPilotFlying
            selectedApproachType = draft.selectedApproachType
            isSimulator = draft.isSimulator
            isPositioning = draft.isPositioning
            outTime = draft.outTime
            inTime = draft.inTime
            scheduledDeparture = draft.scheduledDeparture
            scheduledArrival = draft.scheduledArrival
            isICUS = draft.isICUS
            remarks = draft.remarks
            dayTakeoffs = draft.dayTakeoffs
            dayLandings = draft.dayLandings
            nightTakeoffs = draft.nightTakeoffs
            nightLandings = draft.nightLandings
            hasManuallyEditedTakeoffsLandings = draft.hasManuallyEditedTakeoffsLandings

            // Update approach booleans based on selectedApproachType
            updateSelectedApproachType(selectedApproachType)

                        LogManager.shared.debug("Draft flight data restored successfully")
        } catch {
                        LogManager.shared.debug("Failed to restore draft flight data: \(error)")
            clearDraftFlightData()
        }
    }

    /// Clear saved draft flight data
    func clearDraftFlightData() {
        UserDefaults.standard.removeObject(forKey: Self.draftFlightDataKey)
    }

    /// Check if draft data exists
    var hasDraftFlightData: Bool {
        UserDefaults.standard.data(forKey: Self.draftFlightDataKey) != nil
    }
}
