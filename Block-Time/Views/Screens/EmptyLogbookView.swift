import SwiftUI

// MARK: - Empty State View
struct EmptyLogbookView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Flights Recorded")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            
            Text("Capture an ACARS, Manually Add, or Import from Settings")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyLogbookView()
}
