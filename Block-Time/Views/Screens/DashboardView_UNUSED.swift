////
////  DashboardView.swift
////  Block-Time
////
////  Created by Nelson on 30/9/2025.
////
//
//import SwiftUI
//
//
//struct DashboardView: View {
//    private let databaseService = FlightDatabaseService.shared
//    @Environment(ThemeService.self) private var themeService
//    @State private var flightStatistics = FlightStatistics.empty
//    @State private var isLoading = true
//    @State private var showingSettings = false
//    @State private var isEditMode = false
//    @State private var showAddSheet = false
//    @State private var settings = LogbookSettings.shared
//    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
//
//    var body: some View {
//        ZStack {
//            themeService.getGradient()
//                .ignoresSafeArea()
//            
//            
//            
//            VStack(spacing: 0) {
//                if isLoading {
//                    ProgressView("Loading statistics...")
//                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                } else {
//                    ScrollView {
//                        VStack(spacing: 16) {
//                            FlightStatisticsSection(
//                                statistics: flightStatistics,
//                                isEditMode: $isEditMode
//                            )
//                            Spacer(minLength: 20)
//                        }
//                        //.padding(.horizontal, 16)
//                        .padding(.top, 8)
//                    }
//                    .refreshable {
//                        await refreshStatistics()
//                    }
//                }
//            }
//
//            // Floating buttons in edit mode
//            if isEditMode {
//                VStack {
//                    Spacer()
//                    HStack {
//                        // Compact/Wide View Toggle Button (bottom-left) - only on iPhone
//                        if horizontalSizeClass == .compact {
//                            Button {
//                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
//                                    settings.toggleCompactView()
//                                }
//                            } label: {
//                                Image(systemName: settings.isCompactView ? "square.grid.2x2.fill" : "rectangle.grid.1x2.fill")
//                                    .font(.system(size: 48))
//                                    .foregroundColor(.blue)
//                                    .background(.clear)
////                                    .background(
////                                        Circle()
////                                            .fill(Color(.systemBackground))
////                                            .frame(width: 50, height: 50)
////                                    )
//                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
//                            }
//                            .padding(.leading, 24)
//                            .padding(.bottom, 24)
//                        }
//
//                        Spacer()
//
//                        // Add Card Button (bottom-right)
//                        Button {
//                            showAddSheet = true
//                        } label: {
//                            Image(systemName: "plus.circle.fill")
//                                .font(.system(size: 56))
//                                .foregroundColor(.blue)
//                                .background(
//                                    Circle()
//                                        .fill(Color(.systemBackground))
//                                        .frame(width: 50, height: 50)
//                                )
//                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
//                        }
//                        .padding(.trailing, 24)
//                        .padding(.bottom, 24)
//                    }
//                }
//                .transition(.scale.combined(with: .opacity))
//            }
//        }
//        .navigationTitle("Dashboard")
//        .navigationBarTitleDisplayMode(.inline)
//        .background(Color(.systemGroupedBackground))
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button {
//                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
//                        isEditMode.toggle()
//                    }
//                } label: {
//                    Text(isEditMode ? "Done" : "Edit")
//                        .fontWeight(.semibold)
//                }
//            }
//        }
//        .sheet(isPresented: $showAddSheet) {
//            AddCardSheet(availableCards: StatCardType.allCases.filter { !LogbookSettings.shared.selectedCards.contains($0) })
//        }
//        .onAppear {
//            loadStatistics()
//        }
//        .onReceive(NotificationCenter.default.publisher(for: .flightDataChanged)) { _ in
//            loadStatistics()
//        }
//    }
//
//    private func loadStatistics() {
//        isLoading = true
//       // print("DEBUG: Loading statistics from database")
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//            self.flightStatistics = self.databaseService.getFlightStatistics()
//            // print("DEBUG: Loaded statistics from database")
//            self.isLoading = false
//        }
//    }
//
//    private func refreshStatistics() async {
//        //print("DEBUG: Refreshing statistics from database (pull-to-refresh)")
//        await Task {
//            let stats = self.databaseService.getFlightStatistics()
//            await MainActor.run {
//                self.flightStatistics = stats
//            }
//        }.value
//    }
//}
//
//
//#Preview {
//    DashboardView()
//}
