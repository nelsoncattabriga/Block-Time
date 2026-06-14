//
//  OnboardingFlowView.swift
//  Block-Time
//
//  
//

import SwiftUI
import BlockTimeKit

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var frmsViewModel: FRMSViewModel
    @StateObject private var userDefaultsService = UserDefaultsService()

    @State private var currentStep = 0

    private let steps = ["Crew Settings", "Flight Information", "FRMS"]

    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        withAnimation {
                            if currentStep > 0 {
                                currentStep -= 1
                            }
                        }
                    }
                    .disabled(currentStep == 0)
                }

                ToolbarItem(placement: .topBarTrailing) {
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

#Preview {
    OnboardingFlowView(
        viewModel: FlightTimeExtractorViewModel(),
        frmsViewModel: FRMSViewModel()
    )
    .environment(ThemeService.shared)
}
