//
//  CardHeader.swift
//  Block-Time
//
//  Reusable card header view with optional trailing content.
//

import SwiftUI

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
                .bold()
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
