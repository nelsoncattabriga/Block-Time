import SwiftUI

// MARK: - Individual Stat Card Template
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {

                Text(title)
                    .iPadScaledFont(.headline)
                    .foregroundColor(.secondary)
                    .fontWeight(.bold)

                Spacer()

                Image(systemName: icon)
                    .foregroundColor(color)
                    .iPadScaledFont(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .iPadScaledFont(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // Spacer to match progress bar height in other cards
                Spacer()
                    .frame(height: 6)

                Text(subtitle)
                    .iPadScaledFont(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .appCardStyle()
    }
}
