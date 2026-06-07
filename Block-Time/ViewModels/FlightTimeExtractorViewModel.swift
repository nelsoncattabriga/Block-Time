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
    var isSpIns: Bool = false
    var spInsTime: String = ""
    var simInsTime: String = ""
    let isPositioning: Bool
    let outTime: String
    let inTime: String
    let scheduledDeparture: String
    let scheduledArrival: String
    let isICUS: Bool
    let selectedTimeCredit: TimeCreditType
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
    private let aeroDataBoxService = AeroDataBoxService.shared

    // MARK: - Background task handles
    private var crewNamesReloadTask: Task<Void, Never>?
    private var nightTimeCalculationTask: Task<Void, Never>?
    
    // MARK: - Published Properties
    @Published var selectedImage: UIImage?
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var isExtracting = false
    @Published var showingCamera = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var showingCaptureError = false
    @Published var captureErrorMessage = ""
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
    @Published var enterTimesInLocalTime = false

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
    @Published var isPilotFlying = false {
        didSet {
            // Auto-update time credit when F/O toggles PF
            // Only do this when not in editing mode and when position is F/O
            if !isEditingMode && flightTimePosition == .firstOfficer {
                if isPilotFlying {
                    // F/O + PF = use the foPilotFlyingCredit setting (ICUS or P2)
                    selectedTimeCredit = foPilotFlyingCredit
                    isTimeCreditManualOverride = false
                } else {
                    // F/O + not PF = P2
                    selectedTimeCredit = .p2
                    isTimeCreditManualOverride = false
                }
            }
        }
    }
    @Published var isAIII = false
    @Published var isRNP = false
    @Published var isILS = false
    @Published var isGLS = false
    @Published var isNPA = false
    @Published var selectedApproachType: String? = nil  // "AIII", "RNP", "ILS", "GLS", "NPA", or nil
    @Published var isSimulator = false {
        didSet { isPilotFlying = isSimulator }
    }
    @Published var isSpIns = false
    @Published var spInsTime = ""
    @Published var simInsTime = ""          // SIM portion of an INS Sim session (0…spInsTime)
    private var simInsTimeIsManual = false  // true once user manually edits the SIM field
    @Published var isPositioning = false
    @Published var outTime = ""
    @Published var inTime = ""
    @Published var scheduledDeparture = ""  // STD - Scheduled Time of Departure
    @Published var scheduledArrival = ""     // STA - Scheduled Time of Arrival
    @Published var isICUS = false
    @Published var selectedTimeCredit: TimeCreditType = .p1 {  // Explicit time credit selection
        didSet {
            // Keep isICUS in sync with selectedTimeCredit for backward compatibility
            isICUS = (selectedTimeCredit == .p1us)
        }
    }
    @Published var remarks = ""
    @Published var counterValues: [Int: String] = [:]
    @Published var dayTakeoffs = 0
    @Published var dayLandings = 0
    @Published var nightTakeoffs = 0
    @Published var nightLandings = 0

    // Manual edit tracking flags for takeoffs/landings
    @Published var hasManuallyEditedTakeoffsLandings = false

    // Tracks whether the user has manually overridden the auto-selected time credit
    @Published var isTimeCreditManualOverride = false

    // Settings properties
    @Published var defaultCaptainName = ""
    @Published var defaultCoPilotName = ""
    @Published var defaultSOName = ""
    @Published var flightTimePosition = FlightTimePosition.captain
    @Published var foPilotFlyingCredit: TimeCreditType = .p1us  // What time credit to use when F/O is PF
    @Published var includeLeadingZeroInFlightNumber = false
    @Published var includeAirlinePrefixInFlightNumber = false
    @Published var airlinePrefix = "QF"
    @Published var isCustomAirlinePrefix = false
    @Published var showFullAircraftReg = true
    @Published var savePhotosToLibrary = false  // NEW SETTING
    @Published var showSONameFields = false  // Show/hide SO 1 and SO 2 fields
    @Published var logCustomCount = false    // Show/hide custom counter field
    @Published var customCountLabel = "Passengers" // Label for the custom counter
    @Published var showSpInsSelector = false // Show/hide INS toggle for Sp/Ins logging
    @Published var defaultInstructionEnvironment: InstructionEnvironment = .simulator
    @Published var isInstructingInAircraft = false // true = aircraft instruction (counts as P1), false = sim instruction
    @Published var pfAutoInstrumentMinutes: Int = 30
    @Published var useIATACodes = false  // Display airport codes in IATA format
    @Published var logApproaches = false  // Auto-log approaches toggle
    @Published var defaultApproachType: String? = nil  // Default approach type
    @Published var showTimesInHoursMinutes = false  // Show times in HH:MM format
    @Published var showOutInTimes = true  // Show OUT/IN (and STD/STA) times in the flights list
    @Published var countSimInTotal = true  // Include SIM time in Total flight time
    @Published var selectedFleetID = "B737"  // Selected fleet for filtering
    @Published var decimalRoundingMode: RoundingMode = .standard  // Rounding mode for decimal times

    // Saved crew names — unified list shared across all roles
    @Published var savedCrewNames: [String] = []

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
        // For simulator flights, only require block time and date (airports and OUT/IN times optional)
        if isSimulator {
            return !blockTime.isEmpty && !flightDate.isEmpty
        }
        // For Sp/Ins flights: sim needs spInsTime, aircraft needs blockTime (same as regular flight)
        if isSpIns && !isInstructingInAircraft {
            return !spInsTime.isEmpty && !flightDate.isEmpty
        }
        // For regular flights, require date and airports, plus either OUT/IN times, STD/STA, or a manual block time
        let hasActualTimes = !outTime.isEmpty && !inTime.isEmpty
        let hasScheduledTimes = !scheduledDeparture.isEmpty && !scheduledArrival.isEmpty
        let hasManualBlockTime = !blockTime.isEmpty && blockTime != "0.0"
        return !flightDate.isEmpty && !fromAirport.isEmpty && !toAirport.isEmpty && (hasActualTimes || hasScheduledTimes || hasManualBlockTime)
    }

    /// Named requirement checks used to drive the dot indicators on the Save button and field labels.
    struct SaveRequirements {
        let date: Bool
        let airports: Bool
        let out: Bool
        let `in`: Bool
        let blockOrInsTime: Bool
        let blockOrInsTimeLabel: String
        let needsAirports: Bool
        let needsBlockOrInsTime: Bool

        /// True when OUT+IN are both filled, or STD+STA are both filled
        var times: Bool { out && `in` }
    }

    var saveRequirements: SaveRequirements {
        let hasOut = !outTime.isEmpty
        let hasIn  = !inTime.isEmpty
        let hasStd = !scheduledDeparture.isEmpty
        let hasSta = !scheduledArrival.isEmpty
        // Either actual or scheduled pair counts as times satisfied
        let timesOut = hasOut || hasStd
        let timesIn  = hasIn  || hasSta

        if isSimulator {
            return SaveRequirements(
                date: !flightDate.isEmpty,
                airports: false,
                out: false,
                in: false,
                blockOrInsTime: !blockTime.isEmpty,
                blockOrInsTimeLabel: "SIM Time",
                needsAirports: false,
                needsBlockOrInsTime: true
            )
        }
        if isSpIns && !isInstructingInAircraft {
            return SaveRequirements(
                date: !flightDate.isEmpty,
                airports: false,
                out: false,
                in: false,
                blockOrInsTime: !spInsTime.isEmpty,
                blockOrInsTimeLabel: "INS Time",
                needsAirports: false,
                needsBlockOrInsTime: true
            )
        }
        let hasManualBlockTime = !blockTime.isEmpty && blockTime != "0.0"
        return SaveRequirements(
            date: !flightDate.isEmpty,
            airports: !fromAirport.isEmpty && !toAirport.isEmpty,
            out: timesOut || hasManualBlockTime,
            in: timesIn || hasManualBlockTime,
            blockOrInsTime: false,
            blockOrInsTimeLabel: "",
            needsAirports: true,
            needsBlockOrInsTime: false
        )
    }

    var formattedFlightNumber: String {
        // Don't format flight numbers for simulator or Sp/Ins flights
        if isSimulator || isSpIns {
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

        // Observe flight data changes to refresh crew names (e.g., after CSV import).
        // Guard against editing mode: firing during an active edit causes stacked Core Data
        // fetches on the main thread (CloudKit sync storm scenario → watchdog kill).
        // Debounce so rapid CloudKit notifications collapse into a single reload.
        NotificationCenter.default.addObserver(
            forName: .flightDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isEditingMode else { return }
                self.crewNamesReloadTask?.cancel()
                self.crewNamesReloadTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    self.reloadSavedCrewNames()
                }
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

    func restoreDefaultsAfterPositioning() {
        guard !isEditingMode else { return }
        switch flightTimePosition {
        case .captain:
            if captainName.isEmpty { captainName = defaultCaptainName }
        case .firstOfficer:
            if coPilotName.isEmpty { coPilotName = defaultCoPilotName }
        case .secondOfficer:
            if so1Name.isEmpty { so1Name = defaultSOName }
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

        defaultCaptainName = settings.defaultCaptainName
        defaultCoPilotName = settings.defaultCoPilotName
        defaultSOName = settings.defaultSOName
        flightTimePosition = settings.flightTimePosition
        foPilotFlyingCredit = settings.foPilotFlyingCredit
        includeLeadingZeroInFlightNumber = settings.includeLeadingZeroInFlightNumber
        includeAirlinePrefixInFlightNumber = settings.includeAirlinePrefixInFlightNumber
        airlinePrefix = settings.airlinePrefix
        isCustomAirlinePrefix = settings.isCustomAirlinePrefix
        showFullAircraftReg = settings.showFullAircraftReg
        savePhotosToLibrary = settings.savePhotosToLibrary  // NEW SETTING LOAD
        showSONameFields = settings.showSONameFields  // Load SO fields visibility setting
        logCustomCount = settings.logCustomCount
        customCountLabel = settings.customCountLabel
        showSpInsSelector = settings.showSpInsSelector
        defaultInstructionEnvironment = settings.defaultInstructionEnvironment
        if settings.showSpInsSelector {
            isInstructingInAircraft = settings.defaultInstructionEnvironment == .aircraft
        }
        pfAutoInstrumentMinutes = settings.pfAutoInstrumentMinutes
        displayFlightsInLocalTime = settings.displayFlightsInLocalTime
        enterTimesInLocalTime = settings.enterTimesInLocalTime
        useIATACodes = settings.useIATACodes
        logApproaches = settings.logApproaches
        defaultApproachType = settings.defaultApproachType
        showTimesInHoursMinutes = settings.showTimesInHoursMinutes
        showOutInTimes = settings.showOutInTimes
        countSimInTotal = settings.countSimInTotal
        selectedFleetID = settings.selectedFleetID
        decimalRoundingMode = settings.decimalRoundingMode
        recentCaptainNames = settings.recentCaptainNames
        recentCoPilotNames = settings.recentCoPilotNames
        recentSONames = settings.recentSONames
        recentAircraftRegs = settings.recentAircraftRegs
        recentAirports = userDefaultsService.getRecentAirports()

        // Merge saved crew names with database crew names (includes CSV imported names)
        reloadSavedCrewNames()

        // Derive initial selectedTimeCredit from loaded position (isPilotFlying is false at this point)
        resetTimeCreditOverride()
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
            case "defaultCaptainName":
                defaultCaptainName = settings.defaultCaptainName
            case "defaultCoPilotName":
                defaultCoPilotName = settings.defaultCoPilotName
            case "defaultSOName":
                defaultSOName = settings.defaultSOName
            case "flightTimePosition":
                flightTimePosition = settings.flightTimePosition
            case "foPilotFlyingCredit":
                foPilotFlyingCredit = settings.foPilotFlyingCredit
            case "includeLeadingZeroInFlightNumber":
                includeLeadingZeroInFlightNumber = settings.includeLeadingZeroInFlightNumber
            case "includeAirlinePrefixInFlightNumber":
                includeAirlinePrefixInFlightNumber = settings.includeAirlinePrefixInFlightNumber
            case "airlinePrefix":
                airlinePrefix = settings.airlinePrefix
            case "isCustomAirlinePrefix":
                isCustomAirlinePrefix = settings.isCustomAirlinePrefix
            case "showFullAircraftReg":
                showFullAircraftReg = settings.showFullAircraftReg
            case "savedCrewNames":
                savedCrewNames = settings.savedCrewNames
            case "savePhotosToLibrary":
                savePhotosToLibrary = settings.savePhotosToLibrary
            case "showSONameFields":
                showSONameFields = settings.showSONameFields
            case "logCustomCount":
                logCustomCount = settings.logCustomCount
            case "customCountLabel":
                customCountLabel = settings.customCountLabel
            case "showSpInsSelector":
                showSpInsSelector = settings.showSpInsSelector
            case "defaultInstructionEnvironment":
                defaultInstructionEnvironment = settings.defaultInstructionEnvironment
            case "pfAutoInstrumentMinutes":
                pfAutoInstrumentMinutes = settings.pfAutoInstrumentMinutes
            case "displayFlightsInLocalTime":
                displayFlightsInLocalTime = settings.displayFlightsInLocalTime
            case "enterTimesInLocalTime":
                enterTimesInLocalTime = settings.enterTimesInLocalTime
            case "useIATACodes":
                            LogManager.shared.debug("   Updating useIATACodes: \(useIATACodes) -> \(settings.useIATACodes)")
                useIATACodes = settings.useIATACodes
            case "logApproaches":
                logApproaches = settings.logApproaches
            case "defaultApproachType":
                defaultApproachType = settings.defaultApproachType
            case "showTimesInHoursMinutes":
                showTimesInHoursMinutes = settings.showTimesInHoursMinutes
            case "showOutInTimes":
                showOutInTimes = settings.showOutInTimes
            case "countSimInTotal":
                countSimInTotal = settings.countSimInTotal
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

            // FRMS settings - handled by FRMSViewModel
            case "frmsShowFRMS", "frmsFleet", "frmsHomeBase", "frmsDefaultLimitType",
                 "frmsShowWarningsAtPercentage", "frmsSignOnMinutesBeforeSTD", "frmsSignOffMinutesAfterIN":
                break  // Handled by FRMSViewModel

            // Backup settings - handled by AutomaticBackupService
            case "backupIsEnabled", "backupFrequency", "backupLocation", "backupMaxToKeep":
                break  // Handled by AutomaticBackupService

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
        savedCrewNames = userDefaultsService.addSOName(name)
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

    func userEditedSimInsTime(_ value: String) {
        simInsTimeIsManual = !value.isEmpty
        simInsTime = value
    }

    func resetSimInsTime() {
        simInsTime = ""
        simInsTimeIsManual = false
    }

    func updateFlightTimePosition(_ value: FlightTimePosition) {
        flightTimePosition = value
        userDefaultsService.setFlightTimePosition(value)

        // Update selectedTimeCredit to match the new position (but only when not editing)
        if !isEditingMode {
            switch value {
            case .captain:
                selectedTimeCredit = .p1
            case .firstOfficer:
                selectedTimeCredit = .p2  // Default to P2, can manually change to P1US
            case .secondOfficer:
                selectedTimeCredit = .p2
            }
            isTimeCreditManualOverride = false
        }

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

    func setTimeCreditWithOverride(_ value: TimeCreditType) {
        selectedTimeCredit = value
        isTimeCreditManualOverride = true
        HapticManager.shared.impact(.medium)
    }

    func resetTimeCreditOverride() {
        isTimeCreditManualOverride = false
        // Re-derive the auto value from current state
        if isPositioning || isSimulator || isSpIns { return }
        if flightTimePosition == .firstOfficer {
            selectedTimeCredit = isPilotFlying ? foPilotFlyingCredit : .p2
        } else if flightTimePosition == .captain {
            selectedTimeCredit = .p1
        } else {
            selectedTimeCredit = .p2
        }
    }

    func updateFOPilotFlyingCredit(_ value: TimeCreditType) {
        foPilotFlyingCredit = value
        userDefaultsService.setFOPilotFlyingCredit(value)

        // Update selectedTimeCredit if currently F/O and PF
        if !isEditingMode && flightTimePosition == .firstOfficer && isPilotFlying {
            selectedTimeCredit = value
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

    func updateIsCustomAirlinePrefix(_ value: Bool) {
        isCustomAirlinePrefix = value
        userDefaultsService.setIsCustomAirlinePrefix(value)
    }

    func updateShowFullAircraftReg(_ value: Bool) {
        showFullAircraftReg = value
        userDefaultsService.setShowFullAircraftReg(value)
    }
    
    func updateSavePhotosToLibrary(_ value: Bool) {
        savePhotosToLibrary = value
        userDefaultsService.setSavePhotosToLibrary(value)
    }
    
    func updateShowSpInsSelector(_ value: Bool) {
        showSpInsSelector = value
        userDefaultsService.setShowSpInsSelector(value)
    }

    func updateDefaultInstructionEnvironment(_ value: InstructionEnvironment) {
        defaultInstructionEnvironment = value
        userDefaultsService.setDefaultInstructionEnvironment(value)
    }

    func updateShowSONameFields(_ value: Bool) {
        showSONameFields = value
        userDefaultsService.setShowSONameFields(value)
    }

    func updateLogCustomCount(_ value: Bool) {
        logCustomCount = value
        userDefaultsService.setLogCustomCount(value)
    }

    func updateCustomCountLabel(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? "Passengers" : String(trimmed.prefix(20))
        customCountLabel = label
        userDefaultsService.setCustomCountLabel(label)
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

    func updateEnterTimesInLocalTime(_ value: Bool) {
        enterTimesInLocalTime = value
        userDefaultsService.setEnterTimesInLocalTime(value)
    }

    /// The UTC date used for storage and change-detection comparisons.
    /// When enterTimesInLocalTime is on, flightDate holds the local departure date,
    /// so we convert back to UTC here. Otherwise returns flightDate unchanged.
    ///
    /// Uses the UTC outTime (adjusted to approximate local time via base offset) as the
    /// conversion reference so the UTC date is correct for both same-day and cross-day
    /// flights. Using "00:00" local would be wrong for flights where UTC date = local date
    /// (e.g., 01:00 UTC in AEDT+11 is 12:00 local — midnight local maps to previous UTC day).
    var flightDateForStorage: String {
        guard enterTimesInLocalTime, !fromAirport.isEmpty, !flightDate.isEmpty else {
            return flightDate
        }
        let icao = AirportService.shared.convertToICAO(fromAirport)

        // Pick the best available UTC departure time reference.
        let utcTimeRef: String
        if outTime.count == 5, outTime.contains(":") {
            utcTimeRef = outTime
        } else if !scheduledDeparture.isEmpty {
            utcTimeRef = scheduledDeparture  // "HHMM" accepted by convertFromLocalToUTCDate
        } else {
            utcTimeRef = "11:00"
        }

        // Compute approximate local departure time = UTC time + base offset (hours).
        // convertFromLocalToUTCDate applies DST internally, so we only need this
        // to determine which calendar day the local date falls on.
        guard let baseOffset = AirportService.shared.getTimezoneOffset(for: icao) else {
            return flightDate
        }
        let cleanTime = utcTimeRef.replacingOccurrences(of: ":", with: "")
        let localTimeRef: String
        if cleanTime.count >= 4,
           let utcHour = Int(cleanTime.prefix(2)),
           let utcMin = Int(cleanTime.suffix(2)) {
            let utcMins = utcHour * 60 + utcMin
            let offsetMins = Int(baseOffset * 60)
            let localMins = ((utcMins + offsetMins) % 1440 + 1440) % 1440
            localTimeRef = String(format: "%02d:%02d", localMins / 60, localMins % 60)
        } else {
            localTimeRef = "11:00"
        }

        return AirportService.shared.convertFromLocalToUTCDate(
            localDateString: flightDate,
            localTimeString: localTimeRef,
            airportICAO: icao
        )
    }

    /// UTC offset label for the departure airport when local time entry is active (e.g., "UTC+10").
    /// Returns empty string if the airport or date is unknown.
    var outTimezoneLabel: String {
        guard enterTimesInLocalTime, !fromAirport.isEmpty, !flightDate.isEmpty else { return "" }
        let icao = AirportService.shared.convertToICAO(fromAirport)
        return AirportService.shared.getTimezoneOffsetLabel(for: icao, dateString: flightDate)
    }

    /// UTC offset label for the arrival airport when local time entry is active (e.g., "UTC+11").
    /// Returns empty string if the airport or date is unknown.
    var inTimezoneLabel: String {
        guard enterTimesInLocalTime, !toAirport.isEmpty, !flightDate.isEmpty else { return "" }
        let icao = AirportService.shared.convertToICAO(toAirport)
        return AirportService.shared.getTimezoneOffsetLabel(for: icao, dateString: flightDate)
    }

    func updateUseIATACodes(_ value: Bool) {
        useIATACodes = value
        userDefaultsService.setUseIATACodes(value)
        Task { WidgetDataWriter.shared.updateWidgetSnapshot() }
    }

    func updateShowTimesInHoursMinutes(_ value: Bool) {
        showTimesInHoursMinutes = value
        userDefaultsService.setShowTimesInHoursMinutes(value)
    }

    func updateShowOutInTimes(_ value: Bool) {
        showOutInTimes = value
        userDefaultsService.setShowOutInTimes(value)
    }

    func updateCountSimInTotal(_ value: Bool) {
        countSimInTotal = value
        userDefaultsService.setCountSimInTotal(value)
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
        if fleetID == "B737" || fleetID == "A320" {
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

        // Only allow approach type selection if PF (or SIM — simulator sessions can log approaches for recency)
        guard isPilotFlying || isSimulator else {
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
        let fleetType: FleetType
        switch selectedFleetID {
        case "B787": fleetType = .b787
        case "A330": fleetType = .a330
        case "A320": fleetType = .a321
        case "A380": fleetType = .a380
        default:     fleetType = .b737
        }

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
                // Handle partial extraction - populate what we have and show capture-retry alert
                await MainActor.run {
                    self.updateFieldsWithFlightData(error.partialData)
                    self.isExtracting = false
                    self.selectedImage = nil
                    self.selectedPhotoItem = nil
                    self.statusMessage = "Partial extraction"
                    self.statusColor = .orange
                    self.showCaptureError(error.localizedDescription)
                }
            } catch {
                await MainActor.run {
                    self.isExtracting = false
                    self.selectedImage = nil
                    self.selectedPhotoItem = nil
                    self.showCaptureError(error.localizedDescription)
                }
            }
        }
    }
    
    private func updateFieldsWithFlightData(_ flightData: FlightData) {
        outTime = flightData.outTime
        inTime = flightData.inTime

        // Always calculate block time from OUT/IN times.
        // The extracted BLK from ACARS is used only for validation (in validateAndCorrectTimeSequence)
        // and is not used directly here.
        blockTime = calculateFlightTime()

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
                        LogManager.shared.debug(" Deferring night time calculation for B787 - airports need to be entered manually")
        }

        // After populating ACARS data, check for a matching scheduled/future flight
        // and pre-fill empty fields with data from the roster.
        // Skip when editing — the flight is already loaded, no need to search for a match.
        if !isEditingMode {
            prefillFromMatchingScheduledFlight()
        }
    }

    /// Search for a matching scheduled flight and pre-fill empty form fields with its data
    private func prefillFromMatchingScheduledFlight() {
        // Need at least date and flight number to attempt matching
        guard !flightDate.isEmpty, !flightNumber.isEmpty else {
            LogManager.shared.debug(" Not enough data to search for matching scheduled flight (need date and flight number)")
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
            LogManager.shared.debug(" Airports not available - searching by date and flight number only")
            scheduledFlight = databaseService.findScheduledFlightByDateAndFlightNumber(
                date: flightDate,
                flightNumber: formattedFlightNumber
            )
        }

        guard let scheduledFlight = scheduledFlight else {
            LogManager.shared.debug(" No matching scheduled flight found for pre-fill")
            return
        }

        LogManager.shared.info(" Found matching scheduled flight - pre-filling form with roster data")

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
        guard !flightNumber.isEmpty else { return flightNumber }

        var formatted = flightNumber

        if includeAirlinePrefixInFlightNumber {
            if !formatted.hasPrefix(airlinePrefix) {
                formatted = airlinePrefix + formatted
            }
        }

        // Apply leading zero preference to the numeric part
        if formatted.hasPrefix(airlinePrefix) {
            let numericPart = String(formatted.dropFirst(airlinePrefix.count))
            let adjusted = includeLeadingZeroInFlightNumber
                ? padFlightNumberToFourDigits(numericPart)
                : stripFlightNumberLeadingZeros(numericPart)
            formatted = airlinePrefix + adjusted
        } else {
            formatted = includeLeadingZeroInFlightNumber
                ? padFlightNumberToFourDigits(formatted)
                : stripFlightNumberLeadingZeros(formatted)
        }

        return formatted
    }

    /// Pad the numeric prefix of a flight number to 4 digits, preserving any trailing letter suffix.
    /// e.g. "427" → "0427", "1" → "0001", "0427" → "0427".
    private func padFlightNumberToFourDigits(_ number: String) -> String {
        let numericPrefix = number.prefix(while: { $0.isNumber })
        let suffix = String(number.dropFirst(numericPrefix.count))
        guard !numericPrefix.isEmpty else { return number }
        let stripped = String(numericPrefix.drop(while: { $0 == "0" }))
        let core = stripped.isEmpty ? "0" : stripped
        let padded = String(repeating: "0", count: max(0, 4 - core.count)) + core
        return padded + suffix
    }

    /// Strip all leading zeros from the numeric prefix of a flight number, preserving any trailing letter suffix.
    /// e.g. "0427" → "427", "0001" → "1".
    private func stripFlightNumberLeadingZeros(_ number: String) -> String {
        let numericPrefix = number.prefix(while: { $0.isNumber })
        let suffix = String(number.dropFirst(numericPrefix.count))
        guard !numericPrefix.isEmpty else { return number }
        let stripped = numericPrefix.drop(while: { $0 == "0" })
        let result = stripped.isEmpty ? String(numericPrefix.last!) : String(stripped)
        return result + suffix
    }
    
    // MARK: - Crew Name Management (unchanged)

    func addCaptainName(_ name: String) {
        savedCrewNames = userDefaultsService.addCaptainName(name)
    }

    func addCoPilotName(_ name: String) {
        savedCrewNames = userDefaultsService.addCoPilotName(name)
    }

    func removeCaptainName(_ name: String) {
        savedCrewNames = userDefaultsService.removeCaptainName(name)
    }

    func removeCoPilotName(_ name: String) {
        savedCrewNames = userDefaultsService.removeCoPilotName(name)
    }

    func removeSOName(_ name: String) {
        savedCrewNames = userDefaultsService.removeSOName(name)
    }

    func reloadSavedCrewNames() {
        let settings = userDefaultsService.loadSettings()
        let databaseService = FlightDatabaseService.shared

        // Merge unified saved crew names with all database crew names
        let userCrewNames = Set(settings.savedCrewNames)
        let dbCaptainNames = Set(databaseService.getAllCaptainNames())
        let dbFONames = Set(databaseService.getAllFONames())
        let dbSONames = Set(databaseService.getAllSONames())
        let allDBNames = dbCaptainNames.union(dbFONames).union(dbSONames)
        savedCrewNames = Array(userCrewNames.union(allDBNames)).sorted()
    }
    
    // MARK: - Add to internal Logbook

    /// True when the flight date is today or later (not yet due to be flown).
    /// Also true for past-dated flights that have no time data at all — they were
    /// never flown and should be treated the same way for validation purposes.
    private var isUnflownFlight: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = enterTimesInLocalTime ? flightDate : flightDateForStorage
        guard let date = formatter.date(from: dateString.isEmpty ? flightDate : dateString) else { return false }
        let todayUTC = Calendar.current.startOfDay(for: Date())
        let flightDay = Calendar.current.startOfDay(for: date)
        if flightDay >= todayUTC { return true }
        // Past date — unflown if no OUT/IN or any time value recorded
        let hasNoTimes = outTime.isEmpty && inTime.isEmpty
            && (Double(blockTime) ?? 0) == 0
            && (Double(spInsTime) ?? 0) == 0
        return hasNoTimes
    }

    func saveToLogbook() {
        let isSimInstruction = isSpIns && !isInstructingInAircraft
        if isUnflownFlight {
            // Future or unflown flight — no time data required, save whatever is filled in
        } else if isSimInstruction {
            guard !spInsTime.isEmpty else {
                statusMessage = "Sp/Ins time is required for simulator instruction"
                statusColor = .red
                return
            }
        } else if isSimulator {
            guard !blockTime.isEmpty else { return }
        } else if !isPositioning && !(isSpIns && isInstructingInAircraft) {
            guard !outTime.isEmpty && !inTime.isEmpty else { return }
            let computed = calculateFlightTime()
            guard !computed.isEmpty, (Double(computed) ?? 0) > 0 else {
                statusMessage = "Block time cannot be zero"
                statusColor = .red
                return
            }
        }

        HapticManager.shared.impact(.medium) // Haptic for save action

        // For simulator flights without OUT/IN times, use the blockTime field directly
        let blockTimeCalculated = (isSimulator && (outTime.isEmpty || inTime.isEmpty)) ? blockTime : calculateFlightTime()
        if nightTime.isEmpty { updateNightTime() }

        // Calculate time credits based on selected time credit type
        let p1TimeValue: String
        let p1usTimeValue: String
        let p2TimeValue: String

        // Positioning and simulator flights don't log any time credits
        if isPositioning || isSimulator {
            p1TimeValue = "0.0"
            p1usTimeValue = "0.0"
            p2TimeValue = "0.0"
        } else {
            // Use the explicit selectedTimeCredit instead of flightTimePosition
            switch selectedTimeCredit {
            case .p1:
                p1TimeValue = blockTimeCalculated
                p1usTimeValue = "0.0"
                p2TimeValue = "0.0"
            case .p1us:
                p1TimeValue = "0.0"
                p1usTimeValue = blockTimeCalculated
                p2TimeValue = "0.0"
            case .p2:
                p1TimeValue = "0.0"
                p1usTimeValue = "0.0"
                p2TimeValue = blockTimeCalculated
            }
        }

        let instrumentTimeValue = (isPilotFlying && !isSimulator) ? String(format: "%.1f", Double(pfAutoInstrumentMinutes) / 60.0) : "0.0"
        let nightTimeValue = isSimulator ? "0.0" : nightTime
        let simTimeValue: String
        if isSimulator {
            simTimeValue = blockTimeCalculated
        } else if isSimInstruction {
            let ins = Double(spInsTime) ?? 0
            let sim = min(Double(simInsTime) ?? 0, ins)
            simTimeValue = String(format: "%.2f", sim)
        } else {
            simTimeValue = "0.0"
        }
        let spInsTimeValue = isSpIns && isInstructingInAircraft ? blockTimeCalculated : spInsTime
                    LogManager.shared.debug("DEBUG: saveToLogbook PF=\(isPilotFlying), isSimulator=\(isSimulator), simTime=\(simTimeValue), block=\(isSimulator ? "0.0" : blockTimeCalculated), p1=\(p1TimeValue)")

        // Create database service instance or inject it
        let databaseService = FlightDatabaseService.shared  // Use singleton

        let newFlight = FlightSector(
            date: flightDateForStorage,
            flightNumber: formattedFlightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType, //"B738", // Default - you might want to make this configurable
            fromAirport: AirportService.shared.convertToICAO(fromAirport),
            toAirport: AirportService.shared.convertToICAO(toAirport),
            captainName: captainName,
            foName: coPilotName,
            so1Name: so1Name.isEmpty ? nil : so1Name,  // Add SO1
            so2Name: so2Name.isEmpty ? nil : so2Name,  // Add SO2
            blockTime: (isSimulator || isSimInstruction) ? "0.0" : blockTimeCalculated,
            nightTime: nightTimeValue,
            p1Time: p1TimeValue,
            p1usTime: p1usTimeValue,
            p2Time: p2TimeValue,
            instrumentTime: instrumentTimeValue,
            simTime: simTimeValue,
            spInsTime: spInsTimeValue,
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
            scheduledArrival: scheduledArrival,
            counterEntries: isPositioning ? [:] : currentCounterEntries()
        )
                    LogManager.shared.debug("DEBUG: New FlightSector instrumentTime=\(newFlight.instrumentTime), PF=\(newFlight.isPilotFlying), date=\(newFlight.date), flt=\(newFlight.flightNumber), p2Time=\(newFlight.p2Time)")

        if databaseService.saveFlight(newFlight, actionDescription: nil) {
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

        // Determine flight mode
        let simTimeValue = Double(sector.simTime) ?? 0.0
        let isAircraftIns = sector.isAircraftInstruction
        isSpIns = sector.isSpInsOnly || isAircraftIns
        isInstructingInAircraft = isAircraftIns
        isSimulator = simTimeValue > 0.0 && !isSpIns

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

        // Infer time credit type from actual time values
        let p1TimeValue = Double(sector.p1Time) ?? 0.0
        let p2TimeValue = Double(sector.p2Time) ?? 0.0

        if p1TimeValue > 0 {
            selectedTimeCredit = .p1
        } else if p1usTimeValue > 0 {
            selectedTimeCredit = .p1us
        } else if p2TimeValue > 0 {
            selectedTimeCredit = .p2
        } else {
            // No time logged yet - default based on position
            switch flightTimePosition {
            case .captain:
                selectedTimeCredit = .p1
            case .firstOfficer:
                selectedTimeCredit = .p2
            case .secondOfficer:
                selectedTimeCredit = .p2
            }
        }
        isTimeCreditManualOverride = false

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

        // Load Sp/Ins time
        spInsTime = sector.spInsTime
        if isSpIns && !isInstructingInAircraft {
            // Restore the stored simTime as simInsTime; mark manual if it differs from INS time
            simInsTime = sector.simTime
            simInsTimeIsManual = abs(sector.simTimeValue - sector.spInsTimeValue) > 0.01
        } else {
            simInsTime = ""
            simInsTimeIsManual = false
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

        // Convert stored UTC date to local departure date once when in local entry mode.
        // This avoids a cascade bug where converting at the SwiftUI Binding layer would
        // re-convert on every render cycle (UTC→local→UTC→local...).
        if enterTimesInLocalTime, !fromAirport.isEmpty {
            let icao = AirportService.shared.convertToICAO(fromAirport)
            let timeRef: String
            if outTime.count == 5, outTime.contains(":") {
                timeRef = outTime
            } else if !scheduledDeparture.isEmpty {
                timeRef = scheduledDeparture
            } else {
                timeRef = "11:00"
            }
            flightDate = AirportService.shared.convertToLocalDate(
                utcDateString: flightDate,
                utcTimeString: timeRef,
                airportICAO: icao
            )
        }

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

        // Load custom counter entries
        loadCounterEntries(from: sector)

//        print("DEBUG: Loaded flight for editing: \(sector.flightNumber)")
    }

    func updateExistingFlight() -> Bool {
        guard let sectorID = editingSectorID else { return false }

        let isSimInstruction = isSpIns && !isInstructingInAircraft
        if isUnflownFlight {
            // Future or unflown flight — no time data required, save whatever is filled in
        } else if isSimInstruction {
            guard !spInsTime.isEmpty else {
                statusMessage = "Sp/Ins time is required for simulator instruction"
                statusColor = .red
                return false
            }
        } else if !isSimulator && !isPositioning && !(isSpIns && isInstructingInAircraft) {
            guard !blockTime.isEmpty, (Double(blockTime) ?? 0) > 0 else {
                statusMessage = "Block time cannot be zero"
                statusColor = .red
                return false
            }
        }

        HapticManager.shared.impact(.medium)

        // Calculate time credits based on selected time credit type
        let p1TimeValue: String
        let p1usTimeValue: String
        let p2TimeValue: String

        // Positioning, simulator, and sim-instruction flights don't log any time credits
        if isPositioning || isSimulator || isSimInstruction {
            p1TimeValue = "0.0"
            p1usTimeValue = "0.0"
            p2TimeValue = "0.0"
        } else {
            // Use the explicit selectedTimeCredit instead of flightTimePosition
            switch selectedTimeCredit {
            case .p1:
                p1TimeValue = blockTime
                p1usTimeValue = "0.0"
                p2TimeValue = "0.0"
            case .p1us:
                p1TimeValue = "0.0"
                p1usTimeValue = blockTime
                p2TimeValue = "0.0"
            case .p2:
                p1TimeValue = "0.0"
                p1usTimeValue = "0.0"
                p2TimeValue = blockTime
            }
        }

        let instrumentTimeValue = (isPilotFlying && !isSimulator) ? String(format: "%.1f", Double(pfAutoInstrumentMinutes) / 60.0) : "0.0"
        let nightTimeValue = isSimulator ? "0.0" : nightTime
        let simTimeValue: String
        if isSimulator {
            simTimeValue = blockTime
        } else if isSimInstruction {
            let ins = Double(spInsTime) ?? 0
            let sim = min(Double(simInsTime) ?? 0, ins)
            simTimeValue = String(format: "%.2f", sim)
        } else {
            simTimeValue = "0.0"
        }
        // For aircraft instruction: store blockTime in spInsTime so it can be identified and badged
        let spInsTimeValue = isSpIns && isInstructingInAircraft ? blockTime : spInsTime

//        print("DEBUG: Saving flight with approach - AIII: \(isAIII), RNP: \(isRNP), ILS: \(isILS), GLS: \(isGLS), NPA: \(isNPA)")

        let updatedFlight = FlightSector(
            id: sectorID,
            date: flightDateForStorage,
            flightNumber: formattedFlightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            fromAirport: AirportService.shared.convertToICAO(fromAirport),
            toAirport: AirportService.shared.convertToICAO(toAirport),
            captainName: captainName,
            foName: coPilotName,
            so1Name: so1Name.isEmpty ? nil : so1Name,
            so2Name: so2Name.isEmpty ? nil : so2Name,
            blockTime: (isSimulator || isSimInstruction) ? "0.0" : blockTime,
            nightTime: nightTimeValue,
            p1Time: p1TimeValue,
            p1usTime: p1usTimeValue,
            p2Time: p2TimeValue,
            instrumentTime: instrumentTimeValue,
            simTime: simTimeValue,
            spInsTime: spInsTimeValue,
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
            scheduledArrival: scheduledArrival,
            counterEntries: isPositioning ? [:] : currentCounterEntries()
        )

        let databaseService = FlightDatabaseService.shared
        let success = databaseService.updateFlight(updatedFlight, actionDescription: nil)

        if success {
            statusMessage = "Flight updated successfully!"
            statusColor = .green
            HapticManager.shared.notification(.success)

            // Sync VM fields to what was actually persisted so hasUnsavedChanges
            // matches on the next render. For aircraft instruction the persisted
            // spInsTime mirrors blockTime; the VM's own spInsTime field is unused
            // in that mode and left stale, which would otherwise re-trigger the
            // change-detection alert in iPad split view.
            if isSpIns && isInstructingInAircraft {
                spInsTime = blockTime
            }

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

    private func originalTimeCreditType(_ sector: FlightSector) -> TimeCreditType {
        if (Double(sector.p1usTime) ?? 0) > 0 { return .p1us }
        if (Double(sector.p2Time) ?? 0) > 0 { return .p2 }
        if (Double(sector.p1Time) ?? 0) > 0 { return .p1 }
        // No time logged (e.g. PAX/future flights) — use the same position-based default
        // as loadFlightForEditing so selectedTimeCredit and originalTimeCreditType agree.
        switch flightTimePosition {
        case .captain: return .p1
        case .firstOfficer, .secondOfficer: return .p2
        }
    }

    // MARK: - Custom Counter Helpers

    /// Populate counterValues from a sector's counterEntries dict (loaded from Core Data).
    func loadCounterEntries(from sector: FlightSector) {
        counterValues = sector.counterEntries
    }

    /// Return counterValues as a [columnIndex: rawValue] dict, skipping empty / zero entries.
    func currentCounterEntries() -> [Int: String] {
        var result: [Int: String] = [:]
        for (columnIndex, value) in counterValues {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  trimmed != "0",
                  trimmed != "0.0",
                  trimmed != "00:00",
                  trimmed != "0:00" else { continue }
            result[columnIndex] = trimmed
        }
        return result
    }

    var hasUnsavedChanges: Bool {
        guard let original = originalFlightData else { return false }

        // Helper to compare time values numerically (ignoring precision differences like "4.5" vs "4.50").
        // Empty string is treated as zero so "" == "0.0" == "0.00" (FlightSector normalises empty → "0.00").
        func timeValuesEqual(_ a: String, _ b: String) -> Bool {
            let aVal = Double(a) ?? 0.0
            let bVal = Double(b) ?? 0.0
            return abs(aVal - bVal) < 0.01
        }

        let originalWasSimulator = (Double(original.simTime) ?? 0.0) > 0.0 && !original.isSpInsOnly

        return flightDateForStorage != original.date ||
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
               selectedTimeCredit != originalTimeCreditType(original) ||
               isSimulator != originalWasSimulator ||
               isPositioning != original.isPositioning ||
               // isSpIns/isInstructingInAircraft have no persisted representation on
               // unflown flights (spInsTime is nil/0), so exclude them from change detection
               // to avoid false "unsaved changes" prompts when toggling FLT↔INS.
               (!isUnflownFlight && isSpIns != (original.isSpInsOnly || original.isAircraftInstruction)) ||
               (!isUnflownFlight && isInstructingInAircraft != original.isAircraftInstruction) ||
               remarks != original.remarks ||
               dayTakeoffs != original.dayTakeoffs ||
               dayLandings != original.dayLandings ||
               nightTakeoffs != original.nightTakeoffs ||
               nightLandings != original.nightLandings ||
               outTime != original.outTime ||
               inTime != original.inTime ||
               scheduledDeparture != original.scheduledDeparture ||
               scheduledArrival != original.scheduledArrival ||
               !timeValuesEqual(spInsTime, original.spInsTime) ||
               (isSpIns && !isInstructingInAircraft && !timeValuesEqual(simInsTime, original.simTime)) ||
               currentCounterEntries() != original.counterEntries
    }

    var changesSummary: String {
        guard let original = originalFlightData else { return "" }

        var changes: [String] = []

        if flightDateForStorage != original.date {
            changes.append("Date: \(original.date) → \(flightDateForStorage)")
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

        if (Double(spInsTime) ?? 0.0) != (Double(original.spInsTime) ?? 0.0) {
            changes.append("INS: \(original.spInsTime) → \(spInsTime)")
        }

        if isSpIns && !isInstructingInAircraft,
           (Double(simInsTime) ?? 0.0) != (Double(original.simTime) ?? 0.0) {
            changes.append("SIM (INS): \(original.simTime) → \(simInsTime)")
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

        let originalWasSimulator = (Double(original.simTime) ?? 0.0) > 0.0 && !original.isSpInsOnly
        let originalWasSpIns = original.isSpInsOnly
        if isSimulator != originalWasSimulator || isSpIns != originalWasSpIns {
            let originalType = originalWasSpIns ? "INS" : (originalWasSimulator ? "SIM" : "FLT")
            let currentType = isSpIns ? "INS" : (isSimulator ? "SIM" : "FLT")
            changes.append("Type: \(originalType) → \(currentType)")
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

        let newEntries = currentCounterEntries()
        let allKeys = Set(newEntries.keys).union(original.counterEntries.keys)
        for columnIndex in allKeys {
            let oldVal = original.counterEntries[columnIndex] ?? ""
            let newVal = newEntries[columnIndex] ?? ""
            if oldVal != newVal {
                let label = CustomCounterService.shared.definition(for: columnIndex)?.label ?? "Field"
                changes.append("\(label): \(oldVal.isEmpty ? "—" : oldVal) → \(newVal.isEmpty ? "—" : newVal)")
            }
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
        let success = databaseService.deleteFlight(tempSector, actionDescription: nil)

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
        // For simulator flights, don't calculate night time - let user enter it manually
        if isSimulator {
            return
        }

        let capturedEditingMode = isEditingMode

        // Cancel any queued calculation — only the latest values matter.
        // This prevents stacking multiple expensive calculations when fields
        // change rapidly (e.g. pasting times or rapid keystrokes).
        nightTimeCalculationTask?.cancel()
        // Capture all @MainActor state before leaving the actor.
        let fromAirport = self.fromAirport
        let toAirport = self.toAirport
        let outTime = self.outTime
        let blockTime = self.blockTime
        let flightDate = self.flightDate
        let manager = self.timeCalculationManager

        nightTimeCalculationTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self, !Task.isCancelled else { return }

            // Build context and run the 200-segment solar trig loop off the main thread.
            if let context = manager.buildCalculationContext(
                fromAirport: fromAirport,
                toAirport: toAirport,
                outTime: outTime,
                blockTime: blockTime,
                flightDate: flightDate
            ) {
                guard !Task.isCancelled else { return }
                let result = manager.calculateNightTime(using: context)
                await MainActor.run {
                    self.nightTime = result
                    self.updateTakeoffsLandings(using: context)
                }
            } else {
                await MainActor.run {
                    if capturedEditingMode && outTime.isEmpty {
                        // Preserve existing night time in edit mode when OUT is missing
                    } else {
                        self.nightTime = ""
                    }
                    self.updateTakeoffsLandings(using: nil)
                }
            }
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

        // Set time credit based on position
        switch flightTimePosition {
        case .captain:
            selectedTimeCredit = .p1
        case .firstOfficer:
            selectedTimeCredit = .p2  // Default to P2, can be changed to P1US if ICUS
        case .secondOfficer:
            selectedTimeCredit = .p2
        }
        isTimeCreditManualOverride = false

        // Clear approach types when PF is off
        selectedApproachType = nil
        isAIII = false
        isRNP = false
        isILS = false
        isGLS = false
        isNPA = false

        isICUS = false
        isSimulator = false
        isSpIns = false
        isInstructingInAircraft = showSpInsSelector ? (defaultInstructionEnvironment == .aircraft) : false
        spInsTime = ""
        simInsTime = ""
        simInsTimeIsManual = false
        isPositioning = false
        remarks = ""
        counterValues = [:]
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
        let currentDay = calendar.component(.day, from: now)
        var targetMonth = calendar.component(.month, from: now)
        var targetYear = calendar.component(.year, from: now)

        // Simple month crossing logic:
        // If extracted day > current day, it must be from last month
        // (device time is always ahead of flight start time)
        if day > currentDay {
            targetMonth -= 1
            if targetMonth < 1 {
                targetMonth = 12
                targetYear -= 1
            }
            LogManager.shared.debug("Day \(day) > current day \(currentDay)  using previous month (\(targetMonth)/\(targetYear))")
        } else {
            LogManager.shared.debug("Day \(day) <= current day \(currentDay)  using current month (\(targetMonth)/\(targetYear))")
        }

        // Create the date
        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = targetMonth
        dateComponents.year = targetYear
        dateComponents.timeZone = TimeZone(abbreviation: "UTC")

        if let newDate = calendar.date(from: dateComponents) {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            let newDateString = formatter.string(from: newDate)

            LogManager.shared.info("Updated flight date from '\(self.flightDate)' to '\(newDateString)' (day \(day))")
            self.flightDate = newDateString
        } else {
            LogManager.shared.error("Failed to create date for day \(day), month \(targetMonth), year \(targetYear)")
        }
    }
    
    private func showError(_ message: String) {
        HapticManager.shared.notification(.error) // Error haptic
        errorMessage = message
        showingError = true
        statusMessage = "Error: \(message)"
        statusColor = .red
    }

    private func showCaptureError(_ message: String) {
        HapticManager.shared.notification(.error)
        captureErrorMessage = message
        showingCaptureError = true
        statusMessage = "Capture incomplete"
        statusColor = .orange
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
        if isSpIns && !isInstructingInAircraft {
            // For SIM instruction, populate spInsTime from OUT/IN (no block time credit)
            spInsTime = times.blockTime
        } else {
            blockTime = times.blockTime
            nightTime = times.nightTime
        }
    }
  
    func addToInternalLogbook() {
        // For simulator flights, allow missing OUT/IN times if block time is present
        if isSimulator {
            guard !blockTime.isEmpty else {
                showError("Block time is required for simulator flights")
                return
            }
        } else if isSpIns && !isInstructingInAircraft {
            guard !spInsTime.isEmpty else {
                showError("Instructor time is required")
                return
            }
        } else {
            let hasActualTimes = !outTime.isEmpty && !inTime.isEmpty
            let hasScheduledTimes = !scheduledDeparture.isEmpty && !scheduledArrival.isEmpty
            let hasManualBlockTime = !blockTime.isEmpty && blockTime != "0.0"
            guard hasActualTimes || hasScheduledTimes || hasManualBlockTime else {
                showError("Enter OUT/IN times or a manual block time")
                return
            }
        }

        guard !flightDate.isEmpty else {
            showError("Please set flight date")
            return
        }

        statusMessage = "Saving to logbook..."
        statusColor = .blue

        // Calculate block time: use OUT/IN if available, otherwise fall back to manual blockTime field (future/sim flights)
        let blockTimeCalculated = (!outTime.isEmpty && !inTime.isEmpty) ? calculateFlightTime() : (blockTime.isEmpty ? "0.0" : blockTime)
        if nightTime.isEmpty { updateNightTime() }

        // Calculate time credits based on selected time credit type
        let p1TimeValue: String
        let p1usTimeValue: String
        let p2TimeValue: String

        // Positioning, simulator, and sim-instruction flights don't log any time credits
        let isSimInstruction = isSpIns && !isInstructingInAircraft
        if isPositioning || isSimulator || isSimInstruction {
            p1TimeValue = "0.0"
            p1usTimeValue = "0.0"
            p2TimeValue = "0.0"
        } else {
            // Use the explicit selectedTimeCredit instead of flightTimePosition
            switch selectedTimeCredit {
            case .p1:
                p1TimeValue = blockTimeCalculated
                p1usTimeValue = "0.0"
                p2TimeValue = "0.0"
            case .p1us:
                p1TimeValue = "0.0"
                p1usTimeValue = blockTimeCalculated
                p2TimeValue = "0.0"
            case .p2:
                p1TimeValue = "0.0"
                p1usTimeValue = "0.0"
                p2TimeValue = blockTimeCalculated
            }
        }

        let instrumentTimeValue = (isPilotFlying && !isSimulator) ? String(format: "%.1f", Double(pfAutoInstrumentMinutes) / 60.0) : "0.0"
        let nightTimeValue = isSimulator ? "0.0" : nightTime
        let simTimeValue: String
        if isSimulator {
            simTimeValue = blockTimeCalculated
        } else if isSimInstruction {
            let ins = Double(spInsTime) ?? 0
            let sim = min(Double(simInsTime) ?? 0, ins)
            simTimeValue = String(format: "%.2f", sim)
        } else {
            simTimeValue = "0.0"
        }
        // For aircraft instruction: store blockTime in spInsTime so it can be identified and badged
        let spInsTimeValue = isSpIns && isInstructingInAircraft ? blockTimeCalculated : spInsTime
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
                        LogManager.shared.debug(" Found scheduled flight to update")

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
                blockTime: (isSimulator || isSimInstruction) ? "0.0" : blockTimeCalculated,
                nightTime: nightTimeValue,
                p1Time: p1TimeValue,
                p1usTime: p1usTimeValue,
                p2Time: p2TimeValue,
                instrumentTime: instrumentTimeValue,
                simTime: simTimeValue,
                spInsTime: spInsTimeValue,
                isPilotFlying: isPilotFlying,
                isPositioning: isPositioning,
                isAIII: (isPilotFlying || isSimulator) && isAIII,
                isRNP: (isPilotFlying || isSimulator) && isRNP,
                isILS: (isPilotFlying || isSimulator) && isILS,
                isGLS: (isPilotFlying || isSimulator) && isGLS,
                isNPA: (isPilotFlying || isSimulator) && isNPA,
                remarks: remarks,
                dayTakeoffs: dayTakeoffs,
                dayLandings: dayLandings,
                nightTakeoffs: nightTakeoffs,
                nightLandings: nightLandings,
                outTime: outTime,
                inTime: inTime,
                scheduledDeparture: scheduledDeparture,
                scheduledArrival: scheduledArrival,
                counterEntries: isPositioning ? [:] : currentCounterEntries()
            )

            if databaseService.updateScheduledFlightWithActualData(scheduledFlight, actualData: actualFlightData, actionDescription: nil) {
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
                        LogManager.shared.debug(" No scheduled flight found - creating new flight")

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
                blockTime: (isSimulator || isSimInstruction) ? "0.0" : blockTimeCalculated,
                nightTime: nightTimeValue,
                p1Time: p1TimeValue,
                p1usTime: p1usTimeValue,
                p2Time: p2TimeValue,
                instrumentTime: instrumentTimeValue,
                simTime: simTimeValue,
                spInsTime: spInsTimeValue,
                isPilotFlying: isPilotFlying,
                isPositioning: isPositioning,
                isAIII: (isPilotFlying || isSimulator) && isAIII,
                isRNP: (isPilotFlying || isSimulator) && isRNP,
                isILS: (isPilotFlying || isSimulator) && isILS,
                isGLS: (isPilotFlying || isSimulator) && isGLS,
                isNPA: (isPilotFlying || isSimulator) && isNPA,
                remarks: remarks,
                dayTakeoffs: dayTakeoffs,
                dayLandings: dayLandings,
                nightTakeoffs: nightTakeoffs,
                nightLandings: nightLandings,
                outTime: outTime,
                inTime: inTime,
                scheduledDeparture: scheduledDeparture,
                scheduledArrival: scheduledArrival,
                counterEntries: isPositioning ? [:] : currentCounterEntries()
            )
                        LogManager.shared.debug("DEBUG: New FlightSector instrumentTime=\(newFlight.instrumentTime), PF=\(newFlight.isPilotFlying), date=\(newFlight.date), flt=\(newFlight.flightNumber), isSimulator=\(isSimulator), simTime=\(newFlight.simTime), blockTime=\(newFlight.blockTime), p2Time=\(newFlight.p2Time)")

            if databaseService.saveFlight(newFlight, actionDescription: nil) {
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
                    LogManager.shared.debug(" DEBUG: Toggle called with value: \(newValue)")
                    LogManager.shared.debug(" DEBUG: Current savePhotosToLibrary: \(savePhotosToLibrary)")
                    LogManager.shared.debug(" DEBUG: Has photo permission: \(hasPhotoPermission())")
                    LogManager.shared.debug(" DEBUG: Photo permission status: \(getPhotoPermissionStatus())")

        // Force update the setting regardless of permission (for testing)
        savePhotosToLibrary = newValue
        userDefaultsService.setSavePhotosToLibrary(newValue)

                    LogManager.shared.debug(" DEBUG: After update - savePhotosToLibrary: \(savePhotosToLibrary)")
    }

    // MARK: - Flight Data Lookup (FlightAware + AeroDataBox)

    /// Kick off concurrent fetch from FlightAware and AeroDataBox, then merge results.
    func fetchFlightAwareData() {
        guard !flightNumber.isEmpty else {
            showError("Please enter a flight number first")
            return
        }
        guard !flightDate.isEmpty else {
            showError("Please select a flight date first")
            return
        }

        // FlightAware needs ICAO airline code (e.g. QFA933)
        guard let flightAwareCode = flightNumber.toFlightAwareFormat(
            userAirlinePrefix: includeAirlinePrefixInFlightNumber ? nil : airlinePrefix
        ) else {
            showError("Invalid flight number format")
            return
        }

        // AeroDataBox uses IATA airline code (e.g. QF933)
        let iataFlightNumber = includeAirlinePrefixInFlightNumber
            ? flightNumber
            : airlinePrefix + flightNumber

        isFetchingFlightAware = true
        statusMessage = "Searching flight databases..."
        statusColor = .blue
        HapticManager.shared.impact(.medium)

        // FlightAware always expects a UTC date. When enterTimesInLocalTime is on,
        // flightDate holds the local date — flightDateForStorage converts it back to UTC.
        let utcDateForSearch = flightDateForStorage
        LogManager.shared.info(" Flight lookup: FA=\(flightAwareCode), ADB=\(iataFlightNumber), utcDate=\(utcDateForSearch) (flightDate=\(flightDate))")

        Task {
            // Step 1: Fetch FlightAware first — its result gives us the departure ICAO
            // and UTC departure time needed to compute the correct AeroDataBox local date.
            let faResults = await fetchFromFlightAware(code: flightAwareCode, date: utcDateForSearch)

            // Step 2: Derive the local departure date for AeroDataBox.
            // AeroDataBox uses dateLocalRole=Departure, so it expects the LOCAL date at the
            // departure airport — which can differ from the UTC date by ±1 day.
            let adbLocalDate: String
            if let firstFA = faResults.first {
                let localDate = AirportService.shared.convertToLocalDate(
                    utcDateString: firstFA.flightDate,
                    utcTimeString: firstFA.departureTime,
                    airportICAO: firstFA.origin
                )
                adbLocalDate = localDate
                LogManager.shared.info(" ADB local date: \(localDate) (derived from \(firstFA.origin) UTC \(firstFA.flightDate) \(firstFA.departureTime))")
            } else {
                // No FA result — fall back to flightDate.
                // In local mode flightDate IS the local date (correct for ADB).
                // In UTC mode it's the UTC date (approximate, but UTC mode always finds FA results).
                adbLocalDate = flightDate
                LogManager.shared.info(" ADB local date: \(flightDate) (fallback  no FA result to derive from)")
            }

            // Step 3: Fetch AeroDataBox with the precise local departure date
            let adbResults = await fetchFromAeroDataBox(flightNumber: iataFlightNumber, localDate: adbLocalDate)

            let merged = mergeFlightResults(flightAware: faResults, aeroDataBox: adbResults)

            await MainActor.run {
                self.isFetchingFlightAware = false

                if merged.isEmpty {
                    self.showError("No flights found for this date")
                    HapticManager.shared.notification(.error)
                } else if merged.count == 1 {
                    self.populateFieldsWithFlightData(merged[0])
                    self.statusMessage = "Flight data retrieved successfully!"
                    self.statusColor = .green
                    HapticManager.shared.notification(.success)
                } else {
                    self.flightSegments = merged
                    self.showingSegmentSelection = true
                    self.statusMessage = "Multiple segments found - select one"
                    self.statusColor = .orange
                    HapticManager.shared.impact(.light)
                }
            }
        }
    }

    // MARK: - Private fetch helpers

    private func fetchFromFlightAware(code: String, date: String) async -> [FlightAwareData] {
        do {
            let results = try await flightAwareService.fetchFlightData(flightNumber: code, date: date)
            LogManager.shared.info(" FlightAware: \(results.count) result(s) for \(code)")
            for (i, r) in results.enumerated() {
                LogManager.shared.info(" FlightAware [\(i)] \(r.origin)\(r.destination): OUT=\(r.departureTime) (actual=\(r.departureIsActual)), IN=\(r.arrivalTime) (actual=\(r.arrivalIsActual)), STD=\(r.scheduledDepartureTime ?? "nil"), STA=\(r.scheduledArrivalTime ?? "nil"), date=\(r.flightDate)")
            }
            return results
        } catch {
            LogManager.shared.warning(" FlightAware: fetch failed  \(error.localizedDescription)")
            return []
        }
    }

    private func fetchFromAeroDataBox(flightNumber: String, localDate: String) async -> [FlightAwareData] {
        let results = await aeroDataBoxService.fetchFlightData(flightNumber: flightNumber, localDepartureDate: localDate)
        LogManager.shared.info(" AeroDataBox: \(results.count) result(s) for \(flightNumber) on local date \(localDate)")
        return results
    }

    /// Merge results from both sources, preferring entries with actual gate times.
    /// Matches legs by ICAO origin+destination pair.
    private func mergeFlightResults(flightAware: [FlightAwareData], aeroDataBox: [FlightAwareData]) -> [FlightAwareData] {
        LogManager.shared.info(" Merge: FlightAware=\(flightAware.count), AeroDataBox=\(aeroDataBox.count)")

        // If one source returned nothing, use the other as-is
        if flightAware.isEmpty && aeroDataBox.isEmpty {
            LogManager.shared.info(" Merge: Both sources empty")
            return []
        }
        if flightAware.isEmpty {
            LogManager.shared.info(" Merge: FlightAware empty  using AeroDataBox results only")
            return aeroDataBox
        }
        if aeroDataBox.isEmpty {
            LogManager.shared.info(" Merge: AeroDataBox empty  using FlightAware results only")
            return flightAware
        }

        // Both returned data — match legs by route
        var merged: [FlightAwareData] = []
        var matchedADBIndices = Set<Int>()

        for faFlight in flightAware {
            if let adbIdx = aeroDataBox.firstIndex(where: {
                $0.origin == faFlight.origin && $0.destination == faFlight.destination
            }) {
                let adbFlight = aeroDataBox[adbIdx]
                matchedADBIndices.insert(adbIdx)

                LogManager.shared.info(" \(faFlight.origin)\(faFlight.destination): hybrid field merge")
                LogManager.shared.info("   FA : OUT=\(faFlight.departureTime) (actual=\(faFlight.departureIsActual)), IN=\(faFlight.arrivalTime) (actual=\(faFlight.arrivalIsActual))")
                LogManager.shared.info("   ADB: OUT=\(adbFlight.departureTime) (actual=\(adbFlight.departureIsActual)), IN=\(adbFlight.arrivalTime) (actual=\(adbFlight.arrivalIsActual)), T/O=\(adbFlight.departureRunwayTime ?? "nil"), LDG=\(adbFlight.arrivalRunwayTime ?? "nil")")
                LogManager.shared.info("   ADB registration: \(adbFlight.aircraftRegistration ?? "nil")")

                merged.append(hybridMerge(flightAware: faFlight, aeroDataBox: adbFlight))
            } else {
                // No ADB leg matched this FA leg
                LogManager.shared.info(" \(faFlight.origin)\(faFlight.destination): FlightAware only (no AeroDataBox match)")
                merged.append(faFlight)
            }
        }

        // Append any ADB legs not matched by a FA leg (e.g. extra segments FA missed)
        for (idx, adbFlight) in aeroDataBox.enumerated() where !matchedADBIndices.contains(idx) {
            LogManager.shared.info(" \(adbFlight.origin)\(adbFlight.destination): AeroDataBox only (no FlightAware match)")
            merged.append(adbFlight)
        }

        LogManager.shared.info(" Merge complete: \(merged.count) leg(s) total")
        return merged
    }

    /// Field-level hybrid merge for a matched FA+ADB pair.
    ///
    /// Rules:
    /// - OUT time: prefer the source with an actual (FA first, then ADB). If both actual, use FlightAware.
    /// - IN  time: when AeroDataBox has an actual revisedTime, use whichever IN time is **later**
    ///             (the later gate-arrival time is more conservative and closer to true block-in).
    /// - Aircraft registration: always taken from AeroDataBox (FA doesn't provide it).
    /// - All other fields (route, date, STD/STA, runway times): taken from FA as the base.
    private func hybridMerge(flightAware fa: FlightAwareData, aeroDataBox adb: FlightAwareData) -> FlightAwareData {
        var result = fa  // start with FlightAware as the base

        // ── OUT time ────────────────────────────────────────────────────────
        if !fa.departureIsActual && adb.departureIsActual {
            result.departureTime     = adb.departureTime
            result.departureIsActual = true
            LogManager.shared.info(" OUT: AeroDataBox \(adb.departureTime) used (FA has scheduled only)")
        } else {
            LogManager.shared.info(" OUT: FlightAware \(fa.departureTime) used (actual=\(fa.departureIsActual))")
        }

        // ── IN time ─────────────────────────────────────────────────────────
        // When AeroDataBox has an actual IN, take the later of the two.
        // Use the OUT time as an anchor so midnight crossings are handled correctly:
        // any IN time numerically less than OUT has crossed midnight — add 1440 before comparing.
        if adb.arrivalIsActual {
            let outMinutes = timeStringToMinutes(result.departureTime) ?? 0
            let faMinutes  = timeStringToMinutes(fa.arrivalTime).map  { $0 < outMinutes ? $0 + 1440 : $0 }
            let adbMinutes = timeStringToMinutes(adb.arrivalTime).map { $0 < outMinutes ? $0 + 1440 : $0 }
            if let faMin = faMinutes, let adbMin = adbMinutes {
                if adbMin > faMin {
                    result.arrivalTime     = adb.arrivalTime
                    result.arrivalIsActual = true
                    LogManager.shared.info(" IN : AeroDataBox \(adb.arrivalTime) used (later than FA \(fa.arrivalTime); adjusted mins: ADB=\(adbMin) FA=\(faMin))")
                } else {
                    LogManager.shared.info(" IN : FlightAware \(fa.arrivalTime) used (later than or equal to ADB \(adb.arrivalTime); adjusted mins: FA=\(faMin) ADB=\(adbMin))")
                }
            }
        } else {
            LogManager.shared.info(" IN : FlightAware \(fa.arrivalTime) used (AeroDataBox has no actual IN)")
        }

        // ── Scheduled times (STD/STA) ────────────────────────────────────────
        // ADB is the authoritative source for scheduled times; FA rarely has them.
        result.scheduledDepartureTime = adb.scheduledDepartureTime ?? fa.scheduledDepartureTime
        result.scheduledArrivalTime   = adb.scheduledArrivalTime   ?? fa.scheduledArrivalTime

        // ── Clear OUT/IN for future flights ──────────────────────────────────
        // If the departure is not actual, the flight hasn't happened — clear OUT/IN
        // so only STD/STA are returned. The app should not populate gate-time fields
        // from predicted/scheduled data.
        if !result.departureIsActual {
            result.departureTime = ""
            LogManager.shared.info(" OUT cleared (flight not yet departed  use STD \(result.scheduledDepartureTime ?? "nil"))")
        }
        if !result.arrivalIsActual {
            result.arrivalTime = ""
            LogManager.shared.info(" IN  cleared (flight not yet arrived  use STA \(result.scheduledArrivalTime ?? "nil"))")
        }

        // ── Aircraft registration ────────────────────────────────────────────
        // AeroDataBox is the only source that provides this.
        if let reg = adb.aircraftRegistration, !reg.isEmpty {
            result.aircraftRegistration = reg
            LogManager.shared.info(" REG: \(reg) from AeroDataBox")
        }

        // ── ADB runway times ─────────────────────────────────────────────────
        result.departureRunwayTime = adb.departureRunwayTime
        result.arrivalRunwayTime   = adb.arrivalRunwayTime

        LogManager.shared.info(" Hybrid result: OUT=\(result.departureTime.isEmpty ? "nil" : result.departureTime) (actual=\(result.departureIsActual)), IN=\(result.arrivalTime.isEmpty ? "nil" : result.arrivalTime) (actual=\(result.arrivalIsActual)), STD=\(result.scheduledDepartureTime ?? "nil"), STA=\(result.scheduledArrivalTime ?? "nil")")
        return result
    }

    /// Convert HH:MM time string to total minutes since midnight for comparison.
    private func timeStringToMinutes(_ time: String) -> Int? {
        let parts = time.components(separatedBy: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else { return nil }
        return hours * 60 + minutes
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

        // Populate aircraft registration if provided (also triggers auto aircraft type lookup).
        // Respect the Long A/C Registration setting: if off, strip the country prefix (e.g. "VH-OQK" → "OQK").
        if let reg = flightData.aircraftRegistration, !reg.isEmpty {
            let formattedReg: String
            if showFullAircraftReg {
                formattedReg = reg
            } else if let dashIndex = reg.firstIndex(of: "-") {
                formattedReg = String(reg[reg.index(after: dashIndex)...])
            } else {
                formattedReg = reg  // No dash (e.g. US N-numbers) — use as-is
            }
            LogManager.shared.info(" Aircraft registration from AeroDataBox: \(reg)  stored as \(formattedReg) (showFullReg=\(showFullAircraftReg))")
            self.updateAircraftReg(formattedReg)
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
                        LogManager.shared.debug(" Skipping draft save - in editing mode")
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
                        LogManager.shared.debug(" Skipping draft save - no data entered")
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
            isSpIns: isSpIns,
            spInsTime: spInsTime,
            simInsTime: simInsTime,
            isPositioning: isPositioning,
            outTime: outTime,
            inTime: inTime,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival,
            isICUS: isICUS,
            selectedTimeCredit: selectedTimeCredit,
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
                        LogManager.shared.debug(" Draft flight data saved successfully")
        } catch {
                        LogManager.shared.debug("Failed to save draft flight data: \(error)")
        }
    }

    /// Restore draft flight data if available and not expired
    func restoreDraftFlightData() {
        guard let data = UserDefaults.standard.data(forKey: Self.draftFlightDataKey) else {
                        LogManager.shared.debug(" No draft flight data found")
            return
        }

        do {
            let decoder = JSONDecoder()
            let draft = try decoder.decode(DraftFlightData.self, from: data)

            // Check if draft is expired
            if draft.isExpired {
                            LogManager.shared.debug(" Draft flight data expired (older than 24 hours) - clearing")
                clearDraftFlightData()
                return
            }

            // Restore all fields from draft
                        LogManager.shared.debug(" Restoring draft flight data from \(draft.timestamp)")
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
            isSpIns = draft.isSpIns
            isInstructingInAircraft = isSpIns ? (defaultInstructionEnvironment == .aircraft) : false
            spInsTime = draft.spInsTime
            simInsTime = draft.simInsTime
            simInsTimeIsManual = !draft.simInsTime.isEmpty && draft.simInsTime != draft.spInsTime
            isPositioning = draft.isPositioning
            outTime = draft.outTime
            inTime = draft.inTime
            scheduledDeparture = draft.scheduledDeparture
            scheduledArrival = draft.scheduledArrival
            isICUS = draft.isICUS
            selectedTimeCredit = draft.selectedTimeCredit
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
