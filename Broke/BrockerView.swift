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

struct BrokerView: View {
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var attendanceManager: AttendanceManager
    @EnvironmentObject private var loginManager: LoginManager
    @StateObject private var nfcReader = NFCReader()
    
    // Other state properties...
    private let tagPhrase = "BROKE-IS-GREAT"
    
    @State private var showWrongTagAlert = false
    @State private var showCreateTagAlert = false
    @State private var nfcWriteSuccess = false
    @State private var attendanceMessage: String?
    @State private var showAttendanceRecords = false

    // State for user app selection
    @State private var showUserAppSelection = false
    @State private var userActivitySelection = FamilyActivitySelection()

    // State for task input SHEET
    @State private var showTaskInputSheet = false // Replaces showTaskInputAlert
    // @State private var currentTaskDescription: String = "" // Handled by sheet now
    @State private var currentRecordId: UUID? = nil
    @State private var profileToUseForBlocking: Profile? = nil // Still needed to pass to sheet

    private var isBlocking: Bool {
        appBlocker.isBlocking
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    VStack(spacing: 0) {
                        blockOrUnblockButton(geometry: geometry)
                        
                        if !isBlocking {
                            Divider()
                            
                            // Use the renamed ClassesPicker instead of ProfilesPicker
                            ClassesPicker(profileManager: profileManager)
                                .frame(height: geometry.size.height / 2)
                                .transition(.move(edge: .bottom))
                                .environmentObject(loginManager)
                        }
                    }
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
                        createTagButton
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
                Text("The scanned tag is not a valid Broker tag.")
            }
            .alert("Create Broker Tag?", isPresented: $showCreateTagAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Create") { createBrokerTag() }
            } message: {
                Text("Hold near an NFC tag to make it a Broker tag.")
            }
            .alert("NFC Error", isPresented: $nfcWriteSuccess) { // Assuming nfcWriteSuccess means failure
                Button("OK", role: .cancel) { }
            } message: {
                Text("Failed to write to NFC tag. Ensure it's close and writable.")
            }
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
        // Add sheet for task input
        .sheet(isPresented: $showTaskInputSheet) {
             // Ensure we have the necessary data before presenting
             if let recordId = currentRecordId, let profile = profileToUseForBlocking {
                 TaskInputSheet(
                     isPresented: $showTaskInputSheet,
                     recordIdToUpdate: recordId,
                     profileToUse: profile,
                     onComplete: { taskDescription in
                         // This closure is called by the sheet when done
                         appBlocker.toggleBlocking(for: profile) // Perform blocking
                         showAttendance("Session started. Task: \(taskDescription ?? "None")")
                         // Reset state after sheet dismissal
                         currentRecordId = nil
                         profileToUseForBlocking = nil
                     }
                 )
                 .environmentObject(attendanceManager) // Pass needed environment objects
                 .environmentObject(appBlocker)
             } else {
                  // Handle error case where sheet is triggered without necessary data
                  // This shouldn't happen with the current logic, but good to have a fallback
                  Text("Error presenting task input. Please try again.")
                     .onAppear { showTaskInputSheet = false } // Dismiss immediately
             }
        }
    }
    
    // The rest of your functions, including scanTag(), blockOrUnblockButton, etc.
    private func scanTag() {
        nfcReader.scan { payload in
            if payload == tagPhrase {
                handleValidScan()
            } else {
                showWrongTagAlert = true
                NSLog("Wrong Tag! Payload: \(payload)")
            }
        }
    }

    private func handleValidScan() {
        let currentlyBlocking = appBlocker.isBlocking
        let profile = profileManager.currentProfile

        if currentlyBlocking == false { // STARTING session
            if profile.userSelectsApps == true && loginManager.currentUserRole == .student {
                // User needs to select apps first
                userActivitySelection = FamilyActivitySelection()
                userActivitySelection.applicationTokens = profile.appTokens
                userActivitySelection.categoryTokens = profile.categoryTokens
                showUserAppSelection = true // This will trigger handleUserAppSelectionDone
            } else {
                // No user app selection needed, proceed directly to task input/blocking
                prepareAndStartBlocking(with: profile)
            }
        } else { // STOPPING session
            // Just unblock. No user app selection or task input needed.
            performToggleBlocking(with: profile)
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

    // New function to handle logic before showing task sheet
    private func prepareAndStartBlocking(with profileToUse: Profile) {
         if let currentUser = loginManager.currentUser {
            currentRecordId = attendanceManager.logAttendanceStart(for: profileManager.currentProfile, user: currentUser)
             if currentRecordId != nil {
                 profileToUseForBlocking = profileToUse
                 // Show task input SHEET
                 showTaskInputSheet = true // Changed from showTaskInputAlert
             } else {
                 showAttendance("Failed to start session. Already active?")
             }
        } else {
             showAttendance("Error: Could not identify user.")
             // attendanceManager.logAttendanceStart(for: profileManager.currentProfile, user: "Unknown") 
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
                // Move Task outside withAnimation
                // The animations should still work due to state changes
                Task {
                    await handleButtonTap()
                }
                // Apply animation to any immediate synchronous UI changes if needed,
                // but the Task itself runs separately.
                // If no immediate changes, withAnimation might not be needed here.
                // withAnimation(.spring()) {}
            }) {
                Image(isBlocking ? "RedIcon" : "GreenIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: geometry.size.height / 3)
            }
            .transition(.scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: isBlocking ? geometry.size.height : geometry.size.height / 2)
        .animation(.spring(), value: isBlocking)
    }
    
    private var createTagButton: some View {
        Button(action: {
            showCreateTagAlert = true
        }) {
            Image(systemName: "plus")
        }
        .disabled(!NFCNDEFReaderSession.readingAvailable)
    }
    
    private func createBrokerTag() {
        nfcReader.write(tagPhrase) { success in
            nfcWriteSuccess = !success
            showCreateTagAlert = false
        }
    }
}
