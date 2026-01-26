//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//


import Foundation
import UIKit
import Photos
import Combine

// MARK: - Photo Saving Service (iOS 14+ Compatible)
class PhotoSavingService: ObservableObject {
    
    enum PhotoSavingError: LocalizedError {
        case noPermission
        case limitedAccess
        case savingFailed(String)
        case invalidImage
        
        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "Permission to access photo library is required to save photos."
            case .limitedAccess:
                return "Limited photo access detected. Please grant full photo library access to save photos automatically."
            case .savingFailed(let message):
                return "Failed to save photo: \(message)"
            case .invalidImage:
                return "Invalid image provided for saving."
            }
        }
    }
    
    // MARK: - Permission Management
    
    /// Check current photo library permission status for adding photos
    func checkPermissionStatus() -> PHAuthorizationStatus {
        // Use .addOnly for write-only access
        return PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    
    /// Request permission to save photos to library
    func requestPermission() async -> PHAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Check if we have permission to save photos (handles limited access)
    func hasPermissionToSave() -> Bool {
        let status = checkPermissionStatus()
        return status == .authorized || status == .limited
    }
    
    /// Check if we have full permission (not limited)
    func hasFullPermission() -> Bool {
        let status = checkPermissionStatus()
        return status == .authorized
    }
    
    /// Check if we have limited permission only
    func hasLimitedPermission() -> Bool {
        let status = checkPermissionStatus()
        return status == .limited
    }
    
    // MARK: - Photo Saving
    
    /// Save image to photo library with proper limited access handling
    /// - Parameter image: The UIImage to save
    /// - Returns: Result indicating success or failure
    func saveImageToPhotoLibrary(_ image: UIImage) async -> Result<Void, PhotoSavingError> {
        guard image.cgImage != nil else {
            return .failure(.invalidImage)
        }
        
        // Check permission first
        let permissionStatus = checkPermissionStatus()
        
        switch permissionStatus {
        case .authorized:
            // Full access - proceed with saving
            break
        case .limited:
            // Limited access - photos can still be saved, but user should be informed
            // For .addOnly permission, limited access should still allow saving new photos
            break
        case .denied, .restricted:
            return .failure(.noPermission)
        case .notDetermined:
            // Request permission
            let newStatus = await requestPermission()
            if newStatus == .denied || newStatus == .restricted {
                return .failure(.noPermission)
            }
            // Continue with authorized or limited access
        @unknown default:
            return .failure(.noPermission)
        }
        
        // Save the image
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    print("Photo saved successfully to photo library")
                    continuation.resume(returning: .success(()))
                } else {
                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                    print("Failed to save photo: \(errorMessage)")
                    continuation.resume(returning: .failure(.savingFailed(errorMessage)))
                }
            }
        }
    }
    
    /// Save image with metadata (enhanced version)
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - metadata: Optional metadata dictionary
    /// - Returns: Result indicating success or failure
    func saveImageWithMetadata(_ image: UIImage, metadata: [String: Any]? = nil) async -> Result<Void, PhotoSavingError> {
        guard image.cgImage != nil else {
            return .failure(.invalidImage)
        }
        
        // Check permission
        let permissionStatus = checkPermissionStatus()
        
        switch permissionStatus {
        case .authorized, .limited:
            // Both authorized and limited can save new photos
            break
        case .denied, .restricted:
            return .failure(.noPermission)
        case .notDetermined:
            let newStatus = await requestPermission()
            if newStatus == .denied || newStatus == .restricted {
                return .failure(.noPermission)
            }
        @unknown default:
            return .failure(.noPermission)
        }
        
        // Save with metadata
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                
                // Add metadata if provided
                if let metadata = metadata {
                    if let _ = metadata["flightNumber"] as? String,
                       let date = metadata["date"] as? String {
                        request.creationDate = self.dateFromString(date)
                    }
                }
            }) { success, error in
                if success {
                    print("Photo with metadata saved successfully")
                    continuation.resume(returning: .success(()))
                } else {
                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                    print("Failed to save photo with metadata: \(errorMessage)")
                    continuation.resume(returning: .failure(.savingFailed(errorMessage)))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: dateString)
    }
    
    /// Get user-friendly permission status description
    func permissionStatusDescription() -> String {
        let status = checkPermissionStatus()
        switch status {
        case .authorized:
            return "Full access granted"
        case .limited:
            return "Limited access granted"
        case .denied:
            return "Access denied"
        case .restricted:
            return "Access restricted"
        case .notDetermined:
            return "Permission not requested"
        @unknown default:
            return "Unknown status"
        }
    }
    
    /// Check if user needs to manually enable permission in Settings
    func shouldShowSettingsAlert() -> Bool {
        let status = checkPermissionStatus()
        return status == .denied || status == .restricted
    }
    
    /// Check if user should be informed about limited access
    func shouldShowLimitedAccessInfo() -> Bool {
        return hasLimitedPermission()
    }
    
    // MARK: - Additional Helper Methods
    
    /// Request permission proactively (for UI that wants to check before attempting save)
    func requestPermissionIfNeeded() async -> Bool {
        let currentStatus = checkPermissionStatus()
        
        switch currentStatus {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await requestPermission()
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Check if the permission dialog will be shown (useful for UX)
    func willShowPermissionDialog() -> Bool {
        return checkPermissionStatus() == .notDetermined
    }
    
    /// Get detailed permission info for debugging
    func getDetailedPermissionInfo() -> String {
        let status = checkPermissionStatus()
        return """
        Permission Status: \(status.rawValue)
        Description: \(permissionStatusDescription())
        Can Save: \(hasPermissionToSave())
        Full Permission: \(hasFullPermission())
        Limited Permission: \(hasLimitedPermission())
        Should Show Settings: \(shouldShowSettingsAlert())
        """
    }
}
