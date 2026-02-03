//
//  OnboardingWelcomeView.swift
//  Block-Time
//
//  Created by Nelson on 2026-01-25.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    var onImportFromLogger: () -> Void
    var onSetupManually: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .padding(.top, 40)

                        VStack(spacing: 8) {
                            Text("Welcome to Block-Time")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

//                            Text("Get started by migrating your data or setting up manually")
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
//                                .multilineTextAlignment(.center)
//                                .padding(.horizontal)
                        }
                    }

                    // Options Section
                    VStack(spacing: 20) {
//                        // Import Option Card
//                        Button(action: {
//                            onImportFromLogger()
//                        }) {
//                            VStack(spacing: 16) {
//                                HStack {
//                                    Image(systemName: "arrow.down.doc.fill")
//                                        .font(.system(size: 40))
//                                        .foregroundColor(.orange)
//                                    Spacer()
//                                }
//
//                                VStack(alignment: .leading, spacing: 8) {
//                                    Text("Migrate from Logger")
//                                        .font(.title3)
//                                        .fontWeight(.semibold)
//                                        .foregroundColor(.primary)
//
//                                    Text("Import your flights, settings, and aircraft from Logger")
//                                        .font(.body)
//                                        .foregroundColor(.secondary)
//                                        .fixedSize(horizontal: false, vertical: true)
//                                }
//
//                            }
//                            .padding(20)
//                            .background(Color.orange.opacity(0.1))
//                            .cornerRadius(16)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 16)
//                                    .stroke(Color.orange.opacity(0.3), lineWidth: 2)
//                            )
//                        }
//                        .buttonStyle(PlainButtonStyle())

                        // Manual Setup Option Card
                        Button(action: {
                            onSetupManually()
                        }) {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
//                                    Spacer()
                                    
                                
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Initial Setup")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)

                                        Text("Configure Block-Time Settings")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                }
//
//                                VStack(alignment: .leading, spacing: 8) {
//                                    Text("Initial Setup")
//                                        .font(.title3)
//                                        .fontWeight(.semibold)
//                                        .foregroundColor(.primary)
//
//                                    Text("Configure Block-Time Settings")
//                                        .font(.body)
//                                        .foregroundColor(.secondary)
//                                        .fixedSize(horizontal: false, vertical: true)
//                                }
                            }
                            .padding(20)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWelcomeView(
            onImportFromLogger: { print("Import from Logger") },
            onSetupManually: { print("Set up manually") }
        )
        .preferredColorScheme(.light)

        OnboardingWelcomeView(
            onImportFromLogger: { print("Import from Logger") },
            onSetupManually: { print("Set up manually") }
        )
        .preferredColorScheme(.dark)
    }
}
#endif
