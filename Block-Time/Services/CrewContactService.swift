//
//  CrewContactService.swift
//  Block-Time
//
//  @Observable @MainActor singleton for crew contact CRUD via Core Data.
//

import Foundation
@preconcurrency import CoreData
import Observation

// MARK: - CrewContactBackup

/// Codable representation used for backup serialisation only.
struct CrewContactBackup: Codable {
    let id: String      // UUID string
    let name: String
    let notes: String   // empty string if entity.notes is nil
}

// MARK: - CrewContactService

@Observable @MainActor
final class CrewContactService {

    static let shared = CrewContactService()

    private init() {}

    // MARK: - Public API

    /// Returns all crew contacts sorted by name ascending.
    func fetchAll() -> [CrewContactEntity] {
        let context = FlightDatabaseService.shared.viewContext
        let request: NSFetchRequest<CrewContactEntity> = CrewContactEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return context.performAndWait { (try? context.fetch(request)) ?? [] }
    }

    /// Finds a contact by name (case-insensitive). Returns nil if not found.
    func fetchContact(name: String) -> CrewContactEntity? {
        let context = FlightDatabaseService.shared.viewContext
        let request: NSFetchRequest<CrewContactEntity> = CrewContactEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1
        return context.performAndWait { (try? context.fetch(request))?.first }
    }

    /// Creates or updates a contact. If a contact with this name exists, updates notes.
    /// No-op if name is empty or whitespace-only.
    func upsert(name: String, notes: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        FlightDatabaseService.shared.viewContext.performAndWait {
            let context = FlightDatabaseService.shared.viewContext
            let request: NSFetchRequest<CrewContactEntity> = CrewContactEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", name)
            request.fetchLimit = 1

            let existing = (try? context.fetch(request))?.first
            if let contact = existing {
                contact.notes = notes
                contact.modifiedAt = Date.now
            } else {
                let contact = CrewContactEntity(context: context)
                contact.id = UUID()
                contact.name = name
                contact.notes = notes
                contact.createdAt = Date.now
                contact.modifiedAt = Date.now
            }

            try? context.save()
        }
    }

    /// Deletes the contact with the given name. No-op if not found.
    func delete(name: String) {
        FlightDatabaseService.shared.viewContext.performAndWait {
            let context = FlightDatabaseService.shared.viewContext
            let request: NSFetchRequest<CrewContactEntity> = CrewContactEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", name)
            request.fetchLimit = 1

            guard let contact = (try? context.fetch(request))?.first else { return }
            context.delete(contact)
            try? context.save()
        }
    }

    /// Returns all contacts as a `CrewContactBackup` array for CSV export.
    /// Called on main thread before background dispatch in AutomaticBackupService.
    func fetchAllAsBackup() -> [CrewContactBackup] {
        fetchAll().map { contact in
            CrewContactBackup(
                id: contact.id?.uuidString ?? UUID().uuidString,
                name: contact.name ?? "",
                notes: contact.notes ?? ""
            )
        }
    }
}
