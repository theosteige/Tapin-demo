//
//  LoginManager.swift
//  Broke
//
//  Created by Theo Steiger on 2/15/25.
//

import SwiftUI

class LoginManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: String?
    
    // Two acceptable dummy credentials:
    private let validCredentials: [String: String] = [
        "user1": "password1",
        "user2": "password2"
    ]
    
    func login(username: String, password: String) -> Bool {
        if let validPassword = validCredentials[username], validPassword == password {
            currentUser = username
            isLoggedIn = true
            return true
        } else {
            return false
        }
    }
    
    func logout() {
        currentUser = nil
        isLoggedIn = false
    }
}

