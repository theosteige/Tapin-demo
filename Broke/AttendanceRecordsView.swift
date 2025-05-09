/**
 * A SwiftUI view that displays attendance records.
 *
 * This view provides:
 * - A monthly calendar grid highlighting days with attendance records.
 * - A detail section showing individual attendance sessions for a selected date.
 * - Aggregated time totals per task category for the selected date.
 * - Aggregated time totals per task category across all recorded sessions.
 * It interacts with the `AttendanceManager` environment object to access the data.
 */

//
//  AttendanceRecordsView.swift
//  Broke
//
//  Created by Theo Steiger on 2/13/25.
//

import SwiftUI
import Foundation // Import Foundation for Calendar and Date manipulations
import Charts // Import SwiftUI Charts

// Define a structure for chart data points
struct TaskDurationChartData: Identifiable {
    // Use category rawValue as stable ID
    var id: String { category.rawValue }
    let category: TaskCategory
    let duration: TimeInterval // Duration in seconds
}

struct AttendanceRecordsView: View {
    @EnvironmentObject var attendanceManager: AttendanceManager
    @State private var selectedDate: Date?
    // Add state variables to control expansion if needed, or rely on default DisclosureGroup state
    // @State private var isMonthlyOverviewExpanded: Bool = true
    // @State private var isDailyDetailExpanded: Bool = true
    // @State private var isDailyTotalsExpanded: Bool = true
    // @State private var isOverallTotalsExpanded: Bool = true

    // Group records by day (start of day)
    private var recordsByDay: [Date: [AttendanceRecord]] {
        Dictionary(grouping: attendanceManager.records) { record in
            Calendar.current.startOfDay(for: record.startTime) // Use startTime for grouping
        }
    }

    // Calculate aggregated task durations for the selected date
    private var taskDurationsForSelectedDate: [TaskCategory: TimeInterval] {
        guard let date = selectedDate, let recordsForDay = recordsByDay[date] else {
            return [:]
        }
        var durations: [TaskCategory: TimeInterval] = [:]
        for record in recordsForDay {
            // Use taskCategory, check it's not nil
            guard let category = record.taskCategory, let endTime = record.endTime else {
                continue // Skip records without a category or end time
            }
            let duration = endTime.timeIntervalSince(record.startTime)
            durations[category, default: 0] += duration
        }
        return durations
    }
    
    // Calculate aggregated task durations across ALL records, including tasks with 0 time
    private var totalTaskDurations: [TaskCategory: TimeInterval] {
        // Initialize durations dictionary with all possible task categories set to 0
        var durations = Dictionary(uniqueKeysWithValues: TaskCategory.allCases.map { ($0, 0.0) })
        
        for record in attendanceManager.records {
             // Use taskCategory, check it's not nil
             guard let category = record.taskCategory, let endTime = record.endTime else {
                 continue // Skip records without a category or end time
             }
             // Only add duration if the category exists in our predefined list (safety check)
             if durations.keys.contains(category) {
                 let duration = endTime.timeIntervalSince(record.startTime)
                 durations[category, default: 0] += duration
             }
         }
         return durations
    }

    // Prepare data for the chart, filtering out zero-duration tasks for visual clarity
    private var chartData: [TaskDurationChartData] {
        totalTaskDurations
            .filter { $0.value > 0 } // Only include tasks with recorded time in the chart
            .map { TaskDurationChartData(category: $0.key, duration: $0.value) }
            .sorted { $0.category.rawValue < $1.category.rawValue } // Consistent order
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
                 // --- Collapsible Calendar Grid Section ---
                 // Section header becomes the DisclosureGroup label
                 DisclosureGroup("Monthly Overview") { // Wrap content in DisclosureGroup
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
                 .padding([.horizontal, .top]) // Apply padding to the DisclosureGroup

                // --- Collapsible Daily Detail Section --- 
                if let date = selectedDate, let records = recordsByDay[date] {
                    DisclosureGroup("Sessions for \(date, formatter: DateFormatter.dateOnlyFormatter)") { // Wrap content in DisclosureGroup
                        List {
                           ForEach(records) { record in
                               VStack(alignment: .leading) {
                                   Text("User: \(record.username)")
                                   Text("Class: \(record.className)")
                                   // Display category rawValue
                                   Text("Task: \(record.taskCategory?.rawValue ?? "N/A")") 
                                   HStack {
                                        Text("Start: \(record.startTime, formatter: DateFormatter.timeOnlyFormatter)")
                                        if let endTime = record.endTime {
                                            Text("End: \(endTime, formatter: DateFormatter.timeOnlyFormatter)")
                                        } else {
                                            Text("End: (In Progress)").foregroundColor(.secondary)
                                        }
                                   }
                                   .font(.caption).foregroundColor(.secondary)
                               }
                               .padding(.vertical, 2)
                           }
                        }
                        .frame(height: CGFloat(records.count) * 85) // Adjust height slightly
                        .listStyle(.plain)
                        .padding(.horizontal)
                    }
                    .padding(.horizontal) // Apply padding to the DisclosureGroup
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // --- Collapsible Daily Task Duration Section --- 
                    let dailyTaskDurations = taskDurationsForSelectedDate
                    if !dailyTaskDurations.isEmpty {
                         DisclosureGroup("Task Totals for \(date, formatter: DateFormatter.dateOnlyFormatter)") { // Wrap content in DisclosureGroup
                              List {
                                   // Sort by category rawValue for consistent order
                                   ForEach(dailyTaskDurations.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { category, totalDuration in
                                        HStack {
                                             // Display category rawValue
                                             Text(category.rawValue)
                                             Spacer()
                                             Text(durationFormatter.string(from: totalDuration) ?? "--")
                                        }
                                   }
                              }
                              .frame(height: CGFloat(dailyTaskDurations.count) * 45) // Adjust height
                              .listStyle(.plain)
                              .padding(.horizontal)
                         }
                         .padding(.horizontal) // Apply padding to the DisclosureGroup
                         .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // --- Collapsible Overall Task Duration Section ---
                 DisclosureGroup("Overall Task Totals") { // Wrap content in DisclosureGroup
                     HStack(alignment: .top) { // Use HStack for side-by-side layout
                         // Chart View (Requires iOS 16+)
                         VStack {
                             Text("Total Time Distribution").font(.caption).foregroundColor(.secondary)
                             if #available(iOS 16.0, *) {
                                 if chartData.isEmpty {
                                     Text("No time recorded yet.")
                                         .foregroundColor(.secondary)
                                         .frame(minWidth: 150, minHeight: 150)
                                         .background(Color(UIColor.systemGray5))
                                         .cornerRadius(8)
                                 } else {
                                     Chart(chartData) { dataPoint in
                                         // Bar chart: Task Category on Y-axis, Duration on X-axis
                                         BarMark(
                                             x: .value("Duration (s)", dataPoint.duration),
                                             y: .value("Task", dataPoint.category.rawValue)
                                         )
                                         // Use foregroundStyle(by:) for automatic coloring per category
                                         .foregroundStyle(by: .value("Task", dataPoint.category.rawValue))
                                     }
                                     // Add horizontal axis label
                                     .chartXAxisLabel("Total Time (seconds)", alignment: .center)
                                     // Optional: Customize X-axis formatting if needed
                                     // .chartXAxis {
                                     //     AxisMarks(format: /* Custom Formatter */)
                                     // }
                                     // Optional: Hide Y-axis labels if category names are clear from legend/bars
                                     // .chartYAxis(.hidden)
                                     .frame(minHeight: 150) // Ensure chart has a minimum height
                                 }
                             } else {
                                 // Fallback on earlier versions
                                 Text("Charts require iOS 16+")
                                     .foregroundColor(.secondary)
                                     .frame(minWidth: 150, minHeight: 150)
                             }
                         }
                         .frame(minWidth: 150) // Give the chart container a minimum width
                         .padding(.trailing) // Add some spacing between graph and list
 
                         // Existing List View for totals
                         VStack(alignment: .leading) { // Wrap List in VStack if needed for alignment/sizing
                              let overallDurations = totalTaskDurations
                              Text("Total Time per Task:").font(.subheadline) // Add a label for the list
                              List {
                                   // Sort by category rawValue
                                   ForEach(overallDurations.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { category, totalDuration in
                                        HStack {
                                             // Display category rawValue
                                             Text(category.rawValue)
                                             Spacer()
                                             Text(durationFormatter.string(from: totalDuration) ?? "0s") // Show "0s" if duration is zero or formatting fails
                                        }
                                   }
                              }
                              // Make height dynamic based on content, up to a limit
                              .frame(maxHeight: CGFloat(max(overallDurations.count, 1)) * 45)
                              .listStyle(.plain)
                         }
                     }
                     .padding(.horizontal)
                     .padding(.bottom) // Add padding at the bottom
                 }
                 .padding([.horizontal, .bottom]) // Apply padding to the DisclosureGroup
                 .transition(.opacity) // Simple fade in
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
            .fill(hasRecord ? Color(.systemMint) : Color(UIColor.systemGray5)) // Use a system gray for better light/dark mode adaptivity
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
         self.init(username: username, className: className, startTime: date, endTime: nil, taskCategory: nil)
     }
 }

