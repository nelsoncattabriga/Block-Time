//  Block-Time
//
//  Created by Nelson on 8/9/2025.


import Foundation
import UIKit
import Combine

// MARK: - Data Models
struct FlightEntry {
    let flightDate: String
    let aircraftReg: String
    let outTime: String
    let inTime: String
    let flightNumber: String?
    let fromAirport: String?
    let toAirport: String?
    let captainName: String
    let coPilotName: String
    let so1Name: String
    let so2Name: String
    let flightTimePosition: FlightTimePosition
    let isPilotFlying: Bool
    let isAIII: Bool
    let isRNP: Bool
    let isILS: Bool
    let isGLS: Bool
    let isNPA: Bool
    let isICUS: Bool
    let isSimulator: Bool
    let isPositioning: Bool
    let instrumentTimeMinutes: Int?
    let remarks: String?
}

struct LogTenProError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
    }
}

// MARK: - LogTen Pro Service
class LogTenProService: ObservableObject {
    
    // MARK: - Public Methods
    
    /// Send flight data to LogTen Pro
    /// - Parameter flightEntry: The flight data to send
    /// - Returns: Success status
    func sendFlightToLogTenPro(_ flightEntry: FlightEntry) async -> Result<Void, LogTenProError> {
        // Validate required fields
        guard !flightEntry.outTime.isEmpty && !flightEntry.inTime.isEmpty else {
            return .failure(LogTenProError(message: "OUT and IN times are required"))
        }
        
        guard !flightEntry.flightDate.isEmpty && !flightEntry.aircraftReg.isEmpty else {
            return .failure(LogTenProError(message: "Aircraft registration required"))
        }
        
        // Create the LogTen Pro URL
        let logTenURL = createLogTenProURL(from: flightEntry)
        
        // Log for debugging
        print("=== LogTen Pro URL Debug ===")
        print("Generated URL: \(logTenURL.absoluteString)")
        print("URL length: \(logTenURL.absoluteString.count)")
        
        // Attempt to open LogTen Pro
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                UIApplication.shared.open(logTenURL) { success in
                    if success {
                        print("SUCCESS: LogTen Pro opened successfully")
                        continuation.resume(returning: .success(()))
                    } else {
                        print("FAILED: LogTen Pro did not open")
                        continuation.resume(returning: .failure(LogTenProError(message: "Failed to open LogTen Pro. Make sure LogTen Pro is installed and supports the API.")))
                    }
                }
            }
        }
    }
    
    /// Check if LogTen Pro can be opened (optional - iOS sometimes blocks canOpenURL)
    func canOpenLogTenPro() -> Bool {
        guard let logTenURL = URL(string: "logten://") else { return false }
        return UIApplication.shared.canOpenURL(logTenURL)
    }
    
    // MARK: - Private Methods
    
    private func createLogTenProURL(from flightEntry: FlightEntry) -> URL {
        // Build the flight entity dictionary
        var flightEntity: [String: Any] = [
            "entity_name": "Flight",
            "flight_flightDate": flightEntry.flightDate,
            "flight_selectedAircraftID": flightEntry.aircraftReg,
            "flight_actualDepartureTime": "\(flightEntry.flightDate) \(flightEntry.outTime)",
            "flight_actualArrivalTime": "\(flightEntry.flightDate) \(flightEntry.inTime)",
            "flight_key": "FlightExtractor_\(UUID().uuidString)"
        ]
        
        // Add optional flight number
        if let flightNumber = flightEntry.flightNumber, !flightNumber.isEmpty {
            flightEntity["flight_flightNumber"] = flightNumber
        }
        
        // Add optional airports
        if let fromAirport = flightEntry.fromAirport, !fromAirport.isEmpty {
            flightEntity["flight_from"] = fromAirport
        }
        if let toAirport = flightEntry.toAirport, !toAirport.isEmpty {
            flightEntity["flight_to"] = toAirport
        }
        
        // Add optional remarks
        if let remarks = flightEntry.remarks, !remarks.isEmpty {
            flightEntity["flight_remarks"] = remarks
        }
        
        // Set crew information based on flight time position
        setupCrewRoles(in: &flightEntity, for: flightEntry)
        
        // Calculate and set flight times
        let flightTime = calculateFlightTime(from: flightEntry.outTime, to: flightEntry.inTime)
        setupFlightTimes(in: &flightEntity, flightTime: flightTime, for: flightEntry)
        
        if let instMins = flightEntry.instrumentTimeMinutes, instMins > 0 {
            flightEntity["flight_actualInstrument"] = instMins
        }

        // Add approach type custom operations - only if PF
        flightEntity["flight_customOp10"] = flightEntry.isPilotFlying && flightEntry.isAIII
        flightEntity["flight_customOp11"] = flightEntry.isPilotFlying && flightEntry.isRNP
        flightEntity["flight_customOp12"] = flightEntry.isPilotFlying && flightEntry.isILS
        flightEntity["flight_customOp13"] = flightEntry.isPilotFlying && flightEntry.isGLS
        flightEntity["flight_customOp14"] = flightEntry.isPilotFlying && flightEntry.isNPA
        
        // Create the complete package
        let metadata: [String: Any] = [
            "application": "Block-Time",
            "version": "1.0",
            "serviceID": "com.logger.app",
            "serviceAccountKey": UUID().uuidString,
            "dateFormat": "dd/MM/yyyy",
            "dateAndTimeFormat": "dd/MM/yyyy HH:mm",
            "timesAreZulu": true
        ]
        
        let package: [String: Any] = [
            "metadata": metadata,
            "entities": [flightEntity]
        ]
        
        // Convert to JSON and create URL
        return createURLFromPackage(package)
    }
    
    private func setupCrewRoles(in flightEntity: inout [String: Any], for flightEntry: FlightEntry) {
        // Always set crew names when they are not empty
        if !flightEntry.captainName.isEmpty {
            flightEntity["flight_selectedCrewPIC"] = flightEntry.captainName
        }

        if !flightEntry.coPilotName.isEmpty {
            flightEntity["flight_selectedCrewSIC"] = flightEntry.coPilotName
        }

        if !flightEntry.so1Name.isEmpty {
            flightEntity["flight_selectedCrewRelief"] = flightEntry.so1Name
        }

        if !flightEntry.so2Name.isEmpty {
            flightEntity["flight_selectedCrewRelief2"] = flightEntry.so2Name
        }

        // Set "Self" designation based on position
        switch flightEntry.flightTimePosition {
        case .captain:
            if flightEntry.captainName.isEmpty {
                flightEntity["flight_selectedCrewPIC"] = "Self"
            }

        case .firstOfficer:
            if flightEntry.coPilotName.isEmpty {
                flightEntity["flight_selectedCrewSIC"] = "Self"
            }

        case .secondOfficer:
            if flightEntry.so1Name.isEmpty {
                flightEntity["flight_selectedCrewRelief"] = "Self"
            }
        }
    }
    
    private func setupFlightTimes(in flightEntity: inout [String: Any], flightTime: String, for flightEntry: FlightEntry) {
        // If simulator, use flight_simulator key and set flight_type to 3
        if flightEntry.isSimulator {
            flightEntity["flight_simulator"] = flightTime
            flightEntity["flight_pilotFlyingCapacity"] = flightEntry.isPilotFlying
            flightEntity["flight_type"] = 3  // Simulator flight
            return
        }

        // If positioning/PAX flight, set flight_type to 1
        if flightEntry.isPositioning {
            flightEntity["flight_type"] = 1  // Positioning flight
            // No time credits logged for positioning flights
            return
        }

        // Set flight_type to 0 for regular flights
        flightEntity["flight_type"] = 0

        // Regular flight time logging
        switch flightEntry.flightTimePosition {
        case .captain:
            flightEntity["flight_pic"] = flightTime
            flightEntity["flight_picCapacity"] = true
            flightEntity["flight_pilotFlyingCapacity"] = flightEntry.isPilotFlying

        case .firstOfficer:
            if flightEntry.isICUS {
                // F/O is in command under supervision
                if flightEntry.isPilotFlying {
                    // ICUS and PF - log as P1US time
                    flightEntity["flight_p1us"] = flightTime
                } else {
                    // ICUS but not PF - log as SIC time
                    flightEntity["flight_sic"] = flightTime
                }
                flightEntity["flight_sicCapacity"] = true
                flightEntity["flight_pilotFlyingCapacity"] = flightEntry.isPilotFlying
            } else {
                // Standard F/O (not ICUS) - always log as SIC time regardless of PF status
                flightEntity["flight_sic"] = flightTime
                flightEntity["flight_sicCapacity"] = true
                flightEntity["flight_pilotFlyingCapacity"] = flightEntry.isPilotFlying
            }

        case .secondOfficer:
            // Second Officer logs flight time as if they were First Officer
            flightEntity["flight_sic"] = flightTime
            flightEntity["flight_sicCapacity"] = true
            flightEntity["flight_pilotFlyingCapacity"] = flightEntry.isPilotFlying
        }
    }
    
    private func calculateFlightTime(from outTime: String, to inTime: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let outTimeDate = formatter.date(from: outTime),
              let inTimeDate = formatter.date(from: inTime) else {
            return "0:00"
        }
        
        var flightDuration = inTimeDate.timeIntervalSince(outTimeDate)
        
        // Handle overnight flights (in time is next day)
        if flightDuration < 0 {
            flightDuration += 24 * 60 * 60 // Add 24 hours
        }
        
        let totalSeconds = Int(flightDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds - (hours * 3600)) / 60
        
        return String(format: "%d:%02d", hours, minutes)
    }
    
    private func createURLFromPackage(_ package: [String: Any]) -> URL {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: package, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)!
            let encodedPackage = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let urlString = "logten://v2/addEntities?package=\(encodedPackage)"
            return URL(string: urlString)!
        } catch {
            print("Failed to create LogTen Pro URL: \(error.localizedDescription)")
            return URL(string: "logten://")!
        }
    }
}

// MARK: - Convenience Extensions
extension LogTenProService {
    
    /// Create a FlightEntry from individual parameters for easier usage
    static func createFlightEntry(
        flightDate: String,
        aircraftReg: String,
        outTime: String,
        inTime: String,
        flightNumber: String? = nil,
        fromAirport: String? = nil,
        toAirport: String? = nil,
        captainName: String,
        coPilotName: String,
        so1Name: String = "",
        so2Name: String = "",
        flightTimePosition: FlightTimePosition,
        isPilotFlying: Bool,
        isAIII: Bool,
        isRNP: Bool = false,
        isILS: Bool = false,
        isGLS: Bool = false,
        isNPA: Bool = false,
        isICUS: Bool = false,
        isSimulator: Bool = false,
        isPositioning: Bool = false,
        instrumentTimeMinutes: Int? = nil,
        remarks: String? = nil
    ) -> FlightEntry {
        return FlightEntry(
            flightDate: flightDate,
            aircraftReg: aircraftReg,
            outTime: outTime,
            inTime: inTime,
            flightNumber: flightNumber,
            fromAirport: fromAirport,
            toAirport: toAirport,
            captainName: captainName,
            coPilotName: coPilotName,
            so1Name: so1Name,
            so2Name: so2Name,
            flightTimePosition: flightTimePosition,
            isPilotFlying: isPilotFlying,
            isAIII: isAIII,
            isRNP: isRNP,
            isILS: isILS,
            isGLS: isGLS,
            isNPA: isNPA,
            isICUS: isICUS,
            isSimulator: isSimulator,
            isPositioning: isPositioning,
            instrumentTimeMinutes: instrumentTimeMinutes,
            remarks: remarks
        )
    }
}
