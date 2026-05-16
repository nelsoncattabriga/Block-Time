//
//  MigrationError.swift
//  Block-Time
//
//  Error types for the Core Data → SwiftData migration service (FOUND-09).
//  Plan 01-04
//

import Foundation

/// Errors that can occur during the one-time Core Data → SwiftData migration.
enum MigrationError: Error, CustomStringConvertible {

    /// Row counts in Core Data and SwiftData do not match after write (D-08).
    /// `migrationComplete` flag is NOT set when this error is thrown.
    case rowCountMismatch(expected: Int, actual: Int)

    /// Failed to read records from the v1 Core Data store.
    case coreDataReadFailed(underlying: Error)

    /// Failed to write records to the SwiftData migration container.
    case swiftDataWriteFailed(underlying: Error)

    /// Failed to create the migration `ModelContainer`.
    case containerCreationFailed(underlying: Error)

    /// The App Group `group.com.thezoolab.blocktime` is not provisioned in entitlements.
    case appGroupNotProvisioned

    // MARK: - CustomStringConvertible

    var description: String {
        switch self {
        case .rowCountMismatch(let expected, let actual):
            return "Row count mismatch: expected \(expected), got \(actual). migrationComplete flag NOT set."
        case .coreDataReadFailed(let error):
            return "Core Data read failed: \(error.localizedDescription)"
        case .swiftDataWriteFailed(let error):
            return "SwiftData write failed: \(error.localizedDescription)"
        case .containerCreationFailed(let error):
            return "ModelContainer creation failed: \(error.localizedDescription)"
        case .appGroupNotProvisioned:
            return "App Group 'group.com.thezoolab.blocktime' is not provisioned. Check Block-Time.entitlements."
        }
    }
}
