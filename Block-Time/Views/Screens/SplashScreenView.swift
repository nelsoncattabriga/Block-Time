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
    @State private var size: CGFloat = 0.7
    @State private var opacity: Double = 0.3

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "v\(version).\(build)"
    }

    var body: some View {
        if isActive {
            MainTabView()
        } else {
            VStack {
                VStack {
                    if let uiImage = UIImage(named: "SplashIcon") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 280, height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 140))
                    } else {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                    }

                    Text("Block-Time")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)

                    Text(appVersion)
                        .font(.subheadline.bold())
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.0)) {
                        self.size = 1.0
                        self.opacity = 1.0
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                themeService.getGradient()
                    .ignoresSafeArea()
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
