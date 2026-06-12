//
//  CloudKitErrorHelper.swift
//  BlockTimeKit
//

import Foundation
import CloudKit

public enum CloudKitErrorHelper {

    public static func userFriendlyMessage(for error: Error) -> (message: String, suggestion: String, isRetryable: Bool) {
        let nsError = error as NSError

        guard nsError.domain == CKError.errorDomain,
              let ckError = error as? CKError else {
            return (
                message: "Sync Error",
                suggestion: nsError.localizedDescription,
                isRetryable: false
            )
        }

        switch ckError.code {
        case .notAuthenticated:
            return ("Not Signed Into iCloud", "Please sign in to iCloud in Settings to enable sync.", false)
        case .permissionFailure:
            return ("iCloud Permission Denied", "Please grant iCloud permission in Settings.", false)
        case .accountTemporarilyUnavailable:
            return ("iCloud Account Temporarily Unavailable", "Please try again in a few moments.", true)
        case .networkUnavailable:
            return ("No Internet Connection", "Please check your internet connection and try again.", true)
        case .networkFailure:
            return ("Network Connection Failed", "Unable to connect to iCloud. Please check your connection.", true)
        case .requestRateLimited:
            return ("Too Many Requests", "iCloud will automatically retry in a moment.", true)
        case .quotaExceeded:
            return ("iCloud Storage Full", "Your iCloud storage is full.", false)
        case .limitExceeded:
            return ("Operation Limit Exceeded", "The sync will continue automatically in batches.", true)
        case .serviceUnavailable:
            return ("iCloud Service Unavailable", "iCloud services are down.", true)
        case .zoneBusy:
            return ("iCloud Server Busy", "iCloud is experiencing high load.", true)
        case .internalError:
            return ("iCloud Internal Error", "An unexpected error occurred with iCloud.", true)
        case .serverResponseLost:
            return ("Server Response Lost", "Connection to iCloud was interrupted.", true)
        case .serverRecordChanged:
            return ("Data Conflict Detected", "The most recent changes were kept.", false)
        case .unknownItem:
            return ("Record Not Found", "The data may have been deleted on another device.", false)
        case .zoneNotFound:
            return ("Sync Zone Not Found", "Your iCloud sync zone needs to be recreated.", true)
        case .assetFileNotFound:
            return ("File Not Found", "A synced file will be re-downloaded.", true)
        case .assetFileModified:
            return ("File Was Modified", "The sync will retry with the latest version.", true)
        case .partialFailure:
            return ("Partial Sync Failure", "Some items failed to sync.", true)
        case .batchRequestFailed:
            return ("Batch Operation Failed", "Multiple sync operations failed.", true)
        case .constraintViolation:
            return ("Data Constraint Violation", "Some data couldn't be synced.", false)
        case .incompatibleVersion:
            return ("Incompatible App Version", "Please update the app on all your devices.", false)
        case .operationCancelled:
            return ("Sync Cancelled", "The sync operation was cancelled.", true)
        case .invalidArguments:
            return ("Invalid Sync Request", "The sync request was malformed.", false)
        case .resultsTruncated:
            return ("Results Truncated", "Sync will continue in batches.", true)
        case .referenceViolation:
            return ("Data Reference Error", "Sync will attempt to resolve this automatically.", true)
        case .changeTokenExpired:
            return ("Sync Token Expired", "A full sync will be performed automatically.", true)
        case .managedAccountRestricted:
            return ("Managed Account Restricted", "Contact your administrator.", false)
        case .participantMayNeedVerification:
            return ("Verification Required", "You may need to verify your iCloud account.", false)
        case .badContainer:
            return ("Invalid iCloud Container", "Please contact support.", false)
        case .badDatabase:
            return ("Invalid Database", "Please contact support.", false)
        case .missingEntitlement:
            return ("Missing iCloud Entitlement", "Please contact support.", false)
        default:
            return ("Sync Error", ckError.localizedDescription, true)
        }
    }

    public static func retryDelay(for error: Error) -> TimeInterval? {
        guard let ckError = error as? CKError else { return nil }
        return ckError.retryAfterSeconds
    }

    public static func shouldRetryAutomatically(for error: Error) -> Bool {
        let (_, _, isRetryable) = userFriendlyMessage(for: error)
        return isRetryable
    }
}
