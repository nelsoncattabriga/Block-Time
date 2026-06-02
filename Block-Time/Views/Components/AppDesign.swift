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
    static let insColor     = Color.pink
}

// MARK: - Card ViewModifier

struct AppCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(color: AppColors.cardShadow, radius: 8, x: 0, y: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

// MARK: - Card Filter Chip

/// Tappable badge used as a Menu label for card filter controls.
/// Wrap in a Menu and apply .tint(.primary) to the containing HStack.
struct CardFilterChip: View {
    let title: String

    var body: some View {
        Text(title)
            .iPadScaledFont(.caption2, phoneFont: .footnote)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Card Header

struct CardHeader<Trailing: View>: View {
    let title: String
    let icon: String
    var iconColor: Color = .secondary
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            trailing()
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(title: String, icon: String, iconColor: Color = .secondary) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = { EmptyView() }
    }
}
