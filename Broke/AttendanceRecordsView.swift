

import SwiftUI

struct AttendanceRecordsView: View {
    @EnvironmentObject var attendanceManager: AttendanceManager
    @EnvironmentObject var loginManager: LoginManager

    // Constants for the grid layout
    private let daysInWeek = 7
    private let squareSize: CGFloat = 15 // Adjust size if needed
    private let spacing: CGFloat = 2      // Adjust spacing if needed
    private let numberOfWeeks = 52 

    // Calculate the date range and attendance data
    private var contributionData: [Date: Int] {
        calculateContributionData()
    }

    private var startDate: Date {
        // Ensure start date is calculated correctly relative to today's start of day
        Calendar.current.date(byAdding: .day, value: -(numberOfWeeks * daysInWeek) + 1, to: Calendar.current.startOfDay(for: Date()))!
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: daysInWeek)
    }

    var body: some View {
        // Removed NavigationView, assuming it's presented in a sheet from BrokerView
        ScrollView {
            VStack(alignment: .leading, spacing: 15) { // Increased spacing
                Text("Attendance Activity (Last Year)")
                    .font(.title2).bold()
                    .foregroundColor(Color("PrimaryText")) // Use asset color
                    .padding(.bottom, 5)
                
                contributionGraph
                
                legendView
                    .padding(.top, 10)

            }
            .padding()
        }
        .background(Color("BackgroundColor").edgesIgnoringSafeArea(.all)) // Use asset color
        .navigationTitle("Attendance Graph") // Keep title if presented in NavigationView elsewhere
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if loginManager.currentUserRole == .moderator {
                    Button("Clear") {
                        // Add confirmation alert?
                        attendanceManager.clearRecords()
                    }
                    .tint(Color("DestructiveColor")) // Use red tint for clear
                }
            }
        }
    }
    
    // Extracted Graph View
    private var contributionGraph: some View {
         LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(0..<(numberOfWeeks * daysInWeek), id: \.self) { index in
                let date = Calendar.current.date(byAdding: .day, value: index, to: firstDayOfGrid())!
                let count = contributionData[startOfDay(for: date)] ?? 0
                
                // Only display squares for dates within the relevant range
                if date >= startOfDay(for: startDate) && date <= Calendar.current.startOfDay(for: Date()) {
                    Rectangle()
                        .fill(colorForCount(count))
                        .aspectRatio(1, contentMode: .fit) // Maintain square shape
                        .cornerRadius(3)
                        // Consider adding tooltip/popover on tap/hover
                        // .onTapGesture { show details for 'date' }
                } else {
                    Rectangle() // Placeholder for future/past dates outside range
                        .fill(Color.clear) // Make placeholders invisible
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    // MARK: - Helper Functions

    // Calculate the number of records per day for the current user
    private func calculateContributionData() -> [Date: Int] {
        guard let currentUser = loginManager.currentUser else { return [:] }
        
        var data = [Date: Int]()
        // Filter records for the current user and within the date range for efficiency
        let userRecords = attendanceManager.records.filter { 
            $0.username == currentUser && 
            $0.date >= startDate
        }

        for record in userRecords {
            let day = startOfDay(for: record.date)
            data[day, default: 0] += 1
        }
        return data
    }

    // Get the start of a given Date (midnight)
    private func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    // Calculate the first day to display in the grid (start of the week for the startDate)
    private func firstDayOfGrid() -> Date {
         let calendar = Calendar.current
         // Calculate based on the start date for the data range
         let firstDate = startOfDay(for: startDate)
         let startWeekday = calendar.component(.weekday, from: firstDate)
         let daysToSubtract = (startWeekday - calendar.firstWeekday + daysInWeek) % daysInWeek
         return calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDate)!
    }

    // Determine color based on attendance count
    private func colorForCount(_ count: Int) -> Color {
        switch count {
        case 0:
            return Color("SecondaryBackground") // Use light gray for empty days
        case 1...2:
            return Color("BrandBlue").opacity(0.4) // Light Blue
        case 3...4:
            return Color("BrandBlue").opacity(0.7) // Medium Blue
        default: // 5+
            return Color("BrandBlue") // Dark Blue
        }
    }
    
    // View for the color legend
    private var legendView: some View {
        HStack(spacing: 5) {
            Text("Less")
            ForEach([0, 1, 3, 5], id: \.self) { count in
                 Rectangle()
                    .fill(colorForCount(count))
                    .frame(width: squareSize, height: squareSize)
                    .cornerRadius(3)
            }
            Text("More")
        }
        .font(.caption)
        .foregroundColor(Color("SecondaryText")) // Use asset color
    }
}

// Keep the DateFormatter extension if needed elsewhere, but it's not used in this view anymore
extension DateFormatter {
    static var attendanceFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct AttendanceRecordsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock data for preview
        let attendanceManager = AttendanceManager()
        let loginManager = LoginManager()
        loginManager.currentUser = "user1"
        loginManager.currentUserRole = .student
        
        // Add sample records
        let calendar = Calendar.current
        let today = Date()
        for i in 0..<(52*7) { // Cover the year range
             let date = calendar.date(byAdding: .day, value: -i, to: today)!
             let randomScans = Int.random(in: 0...7) // Random attendance count
             if randomScans > 0 {
                 for _ in 0..<randomScans {
                    // Ensure records are added with correct date for preview
                    attendanceManager.records.append(AttendanceRecord(username: "user1", className: "Sample Class", date: date))
                 }
             }
        }
        // Important: Need to save the preview records if AttendanceManager loads on init
        // attendanceManager.saveRecords() // Uncomment if needed, though preview usually uses fresh instance

        // Embed in NavigationView for realistic preview presentation
        NavigationView {
             AttendanceRecordsView()
                .environmentObject(attendanceManager)
                .environmentObject(loginManager)
                 // Add mock colors for preview if needed
                 .environment(\.colorScheme, .light)
        }
    }
}
