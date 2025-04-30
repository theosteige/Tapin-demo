//
//  AttendanceRecordsView.swift
//  Broke
//
//  Created by Theo Steiger on 2/13/25.
//

//import SwiftUI
//
//struct AttendanceRecordsView: View {
//    @EnvironmentObject var attendanceManager: AttendanceManager
//
//    var body: some View {
//        NavigationView {
//            List(attendanceManager.records) { record in
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Profile: \(record.profileName)")
//                        .font(.headline)
//                    Text("Time: \(record.date, formatter: DateFormatter.attendanceFormatter)")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                .padding(.vertical, 4)
//            }
//            .navigationTitle("Attendance Records")
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    // Optionally, you could add a "Clear" button here
//                    Button("Clear") {
//                        attendanceManager.records.removeAll()
//                    }
//                }
//            }
//        }
//    }
//}
//
//// A DateFormatter extension to format attendance timestamps.
//extension DateFormatter {
//    static var attendanceFormatter: DateFormatter {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter
//    }
//}
//
//struct AttendanceRecordsView_Previews: PreviewProvider {
//    static var previews: some View {
//        AttendanceRecordsView()
//            .environmentObject(AttendanceManager())
//    }
//}

import SwiftUI

struct AttendanceRecordsView: View {
    @EnvironmentObject var attendanceManager: AttendanceManager
    @EnvironmentObject var loginManager: LoginManager // Inject LoginManager

    // Constants for the grid layout
    private let daysInWeek = 7
    private let squareSize: CGFloat = 15
    private let spacing: CGFloat = 3
    private let numberOfWeeks = 52 // Display last 52 weeks (1 year)

    // Calculate the date range and attendance data
    private var contributionData: [Date: Int] {
        calculateContributionData()
    }

    private var startDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -numberOfWeeks + 1, to: Date())!
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(squareSize), spacing: spacing), count: daysInWeek)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Attendance Activity (Last Year)")
                        .font(.title2)
                        .padding(.bottom)

                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(0..<(numberOfWeeks * daysInWeek), id: \.self) { index in
                            let date = Calendar.current.date(byAdding: .day, value: index, to: firstDayOfGrid())!
                            let count = contributionData[startOfDay(for: date)] ?? 0
                            
                            // Only display squares for dates within the last year up to today
                            if date <= Date() && date >= startDate {
                                Rectangle()
                                    .fill(colorForCount(count))
                                    .frame(width: squareSize, height: squareSize)
                                    .cornerRadius(3)
                                    // Add tap gesture or tooltip later if needed
                            } else {
                                Rectangle() // Placeholder for future dates or dates before start
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: squareSize, height: squareSize)
                                    .cornerRadius(3)
                            }
                        }
                    }
                    
                    // Optional: Add legend here
                    legendView

                }
                .padding()
            }
            .navigationTitle("Attendance Graph")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        // Consider confirmation dialog
                        // Call the manager's clear function for persistence
                        attendanceManager.clearRecords()
                    }
                    // Only allow moderator to clear
                    .disabled(loginManager.currentUserRole != .moderator)
                }
            }
        }
    }

    // MARK: - Helper Functions

    // Calculate the number of records per day for the current user
    private func calculateContributionData() -> [Date: Int] {
        guard let currentUser = loginManager.currentUser else { return [:] }
        
        var data = [Date: Int]()
        let userRecords = attendanceManager.records.filter { $0.username == currentUser }

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
         let startWeekday = calendar.component(.weekday, from: startDate) // Sunday = 1, Saturday = 7
         // Adjust to start the grid on Sunday (or Monday depending on locale)
         let daysToSubtract = (startWeekday - calendar.firstWeekday + 7) % 7
         return calendar.date(byAdding: .day, value: -daysToSubtract, to: startDate)!
    }


    // Determine color based on attendance count
    private func colorForCount(_ count: Int) -> Color {
        switch count {
        case 0:
            return Color.gray.opacity(0.3) // No attendance
        case 1...2:
            return Color.green.opacity(0.4) // Low
        case 3...4:
            return Color.green.opacity(0.7) // Medium
        default:
            return Color.green // High
        }
    }
    
    // View for the color legend
    private var legendView: some View {
        HStack {
            Text("Less")
                .font(.caption)
            ForEach([0, 1, 3, 5], id: \.self) { count in // Sample counts for legend colors
                 Rectangle()
                    .fill(colorForCount(count))
                    .frame(width: squareSize, height: squareSize)
                    .cornerRadius(3)
            }
            Text("More")
               .font(.caption)
        }
        .padding(.top)
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
        loginManager.currentUser = "user1" // Set a user for preview
        loginManager.currentUserRole = .student // Set a role
        
        // Add some sample records for user1
        let calendar = Calendar.current
        for i in 0..<100 {
             if Int.random(in: 0...2) == 0 { // Randomly add records
                 let date = calendar.date(byAdding: .day, value: -Int.random(in: 0...365), to: Date())!
                 attendanceManager.records.append(AttendanceRecord(username: "user1", className: "Sample Class", date: date))
                 // Add more on some days
                 if Int.random(in: 0...5) == 0 {
                      attendanceManager.records.append(AttendanceRecord(username: "user1", className: "Sample Class", date: date))
                 }
             }
        }


        return AttendanceRecordsView()
            .environmentObject(attendanceManager)
            .environmentObject(loginManager)
    }
}
