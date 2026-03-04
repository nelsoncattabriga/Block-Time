import SwiftUI

// MARK: - Modern Action Buttons Card
struct ModernActionButtonsCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Binding var showingDeleteAlert: Bool
    @Binding var showSuccessNotification: Bool
    @Binding var successMessage: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Check if we're in iPad split view mode
    private var isInSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.red)
                    .font(.title3)

                Text("Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                // Show different buttons based on editing mode
                if viewModel.isEditingMode {
                    // Update button for editing mode
                    ModernActionButton(
                        title: "Update Flight",
                        subtitle: "Save changes",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        isEnabled: viewModel.hasUnsavedChanges,
                        action: {
                            if viewModel.updateExistingFlight() {
                                HapticManager.shared.notification(.success)
                                // Show success notification
                                successMessage = "Flight Updated"
                                withAnimation {
                                    showSuccessNotification = true
                                }

                                Task { @MainActor in
                                    try await Task.sleep(for: .seconds(2.0))
                                    withAnimation {
                                        showSuccessNotification = false
                                    }
                                }

                                // Only exit editing mode and dismiss on iPhone
                                // On iPad split view, stay in edit mode to continue viewing/editing
                                if !isInSplitView {
                                    Task { @MainActor in
                                        try await Task.sleep(for: .seconds(0.5))
                                        viewModel.exitEditingMode()
                                        dismiss()
                                    }
                                }
                            }
                        }
                    )

                    // Delete button
                    ModernActionButton(
                        title: "Delete Flight",
                        subtitle: "Remove from logbook",
                        icon: "trash.fill",
                        color: .red,
                        isEnabled: true,
                        action: {
                            HapticManager.shared.notification(.warning)
                            print("🗑️ Delete button tapped")
                            showingDeleteAlert = true
                            print("🗑️ showingDeleteAlert set to: \(showingDeleteAlert)")
                        }
                    )

                    // Cancel button - only show on iPhone (not in iPad split view)
                    if !isInSplitView {
                        ModernActionButton(
                            title: "Cancel",
                            subtitle: "Discard changes",
                            icon: "xmark.circle",
                            color: .gray,
                            isEnabled: true,
                            action: {
                                viewModel.exitEditingMode()
                                dismiss()
                            }
                        )
                    }
                } else {
                    // Add to internal logbook button
                    ModernActionButton(
                        title: "Add to Logbook",
                        subtitle: "Save to internal logbook",
                        icon: "plus.circle.fill",
                        color: .green,
                        isEnabled: viewModel.canSendToLogTen,
                        action: {
                            HapticManager.shared.notification(.success)
                            viewModel.addToInternalLogbook()
                            successMessage = "Flight Added"
                            withAnimation {
                                showSuccessNotification = true
                            }
                            if isInSplitView {
                                // iPad split view: clear form ready for next entry
                                Task { @MainActor in
                                    try await Task.sleep(for: .seconds(0.5))
                                    viewModel.resetAllFields()
                                }
                                Task { @MainActor in
                                    try await Task.sleep(for: .seconds(2.0))
                                    withAnimation {
                                        showSuccessNotification = false
                                    }
                                }
                            } else {
                                // iPhone: return to FlightsView after brief success display
                                Task { @MainActor in
                                    try await Task.sleep(for: .seconds(1.0))
                                    dismiss()
                                }
                            }
                        }
                    )

                    // Clear button
                    ModernActionButton(
                        title: "Clear All Entries",
                        subtitle: "Clear form",
                        icon: "arrow.clockwise",
                        color: .red,
                        isEnabled: true,
                        action: {
                            HapticManager.shared.notification(.warning)
                            viewModel.resetAllFields()
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}
