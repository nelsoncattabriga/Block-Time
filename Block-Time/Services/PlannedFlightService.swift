//
//  PlannedFlightService.swift
//  Block-Time
//
//  Created by Nelson on 18/10/2025.
//

import Foundation
import CoreData

/// Service to import planned flights from rosters into the main flight database
class PlannedFlightService {

    // MARK: - Properties

    private let databaseService = FlightDatabaseService.shared
    private let userDefaultsService = UserDefaultsService()

    // MARK: - Import Results

    struct ImportResult {
        let imported: Int
        let duplicates: Int
        let errors: Int
        let flights: [ImportedFlight]
    }

    struct ImportedFlight {
        let flight: RosterParserService.ParsedFlight
        let isDuplicate: Bool
        let error: String?
    }

    // MARK: - Import Methods

    /// Import future flights from a roster file
    func importRoster(from fileURL: URL) async throws -> ImportResult {
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
    func importFlights(_ parsedFlights: [RosterParserService.ParsedFlight]) async throws -> ImportResult {
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

            print("\n✈️  Processing: \(parsedFlight.flightNumber) on \(dateString) (\(parsedFlight.departureAirport)-\(parsedFlight.arrivalAirport))")

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

        print("\n📈 Import Summary:")
        print("   Imported: \(imported)")
        print("    Duplicates: \(duplicates)")
        print("   Errors: \(errors)")

        return ImportResult(
            imported: imported,
            duplicates: duplicates,
            errors: errors,
            flights: results
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

                    // Normalize flight number (remove QF prefix) for broader matching
                    let normalizedFlightNumber = parsedFlight.flightNumber.replacingOccurrences(of: "QF", with: "")

                    // Create predicates for both with and without QF prefix
                    let flightNumberPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "flightNumber == %@", parsedFlight.flightNumber),
                        NSPredicate(format: "flightNumber == %@", "QF\(normalizedFlightNumber)"),
                        NSPredicate(format: "flightNumber == %@", normalizedFlightNumber)
                    ])

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
            // Normalize flight numbers for comparison (remove "QF" prefix if present)
            let parsedFlightNum = parsedFlight.flightNumber.replacingOccurrences(of: "QF", with: "")
            let existingFlightNum = (existing.flightNumber ?? "").replacingOccurrences(of: "QF", with: "")

            if existing.date == utcDate &&
               existingFlightNum == parsedFlightNum &&
               existing.fromAirport == departureICAO &&
               existing.toAirport == arrivalICAO {
                print("      ✓ MATCH FOUND - this is a duplicate!")
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
        print("   ⏰ STD conversion: Local '\(localOutTime)' -> UTC '\(utcOutTime)'")

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
        print("   ⏰ STA conversion: Local '\(localInTime)' -> UTC '\(utcInTime)'")

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

    /// Format flight number with airline prefix if user setting is enabled
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

        // Handle leading zero based on settings
        if formatted.contains(settings.airlinePrefix) && !settings.includeLeadingZeroInFlightNumber {
            if formatted.hasPrefix(settings.airlinePrefix + "0") {
                formatted = settings.airlinePrefix + String(formatted.dropFirst(settings.airlinePrefix.count + 1))
            }
        } else if !formatted.contains(settings.airlinePrefix) && !settings.includeLeadingZeroInFlightNumber {
            if formatted.hasPrefix("0") {
                formatted = String(formatted.dropFirst())
            }
        }

        return formatted
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
    func getFutureFlights() -> [FlightEntity] {
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
    func isFutureFlight(_ flight: FlightEntity) -> Bool {
        guard let flightDate = flight.date else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        return flightDate >= today
    }

    /// Check if a flight has been flown (has block time or flight time logged)
    func isFlown(_ flight: FlightEntity) -> Bool {
        // A flight is considered "flown" if it has block time or any flight time logged
        if let blockTime = flight.blockTime, !blockTime.isEmpty, blockTime != "00:00" {
            return true
        }
        if let p1Time = flight.p1Time, !p1Time.isEmpty, p1Time != "00:00" {
            return true
        }
        if let p2Time = flight.p2Time, !p2Time.isEmpty, p2Time != "00:00" {
            return true
        }
        return false
    }

    /// Get count of future flights
    func getFutureFlightsCount() -> Int {
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
