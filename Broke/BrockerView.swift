/**
 * The main view displayed after successful login.
 *
 * This view serves as the central hub for the application's core functionality:
 * - Toggling the app blocking state via an interactive button and NFC tag scanning.
 * - Managing the workflow for starting a blocking session, which includes:
 *   - Optional user selection of specific apps/categories to block (`FamilyActivityPicker`).
 *   - Mandatory selection of a task category (`TaskInputSheet`).
 *   - Logging attendance start/end times (`AttendanceManager`).
 * - Displaying the profile/class selection view (`ClassesPicker`) when not blocking.
 * - Providing access to view past attendance records (`AttendanceRecordsView`).
 * - Allowing moderators to create new NFC tags.
 * - Handling user logout.
 * It coordinates interactions between `AppBlocker`, `ProfileManager`, `AttendanceManager`,
 * `LoginManager`, and `NFCReader`.
 */

//
//  BrockerView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import CoreNFC
import SFSymbolsPicker
import FamilyControls
import ManagedSettings

// Assuming TaskCategory is defined elsewhere (e.g., in AttendanceManager.swift or a Models file)
// and conforms to: Identifiable, CaseIterable, Hashable
// For example:
// enum TaskCategory: String, CaseIterable, Identifiable {
//     case work = "Work"
//     case study = "Study"
//     case focus = "Focus"
//     var id: String { self.rawValue }
// }

struct BrokerView: View {
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var attendanceManager: AttendanceManager
    @EnvironmentObject private var loginManager: LoginManager
    @StateObject private var nfcReader = NFCReader()
    
    // Other state properties...
    // private let tagPhrase = "BROKE-IS-GREAT" // No longer needed for generic tag checking here
    
    @State private var showWrongTagAlert = false
    // @State private var showCreateTagAlert = false // No longer needed
    // @State private var nfcWriteSuccess = false // Handled in ProfileFormView
    @State private var attendanceMessage: String?
    @State private var showAttendanceRecords = false
    @State private var showAddProfileView = false

    // State for user app selection
    @State private var showUserAppSelection = false
    @State private var userActivitySelection = FamilyActivitySelection()

    // State for task input SHEET - REMOVED as task selection is now upfront
    // @State private var showTaskInputSheet = false
    // @State private var currentRecordId: UUID? = nil // Will become a local var if needed
    // @State private var profileToUseForBlocking: Profile? = nil // Will be passed directly

    @State private var selectedTaskCategory: TaskCategory? = nil // For pre-scan task selection
    @State private var showTaskSelectionAlert = false // Alert if task not selected

    private var isBlocking: Bool {
        appBlocker.isBlocking
    }

    private var nfcWriteFeatureDisabled: Bool {
        #if targetEnvironment(simulator)
        return false // On simulator, enable the button for UI testing
        #else
        return !NFCNDEFReaderSession.readingAvailable // On device, actual availability
        #endif
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    VStack(spacing: 0) { // Main container VStack
                        Spacer() // Pushes content to the center vertically
                        
                        VStack(spacing: 20) { // Inner VStack for centered content
                            blockOrUnblockButton(geometry: geometry)
                            
                            // Task Picker - visible when not blocking, and now positioned under the button
                            if !isBlocking {
                                VStack(spacing: 16) {
                                    Text("Select Your Task Before Tapping In")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    // Custom task selector
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(TaskCategory.allCases) { category in
                                                TaskCategoryButton(
                                                    category: category,
                                                    isSelected: selectedTaskCategory == category,
                                                    action: {
                                                        withAnimation(.spring()) {
                                                            selectedTaskCategory = category
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .frame(height: 120) // Fixed height for the scroll view
                                }
                                .padding(.vertical)
                                
                                // Only show ClassesPicker for moderators
                                if loginManager.currentUserRole == .moderator {
                                    ClassesPicker(profileManager: profileManager)
                                        .frame(maxHeight: geometry.size.height * 0.4)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        Spacer() // Pushes content to the center vertically
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Make VStack fill the ZStack
                    .background(isBlocking ? Color("BlockingBackground") : Color("NonBlockingBackground"))
                    
                    // Attendance message overlay
                    if let message = attendanceMessage {
                        Text(message)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .transition(.opacity)
                    }
                }
            }
            .navigationBarItems(
                leading: Button(action: {
                    showAttendanceRecords = true
                }) {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Tap Tracker")
                    }
                },
                trailing: HStack { // Use HStack to group trailing items
                    if loginManager.currentUserRole == .moderator {
                        Button(action: {
                            showAddProfileView = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                    Button(action: { // Logout Button
                        loginManager.logout()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            )
            .alert("Wrong Tag", isPresented: $showWrongTagAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The scanned tag is not a valid Broker space tag or is unassigned.") // Updated message
            }
            .alert("Select a Task", isPresented: $showTaskSelectionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please select a task before starting a session.")
            }
            // .alert("Create Broker Tag?", isPresented: $showCreateTagAlert) { ... } // Removed
            // .alert("NFC Error", isPresented: $nfcWriteSuccess) { ... } // Removed
        }
        .animation(.spring(), value: isBlocking)
        .sheet(isPresented: $showAttendanceRecords) {
            AttendanceRecordsView()
                .environmentObject(attendanceManager)
        }
        // Add sheet for user app selection
        .sheet(isPresented: $showUserAppSelection) {
            NavigationView {
                FamilyActivityPicker(selection: $userActivitySelection)
                    .navigationTitle("Select Apps to Block")
                    .navigationBarItems(trailing: Button("Done") {
                        handleUserAppSelectionDone()
                    })
            }
        }
        .sheet(isPresented: $showAddProfileView) {
            ProfileFormView(profileManager: profileManager) {
                showAddProfileView = false
            }
            .environmentObject(loginManager)
        }
    }
    
    // The rest of your functions, including scanTag(), blockOrUnblockButton, etc.
    private func scanTag() {
        nfcReader.scan { scannedPayload in // Renamed payload to scannedPayload for clarity
            // Attempt to find a profile matching the scanned NFC tag ID
            if let profile = profileManager.profiles.first(where: { $0.nfcTagID == scannedPayload }) {
                // If a matching profile is found, proceed with it.
                handleValidScan(for: profile, scannedTagID: scannedPayload)
            } else {
                // No profile matches the scanned tag ID.
                showWrongTagAlert = true
                NSLog("Unknown or unassigned NFC Tag! Payload: \(scannedPayload)")
            }
        }
    }

    private func handleValidScan(for profile: Profile, scannedTagID: String) {
        // Set the found profile as the current one for ProfileManager
        profileManager.setCurrentProfile(id: profile.id)

        let currentlyBlocking = appBlocker.isBlocking

        // Check if user is assigned to this space
        if loginManager.currentUserRole == .student {
            guard let currentUser = loginManager.currentUser,
                  let assignedUsers = profile.assignedUsernames,
                  assignedUsers.contains(currentUser) else {
                showAttendance("You are not assigned to this space")
                return
            }
        }

        // Display the "Tapped into" message
        showAttendance("Tapped into: \(profile.name)")

        // Delay further actions slightly to allow the user to see the "Tapped into" message.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !currentlyBlocking { // STARTING session
                // Student app selection logic might still apply based on the profile's properties
                if profile.userSelectsApps == true && loginManager.currentUserRole == .student {
                    userActivitySelection = FamilyActivitySelection()
                    userActivitySelection.applicationTokens = profile.appTokens
                    userActivitySelection.categoryTokens = profile.categoryTokens
                    showUserAppSelection = true
                } else {
                    prepareAndStartBlocking(with: profile)
                }
            } else { // STOPPING session
                performToggleBlocking(with: profile)
            }
        }
    }

    // Called after user finishes selecting apps (if applicable)
    private func handleUserAppSelectionDone() {
        showUserAppSelection = false
        let userSelectedProfile = Profile(
            name: profileManager.currentProfile.name,
            appTokens: userActivitySelection.applicationTokens,
            categoryTokens: userActivitySelection.categoryTokens,
            icon: profileManager.currentProfile.icon,
            assignedUsernames: profileManager.currentProfile.assignedUsernames,
            userSelectsApps: true
        )
        // Now proceed to task input/blocking with the user's selected profile
        prepareAndStartBlocking(with: userSelectedProfile)
    }

    // New function to handle logic before showing task sheet - Now reworked
    private func prepareAndStartBlocking(with profileToUse: Profile) {
         guard let currentUser = loginManager.currentUser else {
             showAttendance("Error: Could not identify user.")
             return
         }
        guard let task = selectedTaskCategory else {
            // This should be caught by handleButtonTap, but as a safeguard
            showTaskSelectionAlert = true
            showAttendance("Please select a task.")
            return
        }

        if let recordId = attendanceManager.logAttendanceStart(for: profileToUse, user: currentUser) {
            attendanceManager.updateTaskCategory(for: recordId, category: task)
            appBlocker.toggleBlocking(for: profileToUse) // Perform blocking now
            showAttendance("Tapped into: \(profileToUse.name). Task: \(task.rawValue)")
            // Consider resetting selectedTaskCategory here if desired after successful start
            // selectedTaskCategory = nil
        } else {
            showAttendance("Failed to start session. Already active for \(profileToUse.name)?")
        }
    }

    // performToggleBlocking remains largely the same for STOPPING the session
    private func performToggleBlocking(with profileToUse: Profile) {
        let currentlyBlocking = appBlocker.isBlocking

        if currentlyBlocking == false {
            // STARTING Block: Logic moved to sheet's onComplete closure.
             print("ERROR: performToggleBlocking called unexpectedly for STARTING block.")
        } else {
            // STOPPING Block:
            if let currentUser = loginManager.currentUser {
                attendanceManager.logAttendanceEnd(for: profileManager.currentProfile, user: currentUser)
            } else {
                 attendanceManager.logAttendanceEnd(for: profileManager.currentProfile, user: "Unknown") 
                 print("Warning: Could not identify user when logging end time.")
            }
            appBlocker.toggleBlocking(for: profileToUse) 
            showAttendance("See you later")
        }
    }

    private func showAttendance(_ message: String) {
        withAnimation {
            attendanceMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                attendanceMessage = nil
            }
        }
    }
    
    // New async function to handle the button tap logic
    private func handleButtonTap() async {
        await appBlocker.requestAuthorization()
        if appBlocker.isAuthorized {
            if isBlocking {
                // If already blocking, just stop blocking
                if let currentUser = loginManager.currentUser {
                    attendanceManager.logAttendanceEnd(for: profileManager.currentProfile, user: currentUser)
                } else {
                    attendanceManager.logAttendanceEnd(for: profileManager.currentProfile, user: "Unknown")
                }
                appBlocker.toggleBlocking(for: profileManager.currentProfile)
                showAttendance("See you later")
            } else {
                // If starting a session, ensure a task is selected and scan NFC
                if selectedTaskCategory == nil {
                    showTaskSelectionAlert = true
                    return
                }
                scanTag()
            }
        } else {
            // Handle authorization denial
            print("Authorization required to block apps.")
        }
    }
    
    @ViewBuilder
    private func blockOrUnblockButton(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text(isBlocking ? "Tap the screen to unblock" : "Tap and scan to block")
                .font(.caption)
                .opacity(0.75)
                .transition(.scale)
            
            Button(action: {
                Task {
                    await handleButtonTap()
                }
            }) {
                Image(isBlocking ? "RedIcon" : "GreenIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: geometry.size.height * 0.25)
            }
            .transition(.scale)
        }
        .animation(.spring(), value: isBlocking)
    }
    
    // private var createTagButton: some View { ... } // Removed
}

// Add this new view at the end of the file, before the last closing brace
struct TaskCategoryButton: View {
    let category: TaskCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 90, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1),
                   radius: isSelected ? 8 : 4,
                   x: 0,
                   y: 2)
        }
    }
    
    private var iconName: String {
        switch category {
        case .math:
            return "function"
        case .science:
            return "atom"
        case .english:
            return "text.book.closed.fill"
        case .history:
            return "clock.fill"
        case .computerScience:
            return "laptopcomputer"
        case .art:
            return "paintpalette.fill"
        case .music:
            return "music.note"
        case .physicalEducation:
            return "figure.run"
        case .foreignLanguage:
            return "globe"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
}
