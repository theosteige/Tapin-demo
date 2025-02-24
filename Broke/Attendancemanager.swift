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

    init(username: String, className: String) {
        self.id = UUID()
        self.username = username
        self.className = className
        self.date = Date()
    }
}

// The attendance manager now logs both the user and the class.
class AttendanceManager: ObservableObject {
    @Published var records: [AttendanceRecord] = []
    
    // Updated function to accept a username in addition to the class (profile).
    func logAttendance(for profile: Profile, user: String) {
        let record = AttendanceRecord(username: user, className: profile.name)
        records.append(record)
        print("Logged attendance for user \(user) in class \(profile.name) at \(record.date)")
    }
}
