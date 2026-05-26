//
//  LoginViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import FirebaseAuth
import Foundation
import SwiftUI

class LoginViewViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage = ""
    @Published var showAlert = false

    init() {}

    func login() {
        guard validate() else {
            self.showAlert = true
            return
        }
        
        // Attempt to log in
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = "Login failed: \(error.localizedDescription)"
                self?.showAlert = true
            } else if let user = result?.user, !user.isEmailVerified {
                // If the user is not verified, show error and sign them out
                self?.errorMessage = "Please verify your email before logging in."
                self?.showAlert = true
                // Sign the user out to prevent access
                try? Auth.auth().signOut()
            }
        }
    }
    
    private func validate() -> Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "You forgot one empty field."
            return false
        }

        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Enter a valid email address."
            return false
        }
        
        return true
    }
    
    func reset(email: String) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                self.errorMessage = "Error: \(error.localizedDescription)"
            } else {
                self.errorMessage = "Password reset email sent successfully!"
            }
            self.showAlert = true
        }
    }
    
    func resendVerificationEmail(email: String) {
        // First, try to sign in temporarily to get the user object
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = "Unable to resend verification: \(error.localizedDescription)"
                self?.showAlert = true
                return
            }
            
            guard let user = result?.user else {
                self?.errorMessage = "Unable to find user account."
                self?.showAlert = true
                return
            }
            
            // Send verification email
            user.sendEmailVerification { error in
                if let error = error {
                    self?.errorMessage = "Failed to send verification email: \(error.localizedDescription)"
                } else {
                    self?.errorMessage = "Verification email sent successfully! Please check your inbox."
                }
                self?.showAlert = true
                
                // Sign out the user since they haven't verified yet
                try? Auth.auth().signOut()
            }
        }
    }
}
