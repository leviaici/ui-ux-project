//
//  RegisterViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import FirebaseFirestore
import FirebaseAuth
import Foundation

class RegisterViewViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var birthday = Date()
    
    init() {}
    
    func register(completion: @escaping (Bool) -> Void) {
        guard validate() else {
            completion(false)
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let user = result?.user else {
                completion(false)
                return
            }
            
            // Send email verification
            user.sendEmailVerification { error in
                if let error = error {
                    print("Error sending verification email: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Verification email sent.")
                    completion(true)
                }
            }
            
            // Sign the user out immediately
            do {
                try Auth.auth().signOut()
            } catch {
                print("Error signing out user: \(error.localizedDescription)")
            }
            
            self?.insertUserRecord(id: user.uid)
        }
    }
    
    private func insertUserRecord(id: String) {
        let newUser = User(id: id,
                           email: email,
                           name: name,
                           joined: Date().timeIntervalSince1970,
                           birthday: birthday.timeIntervalSince1970,
                           streak: 0,
                           lastToken: Date().timeIntervalSince1970 - 86400,
                           lastPrompt: "No Insights for tomorrow yet.",
                           gettingThere: 0)
        
        let db = Firestore.firestore()
        db.collection("users").document(id).setData(newUser.asDictionary())
    }
    
    private func validate() -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            return false
        }
        
        guard password.count >= 6 else {
            return false
        }
        
        return true
    }
}
