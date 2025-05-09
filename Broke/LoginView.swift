/**
 * A SwiftUI view responsible for handling user login.
 *
 * This view provides input fields for username and password.
 * It interacts with the `LoginManager` environment object to authenticate the user.
 * Upon successful login, the main application view (`BrokeApp`) transitions to the `BrockerView`.
 * If authentication fails, an error message is displayed.
 */

//
//  LoginView.swift
//  Broke
//
//  Created by Theo Steiger on 2/15/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var loginManager: LoginManager
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginError: String?
    
    var body: some View {
        // Use a ZStack to layer the background color
        ZStack {
            // Use a color from Assets as the background
            // If 'NonBlockingBackground' isn't defined or suitable, fallback to system background
            Color("NonBlockingBackground", bundle: nil).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer() // Push content down slightly
                
                // Add App Icon
                Image("TapInLogo") // Placeholder if AppIcon direct usage is complex
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.bottom, 30)
                
                Text("Welcome to TapIn") // More engaging title
                    .font(.title)
                    .fontWeight(.medium)

                VStack(spacing: 15) { // Group fields
                    // Username Field with Icon
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                        TextField("Username", text: $username)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress) // Common for usernames
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6)) // Use a system background shade
                    .cornerRadius(10)
                    
                    // Password Field with Icon
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                        SecureField("Password", text: $password)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if let error = loginError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 5)
                }
                
                Spacer() // Push login button towards the bottom
                
                Button(action: { // Action in closure
                    if loginManager.login(username: username, password: password) {
                        // Successful login handled by EnvironmentObject change
                    } else {
                        loginError = "Invalid username or password."
                    }
                }) {
                    // Button Label
                    Text("Login")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor) // Use AccentColor
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 3) // Add subtle shadow
                }
                .padding(.horizontal)
                .padding(.bottom, 30) // Add padding at the very bottom
            }
            // Removed the NavigationView as it might not be needed if this is the root view presented modally or within another structure.
            // If navigation IS needed, wrap the ZStack in the NavigationView.
            // .navigationTitle("Login") // Title can be set here if NavigationView is used
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(LoginManager())
    }
}
