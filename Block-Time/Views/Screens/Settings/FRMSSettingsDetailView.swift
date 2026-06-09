// Views/Screens/Settings/FRMSSettingsDetailView.swift
import SwiftUI

// MARK: - FRMS Settings Detail View

struct FRMSSettingsDetailView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var frmsViewModel: FRMSViewModel
    @Environment(ThemeService.self) private var themeService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ModernFRMSCard(viewModel: frmsViewModel)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("FRMS")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FRMS Card

struct ModernFRMSCard: View {
    @Bindable var viewModel: FRMSViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("FRMS CONFIGURATION")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                // Fleet Picker
                    HStack(spacing: 12) {
                    Image(systemName: "airplane.departure")
                        .foregroundColor(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fleet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.configuration.fleet.fullDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $viewModel.configuration.fleet) {
                        ForEach(FRMSFleet.allCases, id: \.self) { fleet in
                            Text(fleet.shortName).tag(fleet)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.configuration.fleet) { _, _ in
                        viewModel.configuration.updateSignOffForFleet()
                    }
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // Home Base Picker
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home Base")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(viewModel.configuration.homeBase)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $viewModel.configuration.homeBase) {
                        Text("SYD").tag("SYD")
                        Text("MEL").tag("MEL")
                        Text("BNE").tag("BNE")
                        Text("ADL").tag("ADL")
                        Text("PER").tag("PER")
                        Text("NZ").tag("NZ")
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // Default Limits removed - always using operational limits

                // Accuracy note
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(Color.green)
                        .frame(width: 20)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Accurate FRMS Tracking")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary.opacity(0.85))

                        Text("STD, STA, OUT and IN times are required for Flight & Duty time calculations. Flights logged with any of these times missing will have inaccurate FRMS times.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                )
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
