//
//  ProfilePicker.swift
//  Broke
//
//  Created by Oz Tamir on 23/08/2024.
//

//import SwiftUI
//import FamilyControls
//
//struct ProfilesPicker: View { // Renamed from ProfilesPicker to ClassesPicker
//    @ObservedObject var profileManager: ProfileManager
//    @State private var showAddProfileView = false
//    @State private var editingProfile: Profile?
//    
//    var body: some View {
//        VStack {
//            Text("Classes") // Changed header from "Profiles" to "Classes"
//                .font(.headline)
//                .padding(.horizontal)
//                .padding(.top)
//            
//            ScrollView {
//                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
//                    // Filter out default profiles if they exist
//                    ForEach(profileManager.profiles.filter { !$0.isDefault }) { profile in
//                        ProfileCell(profile: profile, isSelected: profile.id == profileManager.currentProfileId)
//                            .onTapGesture {
//                                profileManager.setCurrentProfile(id: profile.id)
//                            }
//                            .onLongPressGesture {
//                                editingProfile = profile
//                            }
//                    }
//                    
//                    // New cell for creating a new class (profile)
//                    ProfileCellBase(name: "New Class", icon: "plus", appsBlocked: nil, categoriesBlocked: nil, isSelected: false, isDashed: true, hasDivider: false)
//                        .onTapGesture {
//                            showAddProfileView = true
//                        }
//                }
//                .padding(.horizontal, 10)
//            }
//            
//            Spacer()
//            
//            Text("Long press on a class to edit...")
//                .font(.caption2)
//                .foregroundColor(.secondary.opacity(0.7))
//                .padding(.bottom, 8)
//        }
//        .background(Color("ProfileSectionBackground"))
//        .sheet(item: $editingProfile) { profile in
//            ProfileFormView(profile: profile, profileManager: profileManager) {
//                editingProfile = nil
//            }
//        }
//        .sheet(isPresented: $showAddProfileView) {
//            ProfileFormView(profileManager: profileManager) {
//                showAddProfileView = false
//            }
//        }
//    }
//}
//
//struct ProfileCellBase: View {
//    let name: String
//    let icon: String
//    let appsBlocked: Int?
//    let categoriesBlocked: Int?
//    let isSelected: Bool
//    var isDashed: Bool = false
//    var hasDivider: Bool = true
//
//    var body: some View {
//        VStack(spacing: 4) {
//            Image(systemName: icon)
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(width: 30, height: 30)
//            if hasDivider {
//                Divider().padding(2)
//            }
//            Text(name)
//                .font(.caption)
//                .fontWeight(.medium)
//                .lineLimit(1)
//            
//            if let apps = appsBlocked, let categories = categoriesBlocked {
//                Text("A: \(apps) | C: \(categories)")
//                    .font(.system(size: 10))
//            }
//        }
//        .frame(width: 90, height: 90)
//        .padding(2)
//        .background(isSelected ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2))
//        .cornerRadius(8)
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(
//                    isSelected ? Color.blue : (isDashed ? Color.secondary : Color.clear),
//                    style: StrokeStyle(lineWidth: 2, dash: isDashed ? [5] : [])
//                )
//        )
//    }
//}
//
//struct ProfileCell: View {
//    let profile: Profile
//    let isSelected: Bool
//
//    var body: some View {
//        ProfileCellBase(
//            name: profile.name,
//            icon: profile.icon,
//            appsBlocked: profile.appTokens.count,
//            categoriesBlocked: profile.categoryTokens.count,
//            isSelected: isSelected
//        )
//    }
//}

//
//  ClassesPicker.swift
//  Broke
//
//  Created by Oz Tamir on 23/08/2024.
//

import SwiftUI
import FamilyControls

struct ClassesPicker: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var showAddProfileView = false
    @State private var editingProfile: Profile?
    
    var body: some View {
        VStack {
            // Update the header label to "Classes"
            Text("Classes")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            ScrollView {
                // Use a LazyVGrid to display all classes.
                // We no longer filter out the default profile because
                // we don't want a default class to appear.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                    ForEach(profileManager.profiles) { profile in
                        // Each cell represents a class (previously a profile)
                        ProfileCell(profile: profile, isSelected: profile.id == profileManager.currentProfileId)
                            .onTapGesture {
                                profileManager.setCurrentProfile(id: profile.id)
                            }
                            .onLongPressGesture {
                                editingProfile = profile
                            }
                    }
                    
                    // Create a new cell for adding a new class.
                    ProfileCellBase(name: "New Class", icon: "plus", appsBlocked: nil, categoriesBlocked: nil, isSelected: false, isDashed: true, hasDivider: false)
                        .onTapGesture {
                            showAddProfileView = true
                        }
                }
                .padding(.horizontal, 10)
            }
            
            Spacer()
            
            // Update instructional text to reference "class" instead of "profile"
            Text("Long press on a class to edit...")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 8)
        }
        .background(Color("ProfileSectionBackground"))
        // The sheet that appears when editing an existing class.
        .sheet(item: $editingProfile) { profile in
            ProfileFormView(profile: profile, profileManager: profileManager) {
                editingProfile = nil
            }
        }
        // The sheet that appears when adding a new class.
        .sheet(isPresented: $showAddProfileView) {
            ProfileFormView(profileManager: profileManager) {
                showAddProfileView = false
            }
        }
    }
}

// MARK: - Reusable Cell Views

struct ProfileCellBase: View {
    let name: String
    let icon: String
    let appsBlocked: Int?
    let categoriesBlocked: Int?
    let isSelected: Bool
    var isDashed: Bool = false
    var hasDivider: Bool = true

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
            if hasDivider {
                Divider().padding(2)
            }
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            if let apps = appsBlocked, let categories = categoriesBlocked {
                Text("A: \(apps) | C: \(categories)")
                    .font(.system(size: 10))
            }
        }
        .frame(width: 90, height: 90)
        .padding(2)
        .background(isSelected ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.blue : (isDashed ? Color.secondary : Color.clear),
                    style: StrokeStyle(lineWidth: 2, dash: isDashed ? [5] : [])
                )
        )
    }
}

struct ProfileCell: View {
    let profile: Profile
    let isSelected: Bool

    var body: some View {
        ProfileCellBase(
            name: profile.name,
            icon: profile.icon,
            appsBlocked: profile.appTokens.count,
            categoriesBlocked: profile.categoryTokens.count,
            isSelected: isSelected
        )
    }
}
