//
//  OnboardingFlowView.swift
//  Block-Time
//
//  Created by Claude on 2026-01-25.
//

import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @ObservedObject var frmsViewModel: FRMSViewModel
    @StateObject private var userDefaultsService = UserDefaultsService()

    @State private var currentStep = 0

    private let steps = ["Crew Settings", "Flight Information", "FRMS"]

    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case 0:
                    PersonalCrewSettingsView(viewModel: viewModel)
                case 1:
                    FlightInformationSettingsView(viewModel: viewModel)
                case 2:
                    FRMSSettingsDetailView(viewModel: viewModel, frmsViewModel: frmsViewModel)
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Step \(currentStep + 1) of \(steps.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        withAnimation {
                            if currentStep > 0 {
                                currentStep -= 1
                            }
                        }
                    }
                    .disabled(currentStep == 0)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(currentStep == steps.count - 1 ? "Complete Setup" : "Next") {
                        withAnimation {
                            if currentStep < steps.count - 1 {
                                currentStep += 1
                            } else {
                                // Mark onboarding complete
                                userDefaultsService.onboardingCompleted = true
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView(
            viewModel: FlightTimeExtractorViewModel(),
            frmsViewModel: FRMSViewModel()
        )
    }
}
#endif
