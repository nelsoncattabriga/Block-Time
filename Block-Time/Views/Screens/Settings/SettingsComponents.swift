// Views/Screens/Settings/SettingsComponents.swift
import SwiftUI
import BlockTimeKit

// MARK: - Modern Toggle Row

struct ModernToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: color))
                .scaleEffect(0.9)
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Modern Text Field Row

struct ModernTextFieldRow: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.subheadline)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Share Sheet Wrapper

struct ShareSheetWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let items: [Any]

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

            // Configure for iPad (popover)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = uiViewController.view
                popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX,
                                           y: uiViewController.view.bounds.midY,
                                           width: 0,
                                           height: 0)
                popover.permittedArrowDirections = []
            }

            activityVC.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                var topController = rootVC
                while let presented = topController.presentedViewController {
                    topController = presented
                }

                if topController.presentedViewController == nil {
                    topController.present(activityVC, animated: true)
                }
            }
        }
    }
}

// MARK: - Photo Backup Card

struct ModernPhotoBackupCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("PHOTO BACKUP")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            ModernToggleRow(
                title: "Save ACARS to Photos",
                subtitle: "Backup photos",
                isOn: Binding(
                    get: { viewModel.savePhotosToLibrary },
                    set: { viewModel.updateSavePhotosToLibrary($0) }
                ),
                color: .blue,
                icon: "photo.on.rectangle.angled"
            )
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}
