//
//  LoginManager.swift
//  Broke
//
//  Created by Theo Steiger on 2/15/25.
//

import SwiftUI

// Define User Roles
enum UserRole {
    case moderator, student
}

class LoginManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: String?
    @Published var currentUserRole: UserRole? // Added user role
    
    // Define moderator credentials separately
    private let moderatorCredentials: [String: String] = [
        "moderator": "modpassword"
    ]
    
    // Regular user credentials
    private let studentCredentials: [String: String] = [
        "user1": "password1",
        "user2": "password2"
    ]
    
    func login(username: String, password: String) -> Bool {
        // Check moderator credentials
        if let validPassword = moderatorCredentials[username], validPassword == password {
            currentUser = username
            currentUserRole = .moderator // Set role to moderator
            isLoggedIn = true
            return true
        // Check student credentials
        } else if let validPassword = studentCredentials[username], validPassword == password {
            currentUser = username
            currentUserRole = .student // Set role to student
            isLoggedIn = true
            return true
        } else {
            // Invalid credentials
            currentUser = nil
            currentUserRole = nil
            isLoggedIn = false
            return false
        }
    }
    
    func logout() {
        currentUser = nil
        currentUserRole = nil // Clear role on logout
        isLoggedIn = false
    }
}

