//
//  CloudKitErrorHelper.swift
//  Block-Time
//
//  Created by Nelson on 18/10/2025.
//

import Foundation
import CloudKit

/// Helper to provide user-friendly error messages for CloudKit errors
enum CloudKitErrorHelper {

    /// Convert a CloudKit error to a user-friendly message with an actionable suggestion
    static func userFriendlyMessage(for error: Error) -> (message: String, suggestion: String, isRetryable: Bool) {
        let nsError = error as NSError

        // Check if it's a CloudKit error
        guard nsError.domain == CKError.errorDomain,
              let ckError = error as? CKError else {
            // Not a CloudKit error - return generic message
            return (
                message: "Sync Error",
                suggestion: nsError.localizedDescription,
                isRetryable: false
            )
        }

        // Handle CloudKit-specific errors with user-friendly messages
        switch ckError.code {

        // MARK: - Authentication & Account Errors
        case .notAuthenticated:
            return (
                message: "Not Signed Into iCloud",
                suggestion: "Please sign in to iCloud in Settings to enable sync.",
                isRetryable: false
            )

        case .permissionFailure:
            return (
                message: "iCloud Permission Denied",
                suggestion: "Please grant iCloud permission in Settings > iCloud > Saved to iCloud > Block-Time.",
                isRetryable: false
            )

        case .accountTemporarilyUnavailable:
            return (
                message: "iCloud Account Temporarily Unavailable",
                suggestion: "Your iCloud account is temporarily unavailable. Please try again in a few moments.",
                isRetryable: true
            )

        // MARK: - Network Errors
        case .networkUnavailable:
            return (
                message: "No Internet Connection",
                suggestion: "Please check your internet connection and try again.",
                isRetryable: true
            )

        case .networkFailure:
            return (
                message: "Network Connection Failed",
                suggestion: "Unable to connect to iCloud. Please check your connection and try again.",
                isRetryable: true
            )

        // MARK: - Rate Limiting & Quota
        case .requestRateLimited:
            return (
                message: "Too Many Requests",
                suggestion: "iCloud will automatically retry in a moment.",
                isRetryable: true
            )

        case .quotaExceeded:
            return (
                message: "iCloud Storage Full",
                suggestion: "Your iCloud storage is full.",
                isRetryable: false
            )

        case .limitExceeded:
            return (
                message: "Operation Limit Exceeded",
                suggestion: "The sync will continue automatically in batches.",
                isRetryable: true
            )

        // MARK: - Service & Server Errors
        case .serviceUnavailable:
            return (
                message: "iCloud Service Unavailable",
                suggestion: "iCloud services are down.",
                isRetryable: true
            )

        case .zoneBusy:
            return (
                message: "iCloud Server Busy",
                suggestion: "iCloud is experiencing high load.",
                isRetryable: true
            )

        case .internalError:
            return (
                message: "iCloud Internal Error",
                suggestion: "An unexpected error occurred with iCloud.",
                isRetryable: true
            )

        case .serverResponseLost:
            return (
                message: "Server Response Lost",
                suggestion: "Connection to iCloud was interrupted.",
                isRetryable: true
            )

        // MARK: - Data & Record Errors
        case .serverRecordChanged:
            return (
                message: "Data Conflict Detected",
                suggestion: "Your data conflicted with another device. The most recent changes were kept.",
                isRetryable: false
            )

        case .unknownItem:
            return (
                message: "Record Not Found",
                suggestion: "The requested data could not be found. It may have been deleted on another device.",
                isRetryable: false
            )

        case .zoneNotFound:
            return (
                message: "Sync Zone Not Found",
                suggestion: "Your iCloud sync zone needs to be recreated. This will happen automatically.",
                isRetryable: true
            )

        case .assetFileNotFound:
            return (
                message: "File Not Found",
                suggestion: "A synced file could not be found locally. It will be re-downloaded.",
                isRetryable: true
            )

        case .assetFileModified:
            return (
                message: "File Was Modified",
                suggestion: "A file was modified while uploading. The sync will retry with the latest version.",
                isRetryable: true
            )

        // MARK: - Partial Failure
        case .partialFailure:
            return (
                message: "Partial Sync Failure",
                suggestion: "Some items failed to sync.",
                isRetryable: true
            )

        // MARK: - Batch Errors
        case .batchRequestFailed:
            return (
                message: "Batch Operation Failed",
                suggestion: "Multiple sync operations failed. Check your connection and try again.",
                isRetryable: true
            )

        // MARK: - Constraint & Validation Errors
        case .constraintViolation:
            return (
                message: "Data Constraint Violation",
                suggestion: "Some data doesn't meet iCloud's requirements and couldn't be synced.",
                isRetryable: false
            )

        case .incompatibleVersion:
            return (
                message: "Incompatible App Version",
                suggestion: "Please update the app on all your devices to the same version.",
                isRetryable: false
            )

        // MARK: - Operation Errors
        case .operationCancelled:
            return (
                message: "Sync Cancelled",
                suggestion: "The sync operation was cancelled. It will retry automatically if needed.",
                isRetryable: true
            )

        case .invalidArguments:
            return (
                message: "Invalid Sync Request",
                suggestion: "The sync request was malformed. Please contact support if this persists.",
                isRetryable: false
            )

        case .resultsTruncated:
            return (
                message: "Results Truncated",
                suggestion: "Too many records to sync at once. Sync will continue in batches.",
                isRetryable: true
            )

        // MARK: - Reference Errors
        case .referenceViolation:
            return (
                message: "Data Reference Error",
                suggestion: "Some related data is missing. Sync will attempt to resolve this automatically.",
                isRetryable: true
            )

        // MARK: - Change Token Errors
        case .changeTokenExpired:
            return (
                message: "Sync Token Expired",
                suggestion: "Your sync token has expired. A full sync will be performed automatically.",
                isRetryable: true
            )

        // MARK: - Managed Account Restrictions
        case .managedAccountRestricted:
            return (
                message: "Managed Account Restricted",
                suggestion: "Your managed Apple ID has restrictions. Contact your administrator.",
                isRetryable: false
            )

        // MARK: - Participant Errors (Shared Zones)
        case .participantMayNeedVerification:
            return (
                message: "Verification Required",
                suggestion: "You may need to verify your iCloud account to continue syncing.",
                isRetryable: false
            )

        // MARK: - Bad Container/Database
        case .badContainer:
            return (
                message: "Invalid iCloud Container",
                suggestion: "The iCloud container configuration is invalid. Please contact support.",
                isRetryable: false
            )

        case .badDatabase:
            return (
                message: "Invalid Database",
                suggestion: "The iCloud database is misconfigured. Please contact support.",
                isRetryable: false
            )

        // MARK: - Mismatched Errors
        case .missingEntitlement:
            return (
                message: "Missing iCloud Entitlement",
                suggestion: "The app is missing required iCloud permissions. Please contact support.",
                isRetryable: false
            )

        // MARK: - Default/Unknown
        default:
            return (
                message: "Sync Error",
                suggestion: ckError.localizedDescription,
                isRetryable: true
            )
        }
    }

    /// Get the retry delay for a CloudKit error if available
    static func retryDelay(for error: Error) -> TimeInterval? {
        guard let ckError = error as? CKError else { return nil }
        return ckError.retryAfterSeconds
    }

    /// Check if an error should trigger an automatic retry
    static func shouldRetryAutomatically(for error: Error) -> Bool {
        let (_, _, isRetryable) = userFriendlyMessage(for: error)
        return isRetryable
    }
}
