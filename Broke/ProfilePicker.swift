import SwiftUI
import FamilyControls

struct ClassesPicker: View {
    @EnvironmentObject var loginManager: LoginManager
    @ObservedObject var profileManager: ProfileManager
    @State private var showAddProfileView = false
    @State private var editingProfile: Profile?
    
    private var filteredProfiles: [Profile] {
        guard let currentUser = loginManager.currentUser, let role = loginManager.currentUserRole else {
            return []
        }

        switch role {
        case .moderator:
            return profileManager.profiles.filter { !$0.isDefault }
        case .student:
            return profileManager.profiles.filter { profile in
                guard let assigned = profile.assignedUsernames else { return false }
                return assigned.contains(currentUser)
            }
        }
    }

    var body: some View {
        VStack {
            Text("My Spaces")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                    ForEach(filteredProfiles) { profile in
                        ProfileCell(profile: profile, isSelected: profile.id == profileManager.currentProfileId)
                            .onTapGesture {
                                profileManager.setCurrentProfile(id: profile.id)
                            }
                            .onLongPressGesture {
                                if loginManager.currentUserRole == .moderator {
                                    editingProfile = profile
                                }
                            }
                    }
                    
                    if loginManager.currentUserRole == .moderator {
                        ProfileCellBase(name: "New Space", icon: "plus", appsBlocked: nil, categoriesBlocked: nil, isSelected: false, isDashed: true, hasDivider: false)
                            .onTapGesture {
                                showAddProfileView = true
                            }
                    }
                }
                .padding(.horizontal, 10)
            }
            
            Spacer()
            
            if loginManager.currentUserRole == .moderator {
                Text("Long press on a class to edit...")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.bottom, 8)
            }
        }
        .background(Color("ProfileSectionBackground"))
        .sheet(item: $editingProfile) { profile in
            ProfileFormView(profile: profile, profileManager: profileManager) {
                editingProfile = nil
            }
            .environmentObject(loginManager)
        }
        .sheet(isPresented: $showAddProfileView) {
            ProfileFormView(profileManager: profileManager) {
                showAddProfileView = false
            }
            .environmentObject(loginManager)
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
