/**
 * The main entry point for the Broke SwiftUI application.
 *
 * This structure defines the application's lifecycle and root view hierarchy.
 * Key responsibilities include:
 * - Initializing and managing the application's core state objects/managers
 *   (`AppBlocker`, `ProfileManager`, `AttendanceManager`, `LoginManager`) using `@StateObject`.
 * - Conditionally presenting either the `LoginView` or the main `BrockerView` based on the
 *   user's login status (`loginManager.isLoggedIn`).
 * - Injecting the core manager objects into the SwiftUI environment using `.environmentObject`,
 *   making them accessible to descendant views.
 */

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
