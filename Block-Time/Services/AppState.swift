//
//  AppState.swift
//  Block-Time
//
//  Created by Claude on 2026-01-25.
//

import Foundation
import SwiftUI

/// Global app state for coordinating between Block_TimeApp and MainTabView
@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    /// Tracks if a file is currently being opened/imported
    var isHandlingFileImport = false

    private init() {}
}
