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
                    Image(systemName: "person.3.fill")
                },
                trailing: loginManager.currentUserRole == .moderator ? createTagButton : nil
            )
            // ... existing alerts ...
        }
        .animation(.spring(), value: isBlocking)
        .sheet(isPresented: $showAttendanceRecords) {
            AttendanceRecordsView()
                .environmentObject(attendanceManager)
        }
    }
    
    // The rest of your functions, including scanTag(), blockOrUnblockButton, etc.
    private func scanTag() {
        nfcReader.scan { payload in
            if payload == tagPhrase {
                let currentlyBlocking = appBlocker.isBlocking
                appBlocker.toggleBlocking(for: profileManager.currentProfile)
                
                if currentlyBlocking == false {
                    // When turning on blocking (class in session), log attendance with the current user.
                    if let currentUser = loginManager.currentUser {
                        attendanceManager.logAttendance(for: profileManager.currentProfile, user: currentUser)
                    } else {
                        // Fallback if user is somehow not set
                        attendanceManager.logAttendance(for: profileManager.currentProfile, user: "Unknown")
                    }
                    showAttendance("Your attendance has been logged!")
                } else {
                    // When unblocking (class is over)
                    showAttendance("Class is over")
                }
            } else {
                showWrongTagAlert = true
                NSLog("Wrong Tag! Payload: \(payload)")
            }
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
    
    @ViewBuilder
    private func blockOrUnblockButton(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text(isBlocking ? "Tap to unblock" : "Tap to block")
                .font(.caption)
                .opacity(0.75)
                .transition(.scale)
            
            Button(action: {
                withAnimation(.spring()) {
                    scanTag()
                }
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
