import SwiftUI

// MARK: - Individual Stat Card Template
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    var fraction: Double? = nil  // 0–1, drives progress bar when provided

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: title, icon: icon, iconColor: color)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .iPadScaledFont(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)

                if let fraction {
                    ProgressView(value: min(max(fraction, 0), 1))
                        .tint(color)
                        .frame(height: 6)
                } else {
                    Spacer()
                        .frame(height: 6)
                }

                Text(subtitle)
                    .iPadScaledFont(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .appCardStyle()
    }
}
