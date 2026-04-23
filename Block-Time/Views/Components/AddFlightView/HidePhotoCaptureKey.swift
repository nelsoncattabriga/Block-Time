//
//  HidePhotoCaptureKey.swift
//  Block-Time
//

import SwiftUI

private struct HidePhotoCaptureKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hidePhotoCapture: Bool {
        get { self[HidePhotoCaptureKey.self] }
        set { self[HidePhotoCaptureKey.self] = newValue }
    }
}
