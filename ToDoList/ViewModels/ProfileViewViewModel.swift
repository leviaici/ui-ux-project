//
//  ProfileViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

class ProfileViewViewModel: ObservableObject {
    @Published var user: User? = nil
    @Published var gettingThere: Int = 0
    @Published var streak: Int = 0

    init() {}

    /// Computed from the already-loaded user — no extra Firestore call needed.
    var isAdult: Bool {
        guard let birthday = user?.birthday else { return true }
        // Legacy account (birthday == 0) — treat as adult so existing users
        // are not suddenly locked out of the feature.
        guard birthday > 0 else { return true }
        let age = Calendar.current.dateComponents([.year], from: Date(timeIntervalSince1970: birthday), to: Date()).year ?? 0
        return age >= 18
    }

    func fetch() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .getDocument { [weak self] snapshot, error in
                guard let data = snapshot?.data(), error == nil else { return }
                DispatchQueue.main.async {
                    self?.user = User(
                        id: data["id"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        name: data["name"] as? String ?? "",
                        joined: data["joined"] as? TimeInterval ?? 0,
                        birthday: data["birthday"] as? TimeInterval ?? 0,
                        streak: data["streak"] as? Int ?? 0,
                        lastToken: data["lastToken"] as? TimeInterval ?? 0,
                        lastPrompt: data["lastPrompt"] as? String ?? "No Insights for tomorrow yet.",
                        gettingThere: data["gettingThere"] as? Int ?? 0
                    )
                    self?.gettingThere = data["gettingThere"] as? Int ?? 0
                    self?.streak = data["streak"] as? Int ?? 0
                }
            }
    }

    func updateGettingThere() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .setData(["gettingThere": user!.gettingThere], merge: true)
    }

    func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print(error)
        }
    }

    func deleteAccount() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        db.collection("todos")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching todo items: \(error)")
                    dispatchGroup.leave()
                    return
                }

                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    print("No todo items found")
                    dispatchGroup.leave()
                    return
                }

                let todosBatch = db.batch()
                for document in documents {
                    todosBatch.deleteDocument(document.reference)
                }

                todosBatch.commit { error in
                    if let error = error {
                        print("Error deleting todo items: \(error)")
                    } else {
                        print("Successfully deleted \(documents.count) todo items")
                    }
                    dispatchGroup.leave()
                }
            }

        dispatchGroup.enter()
        db.collection("userPreferences").document(userId).delete { error in
            if let error = error { print("Error deleting user preferences: \(error)") }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        db.collection("users").document(userId).delete { error in
            if let error = error { print("Error deleting user data: \(error)") }
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            Auth.auth().currentUser?.delete { error in
                if let error = error {
                    print("Error deleting user account: \(error)")
                } else {
                    print("User account successfully deleted")
                }
            }
        }
    }

    func updateUserName(newName: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore()
            .collection("users")
            .document(userId)
            .setData(["name": newName], merge: true) { [weak self] error in
                if let error = error {
                    print("Error updating name: \(error)")
                } else if let currentUser = self?.user {
                    DispatchQueue.main.async {
                        self?.user = User(
                            id: currentUser.id,
                            email: currentUser.email,
                            name: newName,
                            joined: currentUser.joined,
                            birthday: currentUser.birthday,
                            streak: currentUser.streak,
                            lastToken: currentUser.lastToken,
                            lastPrompt: currentUser.lastPrompt,
                            gettingThere: currentUser.gettingThere
                        )
                    }
                }
            }
    }

    func updateUserEmail(newEmail: String, currentPassword: String, completion: @escaping (Bool, String) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(false, "No user is currently logged in")
            return
        }

        let credential = EmailAuthProvider.credential(withEmail: user?.email ?? "", password: currentPassword)

        currentUser.reauthenticate(with: credential) { [weak self] _, error in
            if let error = error {
                completion(false, "Authentication failed: \(error.localizedDescription)")
                return
            }

            currentUser.updateEmail(to: newEmail) { error in
                if let error = error {
                    completion(false, "Error updating email: \(error.localizedDescription)")
                    return
                }

                let userId = currentUser.uid

                Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .setData(["email": newEmail], merge: true) { error in
                        if let error = error {
                            print("Error updating email in database: \(error)")
                            completion(false, "Error updating database record")
                            return
                        }

                        if let currentUser = self?.user {
                            DispatchQueue.main.async {
                                self?.user = User(
                                    id: currentUser.id,
                                    email: newEmail,
                                    name: currentUser.name,
                                    joined: currentUser.joined,
                                    birthday: currentUser.birthday,
                                    streak: currentUser.streak,
                                    lastToken: currentUser.lastToken,
                                    lastPrompt: currentUser.lastPrompt,
                                    gettingThere: currentUser.gettingThere
                                )
                            }
                        }

                        completion(true, "Email updated successfully")
                    }
            }
        }
    }

    func sendPasswordResetEmail() -> Bool {
        guard let email = user?.email, !email.isEmpty else { return false }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error { print("Error sending password reset: \(error)") }
        }
        return true
    }
}
