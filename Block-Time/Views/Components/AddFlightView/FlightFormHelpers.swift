import SwiftUI

// MARK: - Success Notification Banner
struct SuccessNotificationBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.green)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - FlightAware Lookup Progress View
struct FlightAwareLookupProgressView: View {
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: 16) {
                // FlightAware logo or airplane icon
                Image(systemName: "airplane.path.dotted")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)

                // Loading indicator
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.blue)

                Text("Searching online...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity)
    }
}
