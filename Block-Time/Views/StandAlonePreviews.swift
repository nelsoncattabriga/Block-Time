import SwiftUI

// MARK: - Flight List Banners

private struct FlightListBannersPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            // filterStatusBanner (import variant — orange)
            HStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                Text("Showing imported flights")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                Spacer()
                Text("Clear")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            // importDeleteBanner (red)
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Text("Remove this import")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("Delete")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            // undoBar (orange)
            HStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("3 changes to undo")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("History clears when app closes")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Undo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .padding(.top, 16)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Flight List Banners") {
    FlightListBannersPreview()
}
