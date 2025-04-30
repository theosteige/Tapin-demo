

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
