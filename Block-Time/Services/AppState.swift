//
//  AppState.swift
//  Block-Time
//
//  Created by Claude on 2026-01-25.
//

import Foundation
import SwiftUI
import Combine

/// Global app state for coordinating between Block_TimeApp and MainTabView
class AppState: ObservableObject {
    static let shared = AppState()

    /// Tracks if a file is currently being opened/imported
    @Published var isHandlingFileImport = false

    private init() {}
}
