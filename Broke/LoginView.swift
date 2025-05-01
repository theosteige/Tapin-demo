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
        NavigationView {
            VStack(spacing: 20) {
                Text("Login")
                    .font(.largeTitle)
                    .padding(.bottom, 40)
                
                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                if let error = loginError {
                    Text(error)
                        .foregroundColor(.red)
                }
                
                Button("Login") {
                    if loginManager.login(username: username, password: password) {
                        // Successful login; the app will now show the main view.
                    } else {
                        loginError = "Invalid username or password."
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(LoginManager())
    }
}
