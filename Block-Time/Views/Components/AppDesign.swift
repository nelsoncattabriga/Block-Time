//
//  AppDesign.swift
//  Block-Time
//
//  Shared design tokens and card styling for FRMS and Logbook screens.
//

import SwiftUI

// MARK: - Color Tokens

enum AppColors {
    static let accentOrange = Color.orange.opacity(0.85)
    static let accentBlue   = Color.blue.opacity(0.8)
    static let cardShadow   = Color.black.opacity(0.06)
}

// MARK: - Card ViewModifier

struct AppCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: AppColors.cardShadow, radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func appCardStyle() -> some View {
        modifier(AppCardStyle())
    }
}
