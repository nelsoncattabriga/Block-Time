//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//


import Foundation
import CoreData
import Combine


// MARK: - Aircraft Model
public struct Aircraft: Codable, Identifiable, Hashable {
    public let id: String
    public let registration: String
    public let type: String
    public let fullRegistration: String
    
    /// Standard init for preset fleet aircraft — registration stored without "VH-" prefix.
    public init(registration: String, type: String) {
        self.id = registration
        self.registration = registration
        self.type = type
        self.fullRegistration = "VH-\(registration)"
    }

    /// Init for user-entered custom registrations.
    /// - If the input starts with "VH-", stores the short form so the showFullReg toggle works normally.
    /// - Otherwise (e.g. "B738SIM"), stores as-is with no "VH-" prepended.
    public init(customRegistration rawInput: String, type: String) {
        let upper = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if upper.hasPrefix("VH-") {
            let short = String(upper.dropFirst(3))
            self.id = short
            self.registration = short
            self.fullRegistration = upper
        } else {
            // Non-VH registration (sim, foreign, custom) — display identically regardless of showFullReg
            self.id = upper
            self.registration = upper
            self.fullRegistration = upper
        }
        self.type = type
    }

    public func displayRegistration(showFullReg: Bool) -> String {
        return showFullReg ? fullRegistration : registration
    }
}

// MARK: - Fleet Selection
public struct Fleet: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let types: [String]
    public let prefix: String?
    public let aircraft: [Aircraft]

    /// Returns true if the given type code belongs to this fleet —
    /// either via exact match in `types` or prefix match.
    public func typeMatches(_ type: String) -> Bool {
        if types.contains(type) { return true }
        if let prefix, type.hasPrefix(prefix) { return true }
        return false
    }

    /// Init for static fleets — declares the canonical type codes for this family.
    /// Aircraft are filtered from qantasFleet automatically.
    public init(name: String, types: [String], prefix: String? = nil) {
        self.id = name
        self.name = name
        self.types = types
        self.prefix = prefix
        self.aircraft = AircraftFleetService.qantasFleet.filter { types.contains($0.type) }
    }

    /// Init for dynamically-built fleets (e.g. custom aircraft). Types are inferred from aircraft.
    public init(name: String, aircraft: [Aircraft], prefix: String? = nil) {
        self.id = name
        self.name = name
        self.types = aircraft.map(\.type)
        self.prefix = prefix
        self.aircraft = aircraft
    }
}

// MARK: - Aircraft Fleet Service
@MainActor
public class AircraftFleetService: ObservableObject {

    // MARK: - Singleton
    public static let shared = AircraftFleetService()

    private var viewContext: NSManagedObjectContext {
        return FlightDatabaseService.shared.viewContext
    }

    // MARK: - Core Static Fleet Data
    // Note: Custome aircraft are stored in the core data AircraftEntity and are saved to icloud.
    // Static list just keeps things fast and efficient with no DB lookup required.
    
    public static let qantasFleet: [Aircraft] = [
        // Boeing 737-800
        Aircraft(registration: "VXA", type: "B738"),
        Aircraft(registration: "VXB", type: "B738"),
        Aircraft(registration: "VXC", type: "B738"),
        Aircraft(registration: "VXD", type: "B738"),
        Aircraft(registration: "VXE", type: "B738"),
        Aircraft(registration: "VXF", type: "B738"),
        Aircraft(registration: "VXG", type: "B738"),
        Aircraft(registration: "VXH", type: "B738"),
        Aircraft(registration: "VXI", type: "B738"),
        Aircraft(registration: "VXJ", type: "B738"),
        Aircraft(registration: "VXK", type: "B738"),
        Aircraft(registration: "VXL", type: "B738"),
        Aircraft(registration: "VXM", type: "B738"),
        Aircraft(registration: "VXN", type: "B738"),
        Aircraft(registration: "VXO", type: "B738"),
        Aircraft(registration: "VXP", type: "B738"),
        Aircraft(registration: "VXQ", type: "B738"),
        Aircraft(registration: "VXR", type: "B738"),
        Aircraft(registration: "VXS", type: "B738"),
        Aircraft(registration: "VXT", type: "B738"),
        Aircraft(registration: "VXU", type: "B738"),
        
        Aircraft(registration: "VYA", type: "B738"),
        Aircraft(registration: "VYB", type: "B738"),
        Aircraft(registration: "VYC", type: "B738"),
        Aircraft(registration: "VYD", type: "B738"),
        Aircraft(registration: "VYE", type: "B738"),
        Aircraft(registration: "VYF", type: "B738"),
        Aircraft(registration: "VYG", type: "B738"),
        Aircraft(registration: "VYH", type: "B738"),
        Aircraft(registration: "VYI", type: "B738"),
        Aircraft(registration: "VYJ", type: "B738"),
        Aircraft(registration: "VYK", type: "B738"),
        Aircraft(registration: "VYL", type: "B738"),
        Aircraft(registration: "VYZ", type: "B738"),
        
        Aircraft(registration: "VZA", type: "B738"),
        Aircraft(registration: "VZB", type: "B738"),
        Aircraft(registration: "VZC", type: "B738"),
        Aircraft(registration: "VZD", type: "B738"),
        Aircraft(registration: "VZE", type: "B738"),
        Aircraft(registration: "VZF", type: "B738"),
        Aircraft(registration: "VZG", type: "B738"),
        Aircraft(registration: "VZH", type: "B738"),
        Aircraft(registration: "VZI", type: "B738"),
        Aircraft(registration: "VZJ", type: "B738"),
        Aircraft(registration: "VZK", type: "B738"),
        Aircraft(registration: "VZL", type: "B738"),
        Aircraft(registration: "VZM", type: "B738"),
        Aircraft(registration: "VZN", type: "B738"),
        Aircraft(registration: "VZO", type: "B738"),
        Aircraft(registration: "VZP", type: "B738"),
        Aircraft(registration: "VZQ", type: "B738"),
        Aircraft(registration: "VZR", type: "B738"),
        Aircraft(registration: "VZS", type: "B738"),
        Aircraft(registration: "VZT", type: "B738"),
        Aircraft(registration: "VZU", type: "B738"),
        Aircraft(registration: "VZV", type: "B738"),
        Aircraft(registration: "VZW", type: "B738"),
        Aircraft(registration: "VZX", type: "B738"),
        Aircraft(registration: "VZY", type: "B738"),
        Aircraft(registration: "VZZ", type: "B738"),
        
        Aircraft(registration: "XZA", type: "B738"),
        Aircraft(registration: "XZB", type: "B738"),
        Aircraft(registration: "XZC", type: "B738"),
        Aircraft(registration: "XZD", type: "B738"),
        Aircraft(registration: "XZE", type: "B738"),
        Aircraft(registration: "XZF", type: "B738"),
        Aircraft(registration: "XZG", type: "B738"),
        Aircraft(registration: "XZH", type: "B738"),
        Aircraft(registration: "XZI", type: "B738"),
        Aircraft(registration: "XZJ", type: "B738"),
        Aircraft(registration: "XZK", type: "B738"),
        Aircraft(registration: "XZL", type: "B738"),
        Aircraft(registration: "XZM", type: "B738"),
        Aircraft(registration: "XZN", type: "B738"),
        Aircraft(registration: "XZO", type: "B738"),
        Aircraft(registration: "XZP", type: "B738"),
        Aircraft(registration: "XZQ", type: "B738"),
        Aircraft(registration: "XZR", type: "B738"),
        Aircraft(registration: "XZS", type: "B738"),
        Aircraft(registration: "XZT", type: "B738"),
        
        // A321 XLR
        Aircraft(registration: "OGA", type: "A21N"),
        Aircraft(registration: "OGB", type: "A21N"),
        Aircraft(registration: "OGC", type: "A21N"),
        Aircraft(registration: "OGD", type: "A21N"),
        Aircraft(registration: "OGE", type: "A21N"),
        Aircraft(registration: "OGF", type: "A21N"),
        Aircraft(registration: "OGG", type: "A21N"),
        
        // B787
        Aircraft(registration: "ZNA", type: "B789"),
        Aircraft(registration: "ZNB", type: "B789"),
        Aircraft(registration: "ZNC", type: "B789"),
        Aircraft(registration: "ZND", type: "B789"),
        Aircraft(registration: "ZNE", type: "B789"),
        Aircraft(registration: "ZNF", type: "B789"),
        Aircraft(registration: "ZNG", type: "B789"),
        Aircraft(registration: "ZNH", type: "B789"),
        Aircraft(registration: "ZNI", type: "B789"),
        Aircraft(registration: "ZNJ", type: "B789"),
        Aircraft(registration: "ZNK", type: "B789"),
        Aircraft(registration: "ZNL", type: "B789"),
        Aircraft(registration: "ZNM", type: "B789"),
        Aircraft(registration: "ZNN", type: "B789"),
        
        // A330-200
        Aircraft(registration: "EBA", type: "A332"),
        Aircraft(registration: "EBB", type: "A332"),
        Aircraft(registration: "EBC", type: "A332"),
        Aircraft(registration: "EBD", type: "A332"),
        Aircraft(registration: "EBE", type: "A332"),
        Aircraft(registration: "EBF", type: "A332"),
        Aircraft(registration: "EBG", type: "A332"),
        Aircraft(registration: "EBH", type: "A332"),
        Aircraft(registration: "EBI", type: "A332"),
        Aircraft(registration: "EBJ", type: "A332"),
        Aircraft(registration: "EBK", type: "A332"),
        Aircraft(registration: "EBL", type: "A332"),
        Aircraft(registration: "EBM", type: "A332"),
        Aircraft(registration: "EBN", type: "A332"),
        Aircraft(registration: "EBO", type: "A332"),
        Aircraft(registration: "EBP", type: "A332"),
        Aircraft(registration: "EBQ", type: "A332"),
        Aircraft(registration: "EBR", type: "A332"),
        Aircraft(registration: "EBS", type: "A332"),
        Aircraft(registration: "EBT", type: "A332"),
        Aircraft(registration: "EBU", type: "A332"),
        Aircraft(registration: "EBV", type: "A332"),
    
        // A330-300
        Aircraft(registration: "QPA", type: "A333"),
        Aircraft(registration: "QPB", type: "A333"),
        Aircraft(registration: "QPC", type: "A333"),
        Aircraft(registration: "QPD", type: "A333"),
        Aircraft(registration: "QPE", type: "A333"),
        Aircraft(registration: "QPF", type: "A333"),
        Aircraft(registration: "QPG", type: "A333"),
        Aircraft(registration: "QPH", type: "A333"),
        Aircraft(registration: "QPI", type: "A333"),
        Aircraft(registration: "QPJ", type: "A333"),
        Aircraft(registration: "QPK", type: "A333"),
        Aircraft(registration: "QPL", type: "A333"),
        
        // A380-800
        Aircraft(registration: "OQA", type: "A388"),
        Aircraft(registration: "OQB", type: "A388"),
        Aircraft(registration: "OQC", type: "A388"),
        Aircraft(registration: "OQD", type: "A388"),
        Aircraft(registration: "OQE", type: "A388"),
        Aircraft(registration: "OQF", type: "A388"),
        Aircraft(registration: "OQG", type: "A388"),
        Aircraft(registration: "OQH", type: "A388"),
        Aircraft(registration: "OQI", type: "A388"),
        Aircraft(registration: "OQJ", type: "A388"),
        Aircraft(registration: "OQK", type: "A388"),
        Aircraft(registration: "OQL", type: "A388"),
    
        // A350 TBA
    
    ]
    
    // MARK: - Fleet Collections
    public static let availableFleets: [Fleet] = [
        Fleet(name: "B737", types: ["B731", "B732", "B733", "B734", "B735", "B736", "B737", "B738", "B739", "B37M", "B38M", "B39M", "B3XM"], prefix: "B73"),
        Fleet(name: "A320", types: ["A321", "A21N","A320", "A20N", "A318", "A319", "A19N"], prefix: "A32"),
        Fleet(name: "A330", types: ["A330", "A332", "A333", "A338", "A339"], prefix: "A330"),
        Fleet(name: "B787", types: ["B787", "B788", "B789", "B78X"], prefix: "B78"),
        Fleet(name: "A380", types: ["A388", "A380"], prefix: "A38"),
        Fleet(name: "B747", types: ["B741", "B742", "B743", "B744", "B74S", "B747", "B748"], prefix: "B74"),
        Fleet(name: "B767", types: ["B762", "B763", "B764", "B767"], prefix: "B767"),
        Fleet(name: "DHC-8", types: ["DHC-8", "DHC8", "DH8A", "DH8B", "DH8C", "DH8D"], prefix: "DH8"),
        //Fleet(name: "A350", types: ["A35K"]),
    ]
    
    // MARK: - Convenience Methods
    
    /// Get all aircraft from the fleet
    public static func getAllAircraft() -> [Aircraft] {
        return qantasFleet.sorted { $0.registration < $1.registration }
    }
    
    /// Get aircraft by registration (without VH- prefix)
    public static func getAircraft(byRegistration registration: String) -> Aircraft? {
        let cleanReg = registration.replacingOccurrences(of: "VH-", with: "")
        return qantasFleet.first { $0.registration == cleanReg }
    }
    
    /// Get aircraft type by registration
    public static func getAircraftType(byRegistration registration: String) -> String {
        return getAircraft(byRegistration: registration)?.type ?? "" // Default fallback
    }
    
    /// Get all unique aircraft types
    public static func getAllAircraftTypes() -> [String] {
        return Array(Set(qantasFleet.map { $0.type })).sorted()
    }
    
    /// Get aircraft by type
    public static func getAircraft(byType type: String) -> [Aircraft] {
        return qantasFleet.filter { $0.type == type }.sorted { $0.registration < $1.registration }
    }

    // MARK: - Database Operations

    /// Save a custom aircraft to the database
    public func saveAircraft(_ aircraft: Aircraft) -> Bool {
        let entity = AircraftEntity(context: viewContext)
        entity.id = aircraft.id
        entity.registration = aircraft.registration
        entity.type = aircraft.type
        entity.fullRegistration = aircraft.fullRegistration
        entity.createdAt = Date()

        do {
            try viewContext.save()
//            print("Aircraft saved successfully: \(aircraft.registration)")
            objectWillChange.send()
            return true
        } catch {
            print("Error saving aircraft: \(error.localizedDescription)")
            return false
        }
    }

    /// Fetch all custom aircraft from database
    public func fetchCustomAircraft() -> [Aircraft] {
        let request: NSFetchRequest<AircraftEntity> = AircraftEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AircraftEntity.registration, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            return entities.compactMap { entity in
                guard let registration = entity.registration,
                      let type = entity.type else {
                    return nil
                }
                // Use fullRegistration (e.g. "VH-OGF") so the VH- prefix is correctly
                // recognised by customRegistration init, producing matching id/fullRegistration
                // with the static fleet and allowing Set dedup to eliminate duplicates.
                let reg = entity.fullRegistration ?? registration
                return Aircraft(customRegistration: reg, type: type)
            }
        } catch {
            print("Error fetching custom aircraft: \(error.localizedDescription)")
            return []
        }
    }

    /// Delete a custom aircraft from the database
    public func deleteAircraft(_ aircraft: Aircraft) -> Bool {
        let request: NSFetchRequest<AircraftEntity> = AircraftEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", aircraft.id)
        request.fetchLimit = 1

        do {
            let entities = try viewContext.fetch(request)
            guard let entity = entities.first else {
                print("Aircraft not found for deletion: \(aircraft.id)")
                return false
            }

            viewContext.delete(entity)
            try viewContext.save()
//            print("Aircraft deleted successfully: \(aircraft.registration)")
            objectWillChange.send()
            return true
        } catch {
            print("Error deleting aircraft: \(error.localizedDescription)")
            return false
        }
    }

    /// Check if an aircraft is a custom (deletable) aircraft
    public func isCustomAircraft(_ aircraft: Aircraft) -> Bool {
        let request: NSFetchRequest<AircraftEntity> = AircraftEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", aircraft.id)
        request.fetchLimit = 1
        return (try? viewContext.count(for: request)) ?? 0 > 0
    }

    /// Returns the fleet/family name for a given aircraft type code, or nil if unknown.
    /// e.g. "A332" → "A330", "B744" → "B747", "B772" → nil
    public static func familyName(for type: String) -> String? {
        availableFleets.first { $0.typeMatches(type) }?.name
    }

    /// Get all aircraft (static + custom)
    public func getAllAircraftCombined() -> [Aircraft] {
        let staticAircraft = AircraftFleetService.qantasFleet
        let customAircraft = fetchCustomAircraft()
        let combined = staticAircraft + customAircraft
        return Array(Set(combined)).sorted { $0.registration < $1.registration }
    }

    /// Get available fleets with custom aircraft included
    public func getAvailableFleetsWithCustom() -> [Fleet] {
        let allAircraft = getAllAircraftCombined()

        // Get all unique aircraft types
        let allTypes = Set(allAircraft.map { $0.type })

        // Create a fleet for each type with proper grouping
        var fleets: [Fleet] = []
        var processedTypes: Set<String> = []

        for type in allTypes.sorted() {
            guard !processedTypes.contains(type) else { continue }

            let matchedFleet = AircraftFleetService.availableFleets.first { $0.typeMatches(type) }
            let fleetName = matchedFleet?.name ?? type
            let typesToInclude = matchedFleet?.types ?? [type]

            let aircraftOfType = allAircraft.filter { typesToInclude.contains($0.type) }
            if !aircraftOfType.isEmpty {
                fleets.append(Fleet(name: fleetName, aircraft: aircraftOfType))
                processedTypes.formUnion(typesToInclude)
            }
        }

        // Merge any fleets with duplicate names (e.g. custom aircraft typed "A380" alongside static "A388")
        var merged: [String: Fleet] = [:]
        for fleet in fleets {
            if let existing = merged[fleet.id] {
                merged[fleet.id] = Fleet(name: existing.name, aircraft: existing.aircraft + fleet.aircraft)
            } else {
                merged[fleet.id] = fleet
            }
        }
        return merged.values.sorted { $0.name < $1.name }
    }
}
