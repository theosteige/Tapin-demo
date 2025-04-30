//
//  Attendancemanager.swift
//  Broke
//
//  Created by Theo Steiger on 2/13/25.
//

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
