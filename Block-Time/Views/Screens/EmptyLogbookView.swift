import SwiftUI

// MARK: - Empty State View
struct EmptyLogbookView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("No Flights Recorded")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            
            Text("Add a Flight, or Import from Settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyLogbookView()
}
