//
//  Attendancemanager.swift
//  Broke
//
//  Created by Theo Steiger on 2/13/25.
//

//import SwiftUI
//
//// A simple model for each attendance record.
//struct AttendanceRecord: Identifiable, Codable {
//    let id: UUID
//    let profileName: String
//    let date: Date
//
//    init(profileName: String) {
//        self.id = UUID()
//        self.profileName = profileName
//        self.date = Date()
//    }
//}
//
//// The manager that holds attendance records.
//class AttendanceManager: ObservableObject {
//    @Published var records: [AttendanceRecord] = []
//    
//    // Log attendance for a given profile.
//    func logAttendance(for profile: Profile) {
//        let record = AttendanceRecord(profileName: profile.name)
//        records.append(record)
//        // Optionally, save to persistent storage (UserDefaults, file, or Core Data)
//        print("Logged attendance for \(profile.name) at \(record.date)")
//    }
//}

import SwiftUI

// Updated model to include the user and the class name.
struct AttendanceRecord: Identifiable, Codable {
    let id: UUID
    let username: String   // New property for the user
    let className: String  // Renamed from profileName to className
    let date: Date

    // Updated initializer to accept an optional date, defaulting to now
    init(username: String, className: String, date: Date = Date()) {
        self.id = UUID()
        self.username = username
        self.className = className
        self.date = date // Use the provided or default date
    }
}

// The attendance manager now logs both the user and the class.
class AttendanceManager: ObservableObject {
    @Published var records: [AttendanceRecord] = []
    
    // Updated function to accept a username in addition to the class (profile).
    // This will automatically use the current date via the default parameter in AttendanceRecord init
    func logAttendance(for profile: Profile, user: String) {
        let record = AttendanceRecord(username: user, className: profile.name)
        records.append(record)
        // Persist records here if needed
        print("Logged attendance for user \(user) in class \(profile.name) at \(record.date)")
        saveRecords() // Example: Call save after logging
    }
    
    // Add functions to load/save records (example using UserDefaults)
    init() {
        loadRecords()
    }

    func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: "attendanceRecords")
        }
    }

    func loadRecords() {
        if let savedRecords = UserDefaults.standard.data(forKey: "attendanceRecords"),
           let decodedRecords = try? JSONDecoder().decode([AttendanceRecord].self, from: savedRecords) {
            records = decodedRecords
            return
        }
        // Initialize with empty array if no saved data
        records = []
    }
    
    // Function to clear records (potentially add confirmation)
    func clearRecords() {
        records.removeAll()
        saveRecords()
    }
}
