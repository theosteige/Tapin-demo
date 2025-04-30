//
//  AttendanceRecordsView.swift
//  Broke
//
//  Created by Theo Steiger on 2/13/25.
//

import SwiftUI
import Foundation // Import Foundation for Calendar and Date manipulations

struct AttendanceRecordsView: View {
    @EnvironmentObject var attendanceManager: AttendanceManager
    @State private var selectedDate: Date?

    // Group records by day (start of day)
    private var recordsByDay: [Date: [AttendanceRecord]] {
        Dictionary(grouping: attendanceManager.records) { record in
            Calendar.current.startOfDay(for: record.date)
        }
    }

    // Determine the range of dates to display (e.g., last 365 days)
    // For simplicity now, we'll just use the days present in the records,
    // but a more robust implementation would define a fixed range.
    private var dateRange: [Date] {
        generateDatesForCurrentMonth()
    }

    // Define grid columns (7 days a week)
    private let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 7)

    // Function to generate dates for the current month, padded to full weeks
    private func generateDatesForCurrentMonth() -> [Date] {
        let calendar = Calendar.current
        let today = Date()

        // Get the interval for the current month
        guard let monthInterval = calendar.dateInterval(of: .month, for: today) else {
            return [] // Return empty if month interval can't be determined
        }
        let firstDayOfMonth = monthInterval.start
        let lastDayOfMonth = monthInterval.end // Note: This is the start of the *next* day

        // Get the interval for the week containing the first day of the month
        guard let firstWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: firstDayOfMonth) else {
            return []
        }
        let firstDayToDisplay = firstWeekInterval.start

        // Get the interval for the week containing the last *actual* day of the month
        // We need to go back one second from monthInterval.end to get the *actual* last moment of the month
        let actualLastMomentOfMonth = calendar.date(byAdding: .second, value: -1, to: lastDayOfMonth) ?? lastDayOfMonth
        guard let lastWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: actualLastMomentOfMonth) else {
            return []
        }
        let lastDayToDisplay = lastWeekInterval.end // This is the start of the day *after* the last day shown

        var dates: [Date] = []
        calendar.enumerateDates(startingAfter: calendar.date(byAdding: .day, value: -1, to: firstDayToDisplay)!, // Start enumerating from the day *before* the first day
                                matching: DateComponents(hour: 0, minute: 0, second: 0), // Match start of day
                                matchingPolicy: .nextTime) { date, _, stop in
            guard let currentDate = date else { return }
            if currentDate >= lastDayToDisplay {
                stop = true // Stop when we reach the day after the last day to display
                return
            }
            // Only add dates that are within the first day to display or later
            if currentDate >= firstDayToDisplay {
                 dates.append(currentDate)
            }
        }

        return dates
    }

    var body: some View {
        NavigationView {
            ScrollView { // Use ScrollView for potentially large grids
                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(dateRange, id: \.self) { day in
                        // Determine if the day cell should be 'active' (within the current month)
                        let isDayInCurrentMonth = Calendar.current.isDate(day, equalTo: Date(), toGranularity: .month)

                        DayCell(day: day, hasRecord: recordsByDay[day] != nil)
                            .opacity(isDayInCurrentMonth ? 1.0 : 0.4) // Fade out days not in the current month
                            .onTapGesture {
                                // Toggle selection: Allow tapping only if it has a record AND is in the current month
                                if recordsByDay[day] != nil && isDayInCurrentMonth {
                                    // If tapping the same date again, deselect it
                                    if self.selectedDate == day {
                                        self.selectedDate = nil
                                    } else {
                                        self.selectedDate = day
                                    }
                                }
                            }
                    }
                }
                .padding()

                // --- Detail Section --- 
                if let date = selectedDate, let records = recordsByDay[date] {
                    Section(header: Text("Details for \(date, formatter: DateFormatter.dateOnlyFormatter)").font(.headline).padding(.horizontal)) {
                        // Use a List for standard row appearance and potential separators
                        List {
                           ForEach(records) { record in
                               VStack(alignment: .leading) {
                                   Text("User: \(record.username)")
                                   Text("Class: \(record.className)")
                                   Text("Time: \(record.date, formatter: DateFormatter.attendanceFormatter)")
                                       .font(.caption)
                                       .foregroundColor(.secondary)
                               }
                               .padding(.vertical, 2) // Add slight vertical padding within the row
                           }
                        }
                         // Adjust frame height dynamically or set a fixed height
                         // Be mindful of nested ScrollViews if List grows large
                        .frame(height: CGFloat(records.count) * 80) // Set a fixed height for the details list
                        .listStyle(.plain) // Use plain style to blend better
                        .padding(.horizontal)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top))) // Add a subtle transition
                }
                // --- End Detail Section ---
            }
            .navigationTitle("Tap Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        attendanceManager.records.removeAll()
                        self.selectedDate = nil // Clear selection when records are cleared
                    }
                }
            }
        }
        .animation(.default, value: selectedDate) // Animate changes when selectedDate changes
    }
}

// Simple view for each day cell
struct DayCell: View {
    let day: Date
    let hasRecord: Bool

    var body: some View {
        Rectangle()
            .fill(hasRecord ? Color.yellow : Color(UIColor.systemGray5)) // Use a system gray for better light/dark mode adaptivity
            .frame(height: 30) // Adjust size as needed
            .cornerRadius(3)
            // Optional: Add day number or other indicators
            // .overlay(Text("\(Calendar.current.component(.day, from: day))").font(.caption2))
    }
}

extension DateFormatter {
    static var attendanceFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    // New formatter for displaying just the date
    static var dateOnlyFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

// Add initializer to AttendanceRecord accepting a Date
// This should ideally be in AttendanceManager.swift, but placed here for preview functionality
extension AttendanceRecord {
     init(username: String, className: String, date: Date) {
        self.id = UUID()
        self.username = username
        self.className = className
        self.date = date // Use provided date
    }
}

// // Preview needs adjustment if you want to see the grid populated
// struct AttendanceRecordsView_Previews: PreviewProvider {
//     static var previews: some View {
//         // Create a sample AttendanceManager with some data for the preview
//         let manager = AttendanceManager()
//         // Add some dummy records spanning a few days
//         let calendar = Calendar.current
//         let today = Date()
//         manager.records.append(AttendanceRecord(username: "user1", className: "Math", date: today))
//         if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
//              manager.records.append(AttendanceRecord(username: "user1", className: "Math", date: yesterday))
//              manager.records.append(AttendanceRecord(username: "user1", className: "History", date: yesterday))
//         }
//         if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) {
//              manager.records.append(AttendanceRecord(username: "user2", className: "Science", date: twoDaysAgo))
//         }
//          if let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today) {
//              manager.records.append(AttendanceRecord(username: "user1", className: "Math", date: tenDaysAgo))
//         }


//         AttendanceRecordsView()
//             .environmentObject(manager)
//     }
// }
