/**
 * A SwiftUI view presented as a sheet for creating or editing profiles (Classes/Spaces).
 *
 * This view provides a form to configure various aspects of a profile:
 * - Profile name.
 * - Profile icon selection using `SFSymbolsPicker`.
 * - Assignment of student usernames (for moderators).
 * - Configuration of blocked apps and categories using `FamilyActivityPicker`.
 * - A toggle to determine if students can select their own apps for this profile.
 * - Deletion functionality for existing profiles (with confirmation).
 *
 * It interacts with `ProfileManager` to save or update profile data and calls an `onDismiss`
 * closure upon completion or cancellation.
 */

//
//  EditProfileView.swift
//  Broke
//
//  Created by Oz Tamir on 23/08/2024.
//

import SwiftUI
import SFSymbolsPicker
import FamilyControls
import CoreNFC

struct ProfileFormView: View {
    @EnvironmentObject var loginManager: LoginManager
    @ObservedObject var profileManager: ProfileManager
    @StateObject private var nfcReader = NFCReader()
    @State private var profileName: String
    @State private var profileIcon: String
    @State private var assignedUsernamesString: String
    @State private var showSymbolsPicker = false
    @State private var showAppSelection = false
    @State private var activitySelection: FamilyActivitySelection
    @State private var showDeleteConfirmation = false
    @State private var userCanSelectApps: Bool
    @State private var nfcTagIDString: String
    @State private var showNFCAssignAlert = false
    @State private var nfcWriteErrorAlert = false
    @State private var nfcStatusMessage: String = "No NFC tag assigned."
    let profile: Profile?
    let onDismiss: () -> Void
    
    init(profile: Profile? = nil, profileManager: ProfileManager, onDismiss: @escaping () -> Void) {
        self.profile = profile
        self.profileManager = profileManager
        self.onDismiss = onDismiss
        _profileName = State(initialValue: profile?.name ?? "")
        _profileIcon = State(initialValue: profile?.icon ?? "bell.slash")
        _assignedUsernamesString = State(initialValue: profile?.assignedUsernames?.joined(separator: ", ") ?? "")
        _userCanSelectApps = State(initialValue: profile?.userSelectsApps ?? false)
        _nfcTagIDString = State(initialValue: profile?.nfcTagID ?? "")
        
        if let tagId = profile?.nfcTagID, !tagId.isEmpty {
            _nfcStatusMessage = State(initialValue: "Tag ID: \(tagId)")
        } else {
            _nfcStatusMessage = State(initialValue: "No NFC tag assigned.")
        }

        var selection = FamilyActivitySelection()
        selection.applicationTokens = profile?.appTokens ?? []
        selection.categoryTokens = profile?.categoryTokens ?? []
        _activitySelection = State(initialValue: selection)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Class Details")) {
                    VStack(alignment: .leading) {
                        Text("Class Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter class name", text: $profileName)
                    }
                    
                    Button(action: { showSymbolsPicker = true }) {
                        HStack {
                            Image(systemName: profileIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Text("Choose Icon")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("NFC Tag Assignment")) {
                    Text(nfcStatusMessage)
                        .font(.caption)
                        .foregroundColor(nfcTagIDString.isEmpty ? .secondary : .primary)
                    
                    Button(action: {
                        assignNFCTag()
                    }) {
                        Text(nfcTagIDString.isEmpty ? "Assign NFC Tag to this Space" : "Re-assign NFC Tag")
                    }
                    .disabled(!nfcReaderFeatureAvailable)
                }
                
                if loginManager.currentUserRole == .moderator {
                    Section(header: Text("Assign Students")) {
                        VStack(alignment: .leading) {
                            Text("Assigned Usernames (comma-separated)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("user1, user2, ...", text: $assignedUsernamesString)
                                .autocapitalization(.none)
                        }
                    }
                }
                
                Section(header: Text("App Configuration")) {
                    Toggle("Allow students to choose blocked apps", isOn: $userCanSelectApps)
                        .padding(.vertical, 4)
                    
                    Button(action: { showAppSelection = true }) {
                        Text(userCanSelectApps ? "Configure Default Blocked Apps" : "Configure Blocked Apps")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Blocked Apps:")
                            Spacer()
                            Text("\(activitySelection.applicationTokens.count)")
                                .fontWeight(.bold)
                        }
                        HStack {
                            Text("Blocked Categories:")
                            Spacer()
                            Text("\(activitySelection.categoryTokens.count)")
                                .fontWeight(.bold)
                        }
                        Text("Broke can't list the names of the apps due to privacy concerns, it is only able to see the amount of apps selected in the configuration screen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if profile != nil {
                    Section {
                        Button(action: { showDeleteConfirmation = true }) {
                            Text("Delete Class")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(profile == nil ? "Add Class" : "Edit Class")
            .navigationBarItems(
                leading: Button("Cancel", action: onDismiss),
                trailing: Button("Save", action: handleSave)
                    .disabled(profileName.isEmpty)
            )
            .sheet(isPresented: $showSymbolsPicker) {
                SymbolsPicker(selection: $profileIcon, title: "Pick an icon", autoDismiss: true)
            }
            .sheet(isPresented: $showAppSelection) {
                NavigationView {
                    FamilyActivityPicker(selection: $activitySelection)
                        .navigationTitle("Select Apps")
                        .navigationBarItems(trailing: Button("Done") {
                            showAppSelection = false
                        })
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Class"),
                    message: Text("Are you sure you want to delete this class?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let profile = profile {
                            profileManager.deleteProfile(withId: profile.id)
                        }
                        onDismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert("NFC Tag Operation", isPresented: $showNFCAssignAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Hold your iPhone near an NFC tag to assign it to this space. A unique ID will be written to the tag.")
            }
            .alert("NFC Write Error", isPresented: $nfcWriteErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Failed to write to NFC tag. Please ensure the tag is close and writable.")
            }
        }
    }
    
    private var nfcReaderFeatureAvailable: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return NFCNDEFReaderSession.readingAvailable
        #endif
    }
    
    private func assignNFCTag() {
        guard nfcReaderFeatureAvailable else {
            nfcStatusMessage = "NFC writing is not available on this device."
            return
        }

        let newTagID = "BROKE-SPACE-\(UUID().uuidString)"
        showNFCAssignAlert = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            nfcReader.write(newTagID) { success in
                showNFCAssignAlert = false
                if success {
                    nfcTagIDString = newTagID
                    nfcStatusMessage = "Tag ID: \(newTagID)"
                    print("Successfully wrote NFC Tag ID: \(newTagID)")
                } else {
                    nfcWriteErrorAlert = true
                    nfcStatusMessage = "Failed to assign NFC tag."
                    print("Failed to write NFC Tag ID: \(newTagID)")
                }
            }
        }
    }
    
    private func handleSave() {
        let usernames = assignedUsernamesString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let existingProfile = profile {
            profileManager.updateProfile(
                id: existingProfile.id,
                name: profileName,
                appTokens: activitySelection.applicationTokens,
                categoryTokens: activitySelection.categoryTokens,
                icon: profileIcon,
                assignedUsernames: usernames,
                userSelectsApps: userCanSelectApps,
                nfcTagID: nfcTagIDString.isEmpty ? nil : nfcTagIDString
            )
        } else {
            let newProfile = Profile(
                name: profileName,
                appTokens: activitySelection.applicationTokens,
                categoryTokens: activitySelection.categoryTokens,
                icon: profileIcon,
                assignedUsernames: usernames,
                userSelectsApps: userCanSelectApps,
                nfcTagID: nfcTagIDString.isEmpty ? nil : nfcTagIDString
            )
            profileManager.addProfile(newProfile: newProfile)
        }
        onDismiss()
    }
}

