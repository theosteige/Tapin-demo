/**
 * Defines the data structure for a blocking profile (`Profile`)
 * and manages the collection of profiles (`ProfileManager`).
 *
 * `Profile` struct:
 *  - Represents a specific configuration for app blocking, including name, icon,
 *    blocked application/category tokens, assigned usernames, and whether users
 *    can select their own apps.
 *
 * `ProfileManager` class (ObservableObject):
 *  - Manages the lifecycle of `Profile` objects.
 *  - Loads profiles from and saves profiles to `UserDefaults`.
 *  - Ensures a default profile exists.
 *  - Tracks the currently selected profile (`currentProfileId`).
 *  - Provides methods for adding, updating, deleting, and selecting profiles.
 */

//
//  ProfileManager.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024. Edited by Theo on 02/13/25
//

import Foundation
import FamilyControls
import ManagedSettings

class ProfileManager: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var currentProfileId: UUID?
    
    init() {
        loadProfiles()
        ensureDefaultProfile()
    }
    
    var currentProfile: Profile {
        (profiles.first(where: { $0.id == currentProfileId }) ?? profiles.first(where: { $0.name == "Default" }))!
    }
    
    func loadProfiles() {
        if let savedProfiles = UserDefaults.standard.data(forKey: "savedProfiles"),
           let decodedProfiles = try? JSONDecoder().decode([Profile].self, from: savedProfiles) {
            profiles = decodedProfiles
        } else {
            // Create a default profile if no profiles are saved
            let defaultProfile = Profile(name: "Default", appTokens: [], categoryTokens: [], icon: "bell.slash")
            profiles = [defaultProfile]
            currentProfileId = defaultProfile.id
        }
        
        // Ensure all loaded profiles have the userSelectsApps field (defaulting to false if missing)
        profiles = profiles.map { profile in
            var mutableProfile = profile
            if mutableProfile.userSelectsApps == nil {
                mutableProfile.userSelectsApps = false
            }
            return mutableProfile
        }

        if let savedProfileId = UserDefaults.standard.string(forKey: "currentProfileId"),
           let uuid = UUID(uuidString: savedProfileId) {
            currentProfileId = uuid
            NSLog("Found currentProfile: \(uuid)")
        } else {
            currentProfileId = profiles.first?.id
            NSLog("No stored ID, using \(currentProfileId?.uuidString ?? "NONE")")
        }
    }
    
    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: "savedProfiles")
        }
        UserDefaults.standard.set(currentProfileId?.uuidString, forKey: "currentProfileId")
    }
    
    func addProfile(name: String, icon: String = "bell.slash", nfcTagID: String? = nil) {
        let newProfile = Profile(name: name, appTokens: [], categoryTokens: [], icon: icon, userSelectsApps: false, nfcTagID: nfcTagID)
        profiles.append(newProfile)
        currentProfileId = newProfile.id
        saveProfiles()
    }
    
    func addProfile(newProfile: Profile) {
        profiles.append(newProfile)
        currentProfileId = newProfile.id
        saveProfiles()
    }
    
    func updateCurrentProfile(appTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>) {
        if let index = profiles.firstIndex(where: { $0.id == currentProfileId }) {
            profiles[index].appTokens = appTokens
            profiles[index].categoryTokens = categoryTokens
            saveProfiles()
        }
    }
    
    func setCurrentProfile(id: UUID) {
        if profiles.contains(where: { $0.id == id }) {
            currentProfileId = id
            NSLog("New Current Profile: \(id)")
            saveProfiles()
        }
    }
    
    func deleteProfile(withId id: UUID) {
//        guard !profiles.first(where: { $0.id == id })?.isDefault ?? false else {
//            // Don't delete the default profile
//            return
//        }
        
        profiles.removeAll { $0.id == id }
        
        if currentProfileId == id {
            currentProfileId = profiles.first?.id
        }
        
        saveProfiles()
    }

    func deleteAllNonDefaultProfiles() {
        profiles.removeAll { !$0.isDefault }
        
        if !profiles.contains(where: { $0.id == currentProfileId }) {
            currentProfileId = profiles.first?.id
        }
        
        saveProfiles()
    }
    
    func updateCurrentProfile(name: String, iconName: String) {
        if let index = profiles.firstIndex(where: { $0.id == currentProfileId }) {
            profiles[index].name = name
            profiles[index].icon = iconName
            saveProfiles()
        }
    }

    func deleteCurrentProfile() {
        profiles.removeAll { $0.id == currentProfileId }
        if let firstProfile = profiles.first {
            currentProfileId = firstProfile.id
        }
        saveProfiles()
    }
    
    func updateProfile(
        id: UUID,
        name: String? = nil,
        appTokens: Set<ApplicationToken>? = nil,
        categoryTokens: Set<ActivityCategoryToken>? = nil,
        icon: String? = nil,
        assignedUsernames: [String]? = nil,
        userSelectsApps: Bool? = nil,
        nfcTagID: String? = nil
    ) {
        if let index = profiles.firstIndex(where: { $0.id == id }) {
            if let name = name {
                profiles[index].name = name
            }
            if let appTokens = appTokens {
                profiles[index].appTokens = appTokens
            }
            if let categoryTokens = categoryTokens {
                profiles[index].categoryTokens = categoryTokens
            }
            if let icon = icon {
                profiles[index].icon = icon
            }
            if let assignedUsernames = assignedUsernames {
                profiles[index].assignedUsernames = assignedUsernames
            }
            if let userSelectsApps = userSelectsApps {
                profiles[index].userSelectsApps = userSelectsApps
            }
            if nfcTagID != nil {
                profiles[index].nfcTagID = nfcTagID
            } else if name != nil || appTokens != nil || categoryTokens != nil || icon != nil || assignedUsernames != nil || userSelectsApps != nil {
                // If other fields are being updated, but nfcTagID is not explicitly passed (remains nil from signature),
                // we don't want to accidentally wipe an existing nfcTagID. So only update nfcTagID if it's explicitly part of the update.
                // However, if the intention IS to clear it, the caller should pass an empty string or a specific marker.
                // For this iteration, if nfcTagID parameter is nil, we preserve the existing value.
                // This else-if block is a bit complex. A better approach might be to have a separate function to update *only* nfcTagID
                // or make the update more explicit about clearing.
                // For now, we only set nfcTagID if the nfcTagID parameter is not nil.
            }
            
            if currentProfileId == id {
                currentProfileId = profiles[index].id
            }
            
            saveProfiles()
        }
    }
    
    private func ensureDefaultProfile() {
        if profiles.isEmpty {
            let defaultProfile = Profile(name: "Default", appTokens: [], categoryTokens: [], icon: "bell.slash", userSelectsApps: false, nfcTagID: nil)
            profiles.append(defaultProfile)
            currentProfileId = defaultProfile.id
            saveProfiles()
        } else if currentProfileId == nil {
            if let defaultProfile = profiles.first(where: { $0.name == "Default" }) {
                currentProfileId = defaultProfile.id
            } else {
                currentProfileId = profiles.first?.id
            }
            saveProfiles()
        }
    }
}

struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var appTokens: Set<ApplicationToken>
    var categoryTokens: Set<ActivityCategoryToken>
    var icon: String // New property for icon
    var assignedUsernames: [String]? // Added field for assigned usernames
    var userSelectsApps: Bool? = false // NEW: Determines who selects apps (default false)
    var nfcTagID: String? // Unique ID of the NFC tag associated with this profile

    var isDefault: Bool {
        name == "Default"
    }

    // New initializer to support default icon and assignedUsernames
    init(name: String, appTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>, icon: String = "bell.slash", assignedUsernames: [String]? = nil, userSelectsApps: Bool? = false, nfcTagID: String? = nil) { // Added assignedUsernames and userSelectsApps
        self.id = UUID()
        self.name = name
        self.appTokens = appTokens
        self.categoryTokens = categoryTokens
        self.icon = icon
        self.assignedUsernames = assignedUsernames // Initialize assignedUsernames
        self.userSelectsApps = userSelectsApps ?? false // Initialize userSelectsApps, defaulting to false
        self.nfcTagID = nfcTagID // Initialize nfcTagID
    }
}
