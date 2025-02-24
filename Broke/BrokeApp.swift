//
//  BrokeApp.swift
//  Broke
//
//  Created by Oz Tamir on 19/08/2024.
//

//import SwiftUI
//
//@main
//struct BrokeApp: App {
//    @StateObject private var appBlocker = AppBlocker()
//    @StateObject private var profileManager = ProfileManager()
//    
//    var body: some Scene {
//        WindowGroup {
//            BrokerView()
//                .environmentObject(appBlocker)
//                .environmentObject(profileManager)
//        }
//    }
//}

//import SwiftUI
//
//@main
//struct BrokeApp: App {
//    @StateObject private var appBlocker = AppBlocker()
//    @StateObject private var profileManager = ProfileManager()
//    @StateObject private var attendanceManager = AttendanceManager()  // New attendance manager
//
//    var body: some Scene {
//        WindowGroup {
//            BrokerView()
//                .environmentObject(appBlocker)
//                .environmentObject(profileManager)
//                .environmentObject(attendanceManager) // Inject it into the environment
//        }
//    }
//}

import SwiftUI

@main
struct BrokeApp: App {
    @StateObject private var appBlocker = AppBlocker()
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var attendanceManager = AttendanceManager()
    @StateObject private var loginManager = LoginManager()
    
    var body: some Scene {
        WindowGroup {
            if loginManager.isLoggedIn {
                // Main view after login:
                BrokerView()
                    .environmentObject(appBlocker)
                    .environmentObject(profileManager)
                    .environmentObject(attendanceManager)
                    .environmentObject(loginManager)
            } else {
                // Show login if not logged in:
                LoginView()
                    .environmentObject(loginManager)
            }
        }
    }
}
