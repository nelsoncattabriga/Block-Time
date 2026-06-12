//
//  PlannedFlightService.swift
//  Block-Time
//
//  Created by Nelson on 18/10/2025.
//

import Foundation
import CoreData


/// Service to import planned flights from rosters into the main flight database
public class PlannedFlightService {

    // MARK: - Properties

    private let databaseService = FlightDatabaseService.shared
    private let userDefaultsService = UserDefaultsService()

    public init() {}

    // MARK: - Import Results

    public struct ImportResult {
        public let imported: Int
        public let duplicates: Int
        public let errors: Int
        public let flights: [ImportedFlight]
        public let staleFlights: [FlightEntity]
    }

    public struct ImportedFlight {
        public let flight: RosterParserService.ParsedFlight
        public let isDuplicate: Bool
        public let error: String?
    }

    // MARK: - Import Methods

    /// Import future flights from a roster file
    public func importRoster(from fileURL: URL) async throws -> ImportResult {
        // Request access to security-scoped resource
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "PlannedFlightService", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Unable to access the file. Please try again."])
        }

        // Ensure we stop accessing the resource when done
        defer {
            fileURL.stopAccessingSecurityScopedResource()
        }

        // Parse the roster file
        let parseResult = try RosterParserService.parseRoster(from: fileURL)

        // Filter to only future flights
        let futureFlights = RosterParserService.futureFights(from: parseResult.flights)

        // Import the flights
        return try await importFlights(futureFlights)
    }

    /// Import a list of parsed flights into the database
    public func importFlights(_ parsedFlights: [RosterParserService.ParsedFlight]) async throws -> ImportResult {
        var imported = 0
        var duplicates = 0
        var errors = 0
        var results: [ImportedFlight] = []

        print("Starting import of \(parsedFlights.count) parsed flights")

        // Enable batch import mode to debounce notifications during import
        databaseService.startBatchImport()
        defer {
            databaseService.endBatchImport()
        }

        for parsedFlight in parsedFlights {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            let dateString = dateFormatter.string(from: parsedFlight.date)

            print("\n  Processing: \(parsedFlight.flightNumber) on \(dateString) (\(parsedFlight.departureAirport)-\(parsedFlight.arrivalAirport))")

            // Check if this flight already exists (query for each flight individually)
            let existingFlights = try await findExistingFlights(for: [parsedFlight])

            if isDuplicate(parsedFlight, in: existingFlights) {
                print("    DUPLICATE - skipping")
                duplicates += 1
                results.append(ImportedFlight(
                    flight: parsedFlight,
                    isDuplicate: true,
                    error: nil
                ))
                continue
            }

            // Import the flight
            do {
                try await createFlight(from: parsedFlight)
                            print("   IMPORTED successfully")
                imported += 1
                results.append(ImportedFlight(
                    flight: parsedFlight,
                    isDuplicate: false,
                    error: nil
                ))
            } catch {
                    print("   ERROR: \(error.localizedDescription)")
                errors += 1
                results.append(ImportedFlight(
                    flight: parsedFlight,
                    isDuplicate: false,
                    error: error.localizedDescription
                ))
            }
        }

                    print("\n Import Summary:")
                    print("   Imported: \(imported)")
                    print("    Duplicates: \(duplicates)")
                    print("   Errors: \(errors)")

        return ImportResult(
            imported: imported,
            duplicates: duplicates,
            errors: errors,
            flights: results,
            staleFlights: []
        )
    }

    // MARK: - Duplicate Detection

    /// Find existing flights that match the parsed flights
    private func findExistingFlights(for parsedFlights: [RosterParserService.ParsedFlight]) async throws -> [FlightEntity] {
        let context = databaseService.viewContext

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                // Access AirportService inside the closure to avoid Sendable warnings
                let airportService = AirportService.shared

                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()

                // Build predicates for each flight (match on date, flight number, departure, and arrival)
                var predicates: [NSPredicate] = []

                for parsedFlight in parsedFlights {
                    // Convert IATA codes to ICAO for comparison with database
                    let departureICAO = airportService.convertToICAO(parsedFlight.departureAirport)
                    let arrivalICAO = airportService.convertToICAO(parsedFlight.arrivalAirport)

                    // Convert local date to UTC for comparison with database
                    // IMPORTANT: parsedFlight.date is created by Calendar.current in device timezone
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day], from: parsedFlight.date)

                    guard let day = components.day, let month = components.month, let year = components.year else {
                        continue
                    }

                    let localDateString = String(format: "%02d/%02d/%04d", day, month, year)
                    // Format time inline to avoid Sendable warnings
                    let localOutTime: String = {
                        let time = parsedFlight.departureTime
                        guard time.count == 4 else { return time }
                        let hours = time.prefix(2)
                        let minutes = time.suffix(2)
                        return "\(hours):\(minutes)"
                    }()
                    let utcDateString = airportService.convertFromLocalToUTCDate(
                        localDateString: localDateString,
                        localTimeString: localOutTime,
                        airportICAO: departureICAO
                    )

                    // Parse UTC date string back to Date for comparison
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd/MM/yyyy"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

                    guard let utcDate = dateFormatter.date(from: utcDateString) else {
                        continue
                    }

                    // Build all leading-zero variants so the fetch matches regardless of stored format.
                    // Must cover both padded ("QF0427") and stripped ("QF427") forms because the
                    // user may have toggled the setting between imports.
                    var rawNum = parsedFlight.flightNumber
                    if rawNum.hasPrefix("QFA") { rawNum = String(rawNum.dropFirst(3)) }
                    else if rawNum.hasPrefix("QF") { rawNum = String(rawNum.dropFirst(2)) }

                    // Numeric prefix and optional trailing suffix (for letter-suffixed flights)
                    let numericPrefix = rawNum.prefix(while: { $0.isNumber })
                    let letterSuffix = String(rawNum.dropFirst(numericPrefix.count))

                    // Stripped form: remove all leading zeros ("0618" → "618", "618" → "618")
                    let strippedCore: String = {
                        let s = numericPrefix.drop(while: { $0 == "0" })
                        return (s.isEmpty ? String(numericPrefix.last ?? "0") : String(s))
                    }()
                    let strippedNum = strippedCore + letterSuffix

                    // Padded form: pad stripped core to 4 digits ("618" → "0618", "1" → "0001")
                    let paddedCore = String(repeating: "0", count: max(0, 4 - strippedCore.count)) + strippedCore
                    let paddedNum = paddedCore + letterSuffix

                    // All plausible stored forms: stripped and padded, with and without QF prefix
                    let flightNumberVariants: [String] = Array(Set([
                        strippedNum,                     // "618"
                        paddedNum,                       // "0618"
                        "QF" + strippedNum,              // "QF618"
                        "QF" + paddedNum,                // "QF0618"
                        parsedFlight.flightNumber        // original as-parsed
                    ]))

                    let flightNumberPredicate = NSCompoundPredicate(orPredicateWithSubpredicates:
                        flightNumberVariants.map { NSPredicate(format: "flightNumber == %@", $0) }
                    )

                    let flightPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "date == %@", utcDate as NSDate),
                        flightNumberPredicate,
                        NSPredicate(format: "fromAirport == %@", departureICAO),
                        NSPredicate(format: "toAirport == %@", arrivalICAO)
                    ])
                    predicates.append(flightPredicate)
                }

                // Combine all predicates with OR
                if !predicates.isEmpty {
                    request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                }

                do {
                    let existingFlights = try context.fetch(request)
                    continuation.resume(returning: existingFlights)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Check if a parsed flight is a duplicate of an existing flight
    private func isDuplicate(_ parsedFlight: RosterParserService.ParsedFlight, in existingFlights: [FlightEntity]) -> Bool {
        let airportService = AirportService.shared

        // Convert IATA codes to ICAO for comparison
        let departureICAO = airportService.convertToICAO(parsedFlight.departureAirport)
        let arrivalICAO = airportService.convertToICAO(parsedFlight.arrivalAirport)

        // Convert local date to UTC for comparison
        // IMPORTANT: parsedFlight.date is created by Calendar.current in device timezone
        // We need to extract day/month/year components in device timezone, then treat as local departure time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: parsedFlight.date)

        guard let day = components.day, let month = components.month, let year = components.year else {
            return false
        }

        let localDateString = String(format: "%02d/%02d/%04d", day, month, year)

        let localOutTime = formatTime(parsedFlight.departureTime)
        let utcDateString = airportService.convertFromLocalToUTCDate(
            localDateString: localDateString,
            localTimeString: localOutTime,
            airportICAO: departureICAO
        )

                    print("   Date conversion for duplicate check:")
                    print("      Local date: \(localDateString) \(localOutTime)")
                    print("      UTC date string: \(utcDateString)")

        let utcDateFormatter = DateFormatter()
        utcDateFormatter.dateFormat = "dd/MM/yyyy"
        utcDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        guard let utcDate = utcDateFormatter.date(from: utcDateString) else {
            return false
        }

        for existing in existingFlights {
            // Debug: Show comparison details
            let debugFormatter = DateFormatter()
            debugFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
            debugFormatter.timeZone = TimeZone(secondsFromGMT: 0)

                        print("   Comparing with existing flight:")
                        print("      Parsed UTC date: \(debugFormatter.string(from: utcDate))")
            if let existingDate = existing.date {
                            print("      Existing UTC date: \(debugFormatter.string(from: existingDate))")
            }
                        print("      Flight numbers: \(parsedFlight.flightNumber) vs \(existing.flightNumber ?? "nil")")
                        print("      Routes: \(departureICAO)-\(arrivalICAO) vs \(existing.fromAirport ?? "nil")-\(existing.toAirport ?? "nil")")

            // Match on UTC date, flight number, and ICAO airport codes
            // Normalise flight numbers: strip airline prefix and all leading zeros so
            // "QF0427", "QF427", "0427", "427" all compare as equal.
            let parsedFlightNum = normaliseFlightNumber(parsedFlight.flightNumber)
            let existingFlightNum = normaliseFlightNumber(existing.flightNumber ?? "")

            if existing.date == utcDate &&
               existingFlightNum == parsedFlightNum &&
               existing.fromAirport == departureICAO &&
               existing.toAirport == arrivalICAO {
                            print("       MATCH FOUND - this is a duplicate!")
                return true
            }
        }
        return false
    }

    // MARK: - Flight Creation

    /// Create a FlightEntity from a parsed flight
    private func createFlight(from parsedFlight: RosterParserService.ParsedFlight) async throws {
        let context = databaseService.viewContext

        // Convert airport codes to ICAO format for timezone lookup
        let airportService = AirportService.shared
        let departureICAO = airportService.convertToICAO(parsedFlight.departureAirport)
        let arrivalICAO = airportService.convertToICAO(parsedFlight.arrivalAirport)

        // Format date for timezone conversion (roster date is in local time of departure airport)
        // IMPORTANT: parsedFlight.date is created by Calendar.current in device timezone
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: parsedFlight.date)

        guard let day = components.day, let month = components.month, let year = components.year else {
            throw NSError(domain: "PlannedFlightService", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid date components"])
        }

        let localDateString = String(format: "%02d/%02d/%04d", day, month, year)

        // Convert local times to UTC
        // Roster times are in LOCAL time of the respective airports
        let localOutTime = formatTime(parsedFlight.departureTime)
        let localInTime = formatTime(parsedFlight.arrivalTime)

        // Convert departure time from local to UTC using departure airport timezone
        let utcOutTime = airportService.convertFromLocalToUTCTime(
            localDateString: localDateString,
            localTimeString: localOutTime,
            airportICAO: departureICAO
        )
                    print("    STD conversion: Local '\(localOutTime)' -> UTC '\(utcOutTime)'")

        // For arrival time, we need to calculate the local arrival date first
        // (it might be next day if flight crosses midnight)
        let arrivalLocalDate = calculateArrivalLocalDate(
            departureDate: parsedFlight.date,
            departureTime: parsedFlight.departureTime,
            arrivalTime: parsedFlight.arrivalTime
        )
        let arrivalComponents = calendar.dateComponents([.year, .month, .day], from: arrivalLocalDate)
        guard let arrDay = arrivalComponents.day, let arrMonth = arrivalComponents.month, let arrYear = arrivalComponents.year else {
            throw NSError(domain: "PlannedFlightService", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid arrival date components"])
        }
        let arrivalLocalDateString = String(format: "%02d/%02d/%04d", arrDay, arrMonth, arrYear)

        // Convert arrival time from local to UTC using arrival airport timezone
        let utcInTime = airportService.convertFromLocalToUTCTime(
            localDateString: arrivalLocalDateString,
            localTimeString: localInTime,
            airportICAO: arrivalICAO
        )
                    print("    STA conversion: Local '\(localInTime)' -> UTC '\(utcInTime)'")

        // Convert departure date from local to UTC
        let utcDateString = airportService.convertFromLocalToUTCDate(
            localDateString: localDateString,
            localTimeString: localOutTime,
            airportICAO: departureICAO
        )

        // Convert UTC date string back to Date object for storage
        // CRITICAL: Set timezone to UTC before parsing, otherwise DateFormatter uses device local timezone
        let utcDateFormatter = DateFormatter()
        utcDateFormatter.dateFormat = "dd/MM/yyyy"
        utcDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let utcDate = utcDateFormatter.date(from: utcDateString) ?? parsedFlight.date

                    print("   Date conversion: Local '\(localDateString)' -> UTC '\(utcDateString)'")

        // Format flight number with airline prefix if setting is enabled (before entering closure)
        let formattedFlightNumber = formatFlightNumber(parsedFlight.flightNumber)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                let flight = FlightEntity(context: context)

                flight.id = UUID()
                flight.createdAt = Date()
                flight.modifiedAt = Date()

                // Basic flight information - use UTC date and ICAO codes
                flight.date = utcDate
                flight.flightNumber = formattedFlightNumber
                flight.fromAirport = departureICAO
                flight.toAirport = arrivalICAO
                flight.aircraftType = parsedFlight.aircraftType

                // Set aircraft registration to empty (will be filled when flight is actually flown)
                flight.aircraftReg = ""

                // Set crew names to empty (will be filled when flight is actually flown)
                flight.captainName = ""
                flight.foName = ""
                flight.so1Name = nil
                flight.so2Name = nil

                // Set scheduled departure and arrival times in UTC (roster times)
                flight.scheduledDeparture = utcOutTime
                flight.scheduledArrival = utcInTime

                // Set actual departure and arrival times to empty (will be filled when flight is actually flown)
                flight.outTime = ""
                flight.inTime = ""

                // Set all time fields to "0.0" (required fields - will be filled when flight is actually flown)
                flight.blockTime = "0.0"
                flight.nightTime = "0.0"
                flight.p1Time = "0.0"
                flight.p2Time = "0.0"
                flight.p1usTime = "0.0"
                flight.instrumentTime = "0.0"
                flight.simTime = "0.0"

                // Set takeoffs and landings to 0
                flight.dayTakeoffs = 0
                flight.dayLandings = 0
                flight.nightTakeoffs = 0
                flight.nightLandings = 0

                // Set isPilotFlying to false by default (will be updated when flight is actually flown)
                flight.isPilotFlying = false

                // Set positioning flag
                flight.isPositioning = parsedFlight.isPositioning

                // Set approach flags to false (will be filled when flight is actually flown)
                flight.isAIII = false
                flight.isRNP = false
                flight.isILS = false
                flight.isGLS = false
                flight.isNPA = false

//                // Add a remark to indicate this is a planned flight
//                var remarks = "Imported from roster"
//                if let dutyCode = parsedFlight.dutyCode {
//                    remarks += " (\(dutyCode))"
//                }
//                flight.remarks = remarks

                // Save the flight
                do {
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Format flight number with airline prefix and leading zero handling based on user settings
    private func formatFlightNumber(_ flightNumber: String) -> String {
        let settings = userDefaultsService.loadSettings()
        var formatted = flightNumber

        // Only add prefix if setting is enabled
        if settings.includeAirlinePrefixInFlightNumber {
            // Only add prefix if it's not already there
            if !formatted.hasPrefix(settings.airlinePrefix) {
                formatted = settings.airlinePrefix + formatted
            }
        }

        // Apply leading zero preference to the numeric part
        if formatted.hasPrefix(settings.airlinePrefix) {
            let numericPart = String(formatted.dropFirst(settings.airlinePrefix.count))
            let adjusted = settings.includeLeadingZeroInFlightNumber
                ? padToFourDigits(numericPart)
                : stripLeadingZeros(numericPart)
            formatted = settings.airlinePrefix + adjusted
        } else {
            formatted = settings.includeLeadingZeroInFlightNumber
                ? padToFourDigits(formatted)
                : stripLeadingZeros(formatted)
        }

        return formatted
    }

    /// Pad the numeric prefix of a flight number to 4 digits, preserving any trailing letter suffix.
    /// e.g. "427" → "0427", "1" → "0001", "0427" → "0427", "412D" → "0412D".
    /// Already at 4+ digits or non-numeric strings are returned unchanged.
    private func padToFourDigits(_ number: String) -> String {
        let numericPrefix = number.prefix(while: { $0.isNumber })
        let suffix = String(number.dropFirst(numericPrefix.count))
        guard !numericPrefix.isEmpty else { return number }
        let stripped = String(numericPrefix.drop(while: { $0 == "0" }))
        let core = stripped.isEmpty ? "0" : stripped
        let padded = String(repeating: "0", count: max(0, 4 - core.count)) + core
        return padded + suffix
    }

    /// Strip all leading zeros from a flight number string, preserving any trailing letter suffix.
    /// Only operates on purely numeric strings — if a letter suffix is present (e.g. "0412D"),
    /// zeros are stripped from the numeric prefix only: "0412D" → "412D".
    /// Leaves a single "0" intact if the entire numeric part is zero.
    private func stripLeadingZeros(_ number: String) -> String {
        let numericPrefix = number.prefix(while: { $0.isNumber })
        let suffix = number.dropFirst(numericPrefix.count)
        guard !numericPrefix.isEmpty else { return number }
        let stripped = numericPrefix.drop(while: { $0 == "0" })
        let result = stripped.isEmpty ? String(numericPrefix.last!) : String(stripped)
        return result + suffix
    }

    /// Normalise a flight number for duplicate comparison by stripping the airline prefix
    /// and all leading zeros from the numeric part. Trailing letter suffixes are preserved.
    /// Examples: "QF0427" → "427", "QFA0001" → "1", "QF412D" → "412D", "427" → "427"
    private func normaliseFlightNumber(_ flightNumber: String) -> String {
        var digits = flightNumber
        // Strip QFA before QF to avoid partial removal
        if digits.hasPrefix("QFA") { digits = String(digits.dropFirst(3)) }
        else if digits.hasPrefix("QF") { digits = String(digits.dropFirst(2)) }
        return stripLeadingZeros(digits)
    }

    /// Format time from HHmm to HH:mm
    private func formatTime(_ time: String) -> String {
        guard time.count == 4 else { return time }
        let hours = time.prefix(2)
        let minutes = time.suffix(2)
        return "\(hours):\(minutes)"
    }

    /// Calculate arrival local date, handling flights that cross midnight
    /// - Parameters:
    ///   - departureDate: Departure date (local time)
    ///   - departureTime: Departure time in "HHmm" format (local time)
    ///   - arrivalTime: Arrival time in "HHmm" format (local time)
    /// - Returns: Arrival date (local time), potentially next day if flight crosses midnight
    private func calculateArrivalLocalDate(departureDate: Date, departureTime: String, arrivalTime: String) -> Date {
        guard departureTime.count == 4, arrivalTime.count == 4 else {
            return departureDate
        }

        guard let depHour = Int(departureTime.prefix(2)),
              let depMin = Int(departureTime.suffix(2)),
              let arrHour = Int(arrivalTime.prefix(2)),
              let arrMin = Int(arrivalTime.suffix(2)) else {
            return departureDate
        }

        let depTimeMinutes = depHour * 60 + depMin
        let arrTimeMinutes = arrHour * 60 + arrMin

        // If arrival time is earlier than departure time, flight crosses midnight
        if arrTimeMinutes < depTimeMinutes {
            // Add one day
            return Calendar.current.date(byAdding: .day, value: 1, to: departureDate) ?? departureDate
        }

        return departureDate
    }

    // MARK: - Query Methods

    /// Get all future flights (flights with date >= today)
    public func getFutureFlights() -> [FlightEntity] {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        let today = Calendar.current.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "date >= %@", today as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true)]

        do {
            return try databaseService.viewContext.fetch(request)
        } catch {
                        print("Error fetching future flights: \(error.localizedDescription)")
            return []
        }
    }

    /// Check if a flight is in the future
    public func isFutureFlight(_ flight: FlightEntity) -> Bool {
        guard let flightDate = flight.date else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        return flightDate >= today
    }

    /// Check if a flight has been flown (has block time or flight time logged).
    /// Roster-imported placeholder flights store times as "0.0"; treat that as zero alongside "00:00" and "0".
    public func isFlown(_ flight: FlightEntity) -> Bool {
        func hasTime(_ value: String?) -> Bool {
            guard let v = value, !v.isEmpty else { return false }
            if let d = Double(v) { return d > 0 }
            // HH:MM format
            let parts = v.split(separator: ":").compactMap { Int($0) }
            return parts.reduce(0, +) > 0
        }
        return hasTime(flight.blockTime) || hasTime(flight.p1Time) || hasTime(flight.p2Time)
    }

    // MARK: - Stale Flight Detection

    /// Find unflown logbook flights inside [periodStart...periodEnd] (inclusive, by day) that are
    /// NOT present in the new roster. Flown flights are always excluded regardless of key match.
    /// Roster flights are matched by normalised flight number + ICAO route + same UTC calendar day.
    public func findStaleFlights(
        periodStart: Date,
        periodEnd: Date,
        rosterFlights: [RosterParserService.ParsedFlight]
    ) async -> [FlightEntity] {
        let context = databaseService.viewContext

        let staleIDs: [NSManagedObjectID] = await withCheckedContinuation { continuation in
            context.perform {
                let airportService = AirportService.shared

                // Build UTC day boundaries for the period.
                // periodStart/periodEnd are local-timezone Dates (device calendar), but Core Data stores UTC.
                // Widen by ±1 day so that timezone offsets never push a flight outside the query window.
                // Key-set matching (normalised flight number + ICAO route + UTC day) provides correctness;
                // the wider window only determines which DB rows are candidates for the stale check.
                var utcCal = Calendar(identifier: .gregorian)
                utcCal.timeZone = TimeZone(secondsFromGMT: 0)!

                guard let startOfPeriod = utcCal.date(byAdding: .day, value: -1, to: utcCal.startOfDay(for: periodStart)),
                      let endOfPeriod = utcCal.date(byAdding: .day, value: 2, to: utcCal.startOfDay(for: periodEnd)),
                      let endOfPeriodInclusive = utcCal.date(byAdding: .second, value: -1, to: endOfPeriod) else {
                    continuation.resume(returning: [])
                    return
                }

                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "date >= %@", startOfPeriod as NSDate),
                    NSPredicate(format: "date <= %@", endOfPeriodInclusive as NSDate)
                ])
                request.sortDescriptors = [NSSortDescriptor(keyPath: \FlightEntity.date, ascending: true)]

                let utcDayFormatter = DateFormatter()
                utcDayFormatter.dateFormat = "dd/MM/yyyy"
                utcDayFormatter.locale = Locale(identifier: "en_US_POSIX")
                utcDayFormatter.timeZone = TimeZone(secondsFromGMT: 0)

                print("[StaleDetect] Window: \(utcDayFormatter.string(from: startOfPeriod)) → \(utcDayFormatter.string(from: endOfPeriodInclusive)) (UTC)")
                print("[StaleDetect] periodStart(local)=\(periodStart) periodEnd(local)=\(periodEnd)")

                guard let windowFlights = try? context.fetch(request) else {
                    print("[StaleDetect] Core Data fetch failed")
                    continuation.resume(returning: [])
                    return
                }

                print("[StaleDetect] DB flights in window: \(windowFlights.count)")
                for f in windowFlights {
                    let dateStr = f.date.map { utcDayFormatter.string(from: $0) } ?? "nil"
                    let flown = self.isFlown(f)
                    print("[StaleDetect]   DB: \(f.flightNumber ?? "?") \(f.fromAirport ?? "?")-\(f.toAirport ?? "?") \(dateStr)(UTC) flown=\(flown) blockTime=\(f.blockTime ?? "nil")")
                }

                // Build roster key set: "normalisedFlightNum|depICAO|arrICAO|dd/MM/yyyy(UTC)"
                var rosterKeySet = Set<String>()
                for rosterFlight in rosterFlights {
                    let depICAO = airportService.convertToICAO(rosterFlight.departureAirport)
                    let arrICAO = airportService.convertToICAO(rosterFlight.arrivalAirport)

                    let calendar = Calendar.current
                    let comps = calendar.dateComponents([.year, .month, .day], from: rosterFlight.date)
                    guard let day = comps.day, let month = comps.month, let year = comps.year else { continue }
                    let localDateString = String(format: "%02d/%02d/%04d", day, month, year)
                    let localOutTime: String = {
                        let t = rosterFlight.departureTime
                        guard t.count == 4 else { return t }
                        return "\(t.prefix(2)):\(t.suffix(2))"
                    }()
                    let utcDateString = airportService.convertFromLocalToUTCDate(
                        localDateString: localDateString,
                        localTimeString: localOutTime,
                        airportICAO: depICAO
                    )

                    let normNum = self.normaliseFlightNumber(rosterFlight.flightNumber)
                    let key = "\(normNum)|\(depICAO)|\(arrICAO)|\(utcDateString)"
                    print("[StaleDetect] Roster key: \(key)  (local=\(localDateString) \(localOutTime) dep=\(rosterFlight.departureAirport)→\(depICAO))")
                    rosterKeySet.insert(key)
                }

                // Identify stale: in window, not flown, not matched in new roster
                var stale: [FlightEntity] = []
                for flight in windowFlights {
                    guard !self.isFlown(flight) else { continue }

                    guard let flightDate = flight.date else { continue }
                    let utcDayStr = utcDayFormatter.string(from: flightDate)
                    let normNum = self.normaliseFlightNumber(flight.flightNumber ?? "")
                    let depICAO = flight.fromAirport ?? ""
                    let arrICAO = flight.toAirport ?? ""
                    let key = "\(normNum)|\(depICAO)|\(arrICAO)|\(utcDayStr)"
                    let matched = rosterKeySet.contains(key)
                    print("[StaleDetect]   DB key: \(key) → \(matched ? "MATCHED (keep)" : "NO MATCH (stale)")")

                    if !matched {
                        stale.append(flight)
                    }
                }

                print("[StaleDetect] Result: \(stale.count) stale flights found")
                let staleIDs = stale.map { $0.objectID }
                continuation.resume(returning: staleIDs)
            }
        }
        return staleIDs.compactMap { context.object(with: $0) as? FlightEntity }
    }

    /// Delete the given stale flight entities from the logbook. Returns count deleted.
    @discardableResult
    func deleteStaleFlights(_ flights: [FlightEntity]) async -> Int {
        guard !flights.isEmpty else { return 0 }

        let context = databaseService.viewContext
        let objectIDs = flights.compactMap { $0.objectID }

        return await withCheckedContinuation { continuation in
            context.perform {
                var deleted = 0
                for objectID in objectIDs {
                    guard let flight = try? context.existingObject(with: objectID) as? FlightEntity else { continue }
                    context.delete(flight)
                    deleted += 1
                }
                try? context.save()
                continuation.resume(returning: deleted)
            }
        }
    }

    /// Get count of future flights
    public func getFutureFlightsCount() -> Int {
        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        let today = Calendar.current.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "date >= %@", today as NSDate)

        do {
            return try databaseService.viewContext.count(for: request)
        } catch {
                        print("Error counting future flights: \(error.localizedDescription)")
            return 0
        }
    }
}
