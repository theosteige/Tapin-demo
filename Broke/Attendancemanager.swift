//
//  Attendancemanager.swift
//  Broke
//
//  Created by Theo Steiger on 2/13/25.
//

import SwiftUI

// Updated model to include task tracking
struct AttendanceRecord: Identifiable, Codable {
    let id: UUID
    let username: String
    let className: String
    let startTime: Date // Renamed from date
    var endTime: Date?   // Optional: Set when user taps out
    var taskDescription: String? // Optional: User-provided task

    // Initializer for starting a session (no task description initially)
    init(username: String, className: String) {
        self.id = UUID()
        self.username = username
        self.className = className
        self.startTime = Date() // Set current time as start time
        self.endTime = nil
        self.taskDescription = nil
    }
    
    // Add a convenience initializer if needed for previews or testing
     init(id: UUID = UUID(), username: String, className: String, startTime: Date, endTime: Date? = nil, taskDescription: String? = nil) {
        self.id = id
        self.username = username
        self.className = className
        self.startTime = startTime
        self.endTime = endTime
        self.taskDescription = taskDescription
    }
}

// The attendance manager now logs both the user and the class.
class AttendanceManager: ObservableObject {
    @Published var records: [AttendanceRecord] = []
    
    // Function to log the START of attendance (and potentially the task later)
    func logAttendanceStart(for profile: Profile, user: String) -> UUID? {
        // Prevent duplicate active sessions for the same user/class (optional but good practice)
        if records.contains(where: { $0.username == user && $0.className == profile.name && $0.endTime == nil }) {
             print("User \(user) already has an active session for class \(profile.name)")
             return nil // Indicate failure or handle as needed
        }
        
        let newRecord = AttendanceRecord(username: user, className: profile.name)
        records.append(newRecord)
        print("Logged attendance START for user \(user) in class \(profile.name) at \(newRecord.startTime)")
        return newRecord.id // Return ID to potentially update task later
    }
    
    // Function to update task description for a specific record
    func updateTask(for recordId: UUID, task: String) {
        if let index = records.firstIndex(where: { $0.id == recordId }) {
            records[index].taskDescription = task
            print("Updated task for record \(recordId) to: \(task)")
        }
    }

    // Function to mark the END of the most recent active session for a user/class
    func logAttendanceEnd(for profile: Profile, user: String) {
        // Find the most recent record for this user/class that hasn't ended yet
        if let index = records.lastIndex(where: { $0.username == user && $0.className == profile.name && $0.endTime == nil }) {
            records[index].endTime = Date()
            print("Logged attendance END for user \(user) in class \(profile.name) at \(records[index].endTime!)")
        } else {
            print("Could not find active session to end for user \(user) in class \(profile.name)")
        }
    }
    
    // Function to get records for a specific date (still useful for display)
    func records(for date: Date) -> [AttendanceRecord] {
        let calendar = Calendar.current
        return records.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
    
    // Computed property to get unique, sorted task descriptions
    var uniqueTaskDescriptions: [String] {
        let allTasks = records.compactMap { $0.taskDescription }.filter { !$0.isEmpty }
        let uniqueTasks = Set(allTasks)
        return Array(uniqueTasks).sorted()
    }
}
