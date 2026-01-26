//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//


import Foundation
import CoreData
import Combine

// MARK: - Aircraft Model
struct Aircraft: Codable, Identifiable, Hashable {
    let id: String
    let registration: String
    let type: String
    let fullRegistration: String
    
    init(registration: String, type: String) {
        self.id = registration // Use registration as ID for consistency
        self.registration = registration
        self.type = type
        self.fullRegistration = "VH-\(registration)"
    }
    
    func displayRegistration(showFullReg: Bool) -> String {
        return showFullReg ? fullRegistration : registration
    }
}

// MARK: - Fleet Selection
struct Fleet: Identifiable, Hashable {
    let id: String
    let name: String
    let aircraft: [Aircraft]
    
    init(name: String, aircraft: [Aircraft]) {
        self.id = name // Use name as ID for consistency
        self.name = name
        self.aircraft = aircraft
    }
}

// MARK: - Aircraft Fleet Service
class AircraftFleetService: ObservableObject {

    // MARK: - Singleton
    static let shared = AircraftFleetService()

    private var viewContext: NSManagedObjectContext {
        return FlightDatabaseService.shared.viewContext
    }

    // MARK: - Core Static Fleet Data
    // Note: Custome aircraft are stored in the core data AircraftEntity and are saved to icloud.
    // Static list just keeps things fast and efficient with no DB lookup required.
    
    static let qantasFleet: [Aircraft] = [
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
        
        // A321
        Aircraft(registration: "OGA", type: "A321"),
        Aircraft(registration: "OGB", type: "A321"),
        Aircraft(registration: "OGC", type: "A321"),
        Aircraft(registration: "OGD", type: "A321"),
        Aircraft(registration: "OGE", type: "A321"),
        Aircraft(registration: "OGF", type: "A321"),
        Aircraft(registration: "OGG", type: "A321"),
        
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
    static let availableFleets: [Fleet] = {
        //let b737Aircraft = qantasFleet.filter { $0.type == "B738" }
        
        return [
            Fleet(name: "All Aircraft", aircraft: qantasFleet),
            Fleet(name: "B737", aircraft: qantasFleet.filter { $0.type == "B738" }),
            Fleet(name: "A321", aircraft: qantasFleet.filter { $0.type == "A321" }),
            Fleet(name: "A330", aircraft: qantasFleet.filter { ["A332", "A333"].contains($0.type) }),
            Fleet(name: "B787", aircraft: qantasFleet.filter { $0.type == "B789" }),
            Fleet(name: "A380", aircraft: qantasFleet.filter { $0.type == "A388" }),
            //Fleet(name: "A350", aircraft: qantasFleet.filter { $0.type == "A35K" }),
            
        ]
    }()
    
    // MARK: - Convenience Methods
    
    /// Get all aircraft from the fleet
    static func getAllAircraft() -> [Aircraft] {
        return qantasFleet.sorted { $0.registration < $1.registration }
    }
    
    /// Get aircraft by registration (without VH- prefix)
    static func getAircraft(byRegistration registration: String) -> Aircraft? {
        let cleanReg = registration.replacingOccurrences(of: "VH-", with: "")
        return qantasFleet.first { $0.registration == cleanReg }
    }
    
    /// Get aircraft type by registration
    static func getAircraftType(byRegistration registration: String) -> String {
        return getAircraft(byRegistration: registration)?.type ?? "" // Default fallback
    }
    
    /// Get all unique aircraft types
    static func getAllAircraftTypes() -> [String] {
        return Array(Set(qantasFleet.map { $0.type })).sorted()
    }
    
    /// Get aircraft by type
    static func getAircraft(byType type: String) -> [Aircraft] {
        return qantasFleet.filter { $0.type == type }.sorted { $0.registration < $1.registration }
    }

    // MARK: - Database Operations

    /// Save a custom aircraft to the database
    func saveAircraft(_ aircraft: Aircraft) -> Bool {
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
            LogManager.shared.error("Error saving aircraft: \(error.localizedDescription)")
            return false
        }
    }

    /// Fetch all custom aircraft from database
    func fetchCustomAircraft() -> [Aircraft] {
        let request: NSFetchRequest<AircraftEntity> = AircraftEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AircraftEntity.registration, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            return entities.compactMap { entity in
                guard let registration = entity.registration,
                      let type = entity.type else {
                    return nil
                }
                return Aircraft(registration: registration, type: type)
            }
        } catch {
            LogManager.shared.error("Error fetching custom aircraft: \(error.localizedDescription)")
            return []
        }
    }

    /// Delete a custom aircraft from the database
    func deleteAircraft(_ aircraft: Aircraft) -> Bool {
        let request: NSFetchRequest<AircraftEntity> = AircraftEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", aircraft.id)
        request.fetchLimit = 1

        do {
            let entities = try viewContext.fetch(request)
            guard let entity = entities.first else {
                LogManager.shared.error("Aircraft not found for deletion: \(aircraft.id)")
                return false
            }

            viewContext.delete(entity)
            try viewContext.save()
//            LogManager.shared.info("Aircraft deleted successfully: \(aircraft.registration)")
            objectWillChange.send()
            return true
        } catch {
            LogManager.shared.error("Error deleting aircraft: \(error.localizedDescription)")
            return false
        }
    }

    /// Check if an aircraft is a custom (deletable) aircraft
    func isCustomAircraft(_ aircraft: Aircraft) -> Bool {
        let customAircraft = fetchCustomAircraft()
        return customAircraft.contains(where: { $0.id == aircraft.id })
    }

    /// Get all aircraft (static + custom)
    func getAllAircraftCombined() -> [Aircraft] {
        let staticAircraft = AircraftFleetService.qantasFleet
        let customAircraft = fetchCustomAircraft()
        let combined = staticAircraft + customAircraft
        return Array(Set(combined)).sorted { $0.registration < $1.registration }
    }

    /// Get available fleets with custom aircraft included
    func getAvailableFleetsWithCustom() -> [Fleet] {
        let allAircraft = getAllAircraftCombined()

        // Get all unique aircraft types
        let allTypes = Set(allAircraft.map { $0.type })

        // Create a fleet for each type with proper grouping
        var fleets: [Fleet] = [Fleet(name: "All Aircraft", aircraft: allAircraft)]
        var processedTypes: Set<String> = []

        for type in allTypes.sorted() {
            guard !processedTypes.contains(type) else { continue }

            // Map aircraft types to fleet names and group variants
            let (fleetName, typesToInclude): (String, [String]) = {
                switch type {
                case "B738":
                    return ("B737", ["B738"])
                case "A332", "A333":
                    return ("A330", ["A332", "A333"])
                case "B789":
                    return ("B787", ["B789"])
                case "A388":
                    return ("A380", ["A388"])
                default:
                    return (type, [type])
                }
            }()

            let aircraftOfType = allAircraft.filter { typesToInclude.contains($0.type) }
            if !aircraftOfType.isEmpty {
                fleets.append(Fleet(name: fleetName, aircraft: aircraftOfType))
                processedTypes.formUnion(typesToInclude)
            }
        }

        return fleets
    }
}
