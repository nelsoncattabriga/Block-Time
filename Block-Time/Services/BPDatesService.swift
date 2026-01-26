import SwiftUI

struct BPDateCalculatorView: View {
    @State private var bpInput: String = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var errorMessage: String = ""
    @State private var showResult: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.orange.opacity(0.35)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("BP Date Calculator")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Enter a bid period to calculate its date range")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bid Period (BP)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("370 or 3701", text: $bpInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numbersAndPunctuation)
                            .font(.body)
                            .padding(4)
                        
                        Text("3 digits for 56-day BP • 4 digits for 28-day BP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 32)
                    
                    Button(action: calculateDates) {
                        Text("Show Dates")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    
                    if !errorMessage.isEmpty {
                        VStack {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    if showResult, let start = startDate, let end = endDate {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("BP \(bpInput)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Divider()
                            
                            HStack {
                                Text("Start Date:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(formatDate(start))
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("End Date:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(formatDate(end))
                                    .fontWeight(.bold)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Duration:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(calculateDuration(start: start, end: end)) days")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    

                }
            }
            .navigationBarHidden(true)
        }
    }
    
    func calculateDates() {
        errorMessage = ""
        showResult = false
        
        guard let bpNum = Int(bpInput) else {
            errorMessage = "Please enter a valid BP number"
            return
        }
        
        guard let dates = bpDates(bp: bpNum) else {
            errorMessage = "Invalid BP format. Use 3 digits (e.g., 291) or 4 digits (e.g., 2911)"
            return
        }
        
        startDate = dates.startDate
        endDate = dates.endDate
        showResult = true
    }
    
    func bpDates(bp: Int) -> (startDate: Date, endDate: Date)? {
        let calendar = Calendar.current
        
        let bpString = String(abs(bp))
        let digitCount = bpString.count
        
        if digitCount == 4 {
            let lastDigit = bpString.last!
            
            let epochBP: Int
            let epochDate: Date
            
            if lastDigit == "1" {
                epochBP = 11
                epochDate = calendar.date(from: DateComponents(year: 1969, month: 1, day: 13))!
            } else {
                epochBP = 15
                epochDate = calendar.date(from: DateComponents(year: 1969, month: 2, day: 10))!
            }
            
            let diffBP = (bp - epochBP) / 5
            
            guard let startDate = calendar.date(byAdding: .day, value: 28 * diffBP, to: epochDate),
                  let endDate = calendar.date(byAdding: .day, value: 27, to: startDate) else {
                return nil
            }
            
            return (startDate, endDate)
            
        } else if digitCount == 3 {
            let epochBP = 1
            let epochDate = calendar.date(from: DateComponents(year: 1969, month: 1, day: 13))!
            
            let diffBP = bp - epochBP
            
            guard let startDate = calendar.date(byAdding: .day, value: 56 * diffBP, to: epochDate),
                  let endDate = calendar.date(byAdding: .day, value: 55, to: startDate) else {
                return nil
            }

            return (startDate, endDate)
            
        } else {
            return nil
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: date)
    }
    
    func calculateDuration(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return (components.day ?? 0) + 1
    }
}

// Preview
struct BPDateCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        BPDateCalculatorView()
    }
}
