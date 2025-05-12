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
                                Section { // Using Section for grouping and potential header
                                    Picker("Select Task", selection: $selectedTaskCategory) {
                                        Text("-- Select Task --").tag(nil as TaskCategory?)
                                        ForEach(TaskCategory.allCases) { category in
                                            Text(category.rawValue).tag(category as TaskCategory?)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .pickerStyle(.menu) // Use a more compact picker style
                                
                                // Add ClassesPicker only for moderators
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
                if loginManager.currentUserRole == .student {
                    Text("You are not assigned to this space or the tag is invalid.")
                } else {
                    Text("The scanned tag is not a valid Broker space tag or is unassigned.")
                }
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
        // Add sheet for task input - REMOVED
        // .sheet(isPresented: $showTaskInputSheet) {
        //      // Ensure we have the necessary data before presenting
        //      if let recordId = currentRecordId, let profile = profileToUseForBlocking {
        //          TaskInputSheet(
        //              isPresented: $showTaskInputSheet,
        //              recordIdToUpdate: recordId,
        //              profileToUse: profile,
        //              onComplete: { taskDescription in
        //                  // This closure is called by the sheet when done
        //                  appBlocker.toggleBlocking(for: profile) // Perform blocking
        //                  showAttendance("Session started. Task: \\(taskDescription ?? "None")")
        //                  // Reset state after sheet dismissal
        //                  currentRecordId = nil
        //                  profileToUseForBlocking = nil
        //              }
        //          )
        //          .environmentObject(attendanceManager) // Pass needed environment objects
        //          .environmentObject(appBlocker)
        //      } else {
        //           // Handle error case where sheet is triggered without necessary data
        //           // This shouldn't happen with the current logic, but good to have a fallback
        //           Text("Error presenting task input. Please try again.")
        //              .onAppear { showTaskInputSheet = false } // Dismiss immediately
        //      }
        // }
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

        // Check if user is assigned to this space (for students)
        if loginManager.currentUserRole == .student {
            guard let currentUser = loginManager.currentUser,
                  let assignedUsers = profile.assignedUsernames,
                  assignedUsers.contains(currentUser) else {
                showWrongTagAlert = true
                NSLog("Student \(loginManager.currentUser ?? "unknown") not assigned to space \(profile.name)")
                return
            }
        }

        // Display the "Tapped into" message
        showAttendance("Tapped into: \(profile.name)")

        // Delay further actions slightly to allow the user to see the "Tapped into" message.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Adjust delay as needed
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
            showAttendance("Session started for \\(profileToUse.name). Task: \\(task.rawValue)")
            // Consider resetting selectedTaskCategory here if desired after successful start
            // selectedTaskCategory = nil
        } else {
            showAttendance("Failed to start session. Already active for \\(profileToUse.name)?")
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
            // If starting a session, ensure a task is selected
            if !isBlocking && selectedTaskCategory == nil {
                showTaskSelectionAlert = true
                return
            }
            scanTag()
        } else {
            // Handle authorization denial (e.g., show alert)
            print("Authorization required to block apps.")
            // You might want to show an alert here
        }
    }
    
    @ViewBuilder
    private func blockOrUnblockButton(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text(isBlocking ? "Tap to unblock" : "Tap to block")
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
                    // Make the logo smaller
                    .frame(height: geometry.size.height * 0.25) // Reduced size, e.g., 25% of screen height
            }
            .transition(.scale)
        }
        // This VStack (for the button content) should center itself based on parent spacers
        // No need for .frame(maxWidth: .infinity, maxHeight: .infinity) here anymore
        .animation(.spring(), value: isBlocking)
    }
    
    // private var createTagButton: some View { ... } // Removed
}
