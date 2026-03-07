import SwiftUI
import PhotosUI

// MARK: - Modern Photo Capture Card
struct ModernPhotoCaptureCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var fleetType: String = "B737"

    private var cardTitle: String {
        switch fleetType {
        case "B787": return "787 Capture"
        case "A330": return "A330 Capture"
        default: return "737 Capture"
        }
    }

    private var cameraButtonTitle: String {
        switch fleetType {
        case "B787": return "PRINTER"
        case "A330": return "ACARS or PRINTER"
        default:     return "ACARS"
        }
    }

    private var cameraButtonSubtitle: String {
        switch fleetType {
        case "B787": return "ACARS Printout"
        case "A330": return "CURRENT-FLT Screen or Printout"
        default:     return "CURRENT-FLT Screen"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.green)
                    .font(.title3)

                Text(cardTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            ModernButton(
                title: cameraButtonTitle,
                subtitle: cameraButtonSubtitle,
                icon: "camera",
                color: .blue,
                action: viewModel.showCamera
            )

            PhotosPicker(selection: $viewModel.selectedPhotoItem) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.subheadline)
                    Text("Photos Library")
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Modern Component Helpers

struct ModernButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ModernButtonContent(title: title, subtitle: subtitle, icon: icon, color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernButtonContent: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ModernActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isEnabled ? .white : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isEnabled ? .white : .gray)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isEnabled ? .white.opacity(0.8) : .gray)
                }

                Spacer()
            }
            .padding(16)
            .background(isEnabled ? color.opacity(0.8) : Color.gray.opacity(0.3))
            .cornerRadius(10)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}
