//
//  SplashScreenView.swift
//  Block-Time
//
//  Created by Nelson on 8/9/2025.
//
import SwiftUI

struct SplashScreenView: View {
    @ObservedObject private var themeService = ThemeService.shared
    @State private var isActive = false
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.3

    // Constants
    private enum Constants {
        static let iconSize: CGFloat = 280
        static let iconCornerRadius: CGFloat = 140
        static let initialDelay: TimeInterval = 1.0
        static let animationDuration: Double = 1.0
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "v\(version).\(build)"
    }

    var body: some View {
        ZStack {
            if isActive {
                MainTabView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 10) {
                    if let uiImage = UIImage(named: "SplashIcon") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: Constants.iconCornerRadius))
                    } else {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 120))
                            .foregroundColor(.blue)
                    }

                    Text("Block-Time")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    Text(appVersion)
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                }
                .scaleEffect(scale)
                .opacity(opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeService.getGradient().ignoresSafeArea())
        .task {
            // Animate the splash content
            withAnimation(.easeIn(duration: Constants.animationDuration)) {
                scale = 1.0
                opacity = 1.0
            }

            // Wait, then transition to main view
            try? await Task.sleep(nanoseconds: UInt64(Constants.initialDelay * 1_000_000_000))
            withAnimation {
                isActive = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
