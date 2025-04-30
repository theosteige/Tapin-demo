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
            Calendar.current.startOfDay(for: record.startTime) // Use startTime for grouping
        }
    }

    // Calculate aggregated task durations for the selected date
    private var taskDurationsForSelectedDate: [String: TimeInterval] {
        guard let date = selectedDate, let recordsForDay = recordsByDay[date] else {
            return [:]
        }
        
        var durations: [String: TimeInterval] = [:]
        
        for record in recordsForDay {
            guard let task = record.taskDescription, !task.isEmpty, let endTime = record.endTime else {
                continue // Skip records without a task or end time
            }
            let duration = endTime.timeIntervalSince(record.startTime)
            durations[task, default: 0] += duration
        }
        
        return durations
    }
    
    // Calculate aggregated task durations across ALL records
    private var totalTaskDurations: [String: TimeInterval] {
        var durations: [String: TimeInterval] = [:]
        for record in attendanceManager.records {
             guard let task = record.taskDescription, !task.isEmpty, let endTime = record.endTime else {
                 continue // Skip records without a task or end time
             }
             let duration = endTime.timeIntervalSince(record.startTime)
             durations[task, default: 0] += duration
         }
         return durations
    }

    // Formatter for displaying time intervals nicely
    private let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated // e.g., "1h 15m"
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad // Optional: show 0h 0m 5s
        return formatter
    }()

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
            ScrollView { 
                 // --- Calendar Grid Section ---
                 Section(header: Text("Monthly Overview").font(.headline).padding([.horizontal, .top])) {
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
                     .padding(.horizontal)
                 }

                // --- Daily Detail Section --- 
                if let date = selectedDate, let records = recordsByDay[date] {
                    Section(header: Text("Sessions for \(date, formatter: DateFormatter.dateOnlyFormatter)").font(.headline).padding(.horizontal)) {
                        List {
                           ForEach(records) { record in
                               VStack(alignment: .leading) {
                                   Text("User: \(record.username)")
                                   Text("Class: \(record.className)")
                                   Text("Task: \(record.taskDescription ?? "N/A")") // Display task
                                   HStack {
                                        Text("Start: \(record.startTime, formatter: DateFormatter.timeOnlyFormatter)") // Use new timeOnlyFormatter
                                        if let endTime = record.endTime {
                                            Text("End: \(endTime, formatter: DateFormatter.timeOnlyFormatter)")
                                        } else {
                                            Text("End: (In Progress)")
                                                .foregroundColor(.secondary)
                                        }
                                   }
                                   .font(.caption)
                                   .foregroundColor(.secondary)
                               }
                               .padding(.vertical, 2)
                           }
                        }
                        .frame(height: CGFloat(records.count) * 85) // Adjust height slightly
                        .listStyle(.plain)
                        .padding(.horizontal)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // --- Daily Task Duration Section --- 
                    let dailyTaskDurations = taskDurationsForSelectedDate
                    if !dailyTaskDurations.isEmpty {
                         Section(header: Text("Task Totals for \(date, formatter: DateFormatter.dateOnlyFormatter)").font(.headline).padding(.horizontal)) {
                              List {
                                   ForEach(dailyTaskDurations.sorted(by: { $0.key < $1.key }), id: \.key) { task, totalDuration in
                                        HStack {
                                             Text(task)
                                             Spacer()
                                             Text(durationFormatter.string(from: totalDuration) ?? "--")
                                        }
                                   }
                              }
                              .frame(height: CGFloat(dailyTaskDurations.count) * 45) // Adjust height
                              .listStyle(.plain)
                              .padding(.horizontal)
                         }
                         .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // --- Overall Task Duration Section ---
                let overallDurations = totalTaskDurations
                if !overallDurations.isEmpty {
                     Section(header: Text("Overall Task Totals").font(.headline).padding(.horizontal)) {
                          List {
                               ForEach(overallDurations.sorted(by: { $0.key < $1.key }), id: \.key) { task, totalDuration in
                                    HStack {
                                         Text(task)
                                         Spacer()
                                         Text(durationFormatter.string(from: totalDuration) ?? "--")
                                    }
                               }
                          }
                          // Make height dynamic based on content, up to a limit
                          .frame(maxHeight: CGFloat(overallDurations.count) * 45) 
                          .listStyle(.plain)
                          .padding(.horizontal)
                          .padding(.bottom) // Add padding at the bottom
                     }
                     .transition(.opacity) // Simple fade in
                }
            }
            .navigationTitle("Tap Tracker")
        }
        .animation(.default, value: selectedDate)
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
    
    static var timeOnlyFormatter: DateFormatter {
         let formatter = DateFormatter()
         formatter.dateStyle = .none
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

// Updated initializer to reflect new AttendanceRecord structure
extension AttendanceRecord {
     init(username: String, className: String, date: Date) {
         // This initializer might be outdated or used only for previews?
         // It doesn't align perfectly with the main init or the new fields.
         // Consider removing or updating it based on usage.
         self.init(username: username, className: className, startTime: date, endTime: nil, taskDescription: nil)
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
