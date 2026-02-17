//
//  SearchView.swift
//  Block-Time
//
//  Created by Nelson on 24/10/2025.
//

import SwiftUI

struct SearchView: View {
    @Environment(ThemeService.self) private var themeService
    @State private var searchText = ""
    @State private var showFlightAware = false

    var body: some View {
        ZStack {
            themeService.getGradient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Hero Section
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.top, 40)

                            Text("Flight Data Search")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Look up historical flight data")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Placeholder Content Card
                        VStack(spacing: 20) {
                            Button {
                                showFlightAware = true
                            } label: {
                                HStack(spacing: 16) {
//                                    Image(systemName: "airplane.departure")
//                                        .font(.title)
//                                        .foregroundColor(.blue)
//                                        .frame(width: 50, height: 50)
//                                        .background(Color.blue.opacity(0.1))
//                                        .clipShape(RoundedRectangle(cornerRadius: 12))

                                    Image("FlightAwareLogo")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 80, height: 80)
                                                .background(Color.white.opacity(0.8))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("FlightAware")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("Search Online")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
//
//                                    Image(systemName: "chevron.right")
//                                        .font(.caption)
//                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            Spacer()
                            Spacer()
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showFlightAware) {
            if let url = URL(string: "https://www.flightaware.com") {
                WebViewScreen(url: url, title: "FlightAware")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
