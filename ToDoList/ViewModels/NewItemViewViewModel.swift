//
//  NewItemViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//  Updated with encryption on 22.04.2025
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

class NewItemViewViewModel: ObservableObject {
    @Published var title = ""
    @Published var dueDate = Date()
    @Published var showAlert = false
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var locationDescription = "no location information"
    @Published var gettingThere: Int = 0 {
        didSet {
            print("gettingThere updated in viewModel: \(gettingThere)")
        }
    }
    @Published var selectedTag: String = "Work"
    @Published var tagColorIndex: Int = 0

    /// Whether the current user is 18 or older. Defaults to false until the
    /// Firestore fetch completes, so the location section stays hidden while loading.
    @Published var isAdult: Bool = false

    init() {
        fetchUserData()
    }

    func save() {
        guard canSave else { return }
        guard let uId = Auth.auth().currentUser?.uid else { return }

        let newId = UUID().uuidString
        let newItem = Item(
            id: newId,
            title: title,
            dueDate: dueDate.timeIntervalSince1970,
            tagName: selectedTag,
            tagColorIndex: tagColorIndex,
            createdDate: Date().timeIntervalSince1970,
            isDone: false,
            recentlyDeleted: false,
            streaked: false,
            latitude: isAdult ? latitude : nil,
            longitude: isAdult ? longitude : nil,
            locationDescription: isAdult ? locationDescription : "no location information",
            gettingThere: gettingThere
        )

        let db = Firestore.firestore()
        db.collection("users")
            .document(uId)
            .collection("todos")
            .document(newId)
            .setData(newItem.asDictionary()) { error in
                if let error = error {
                    print("Error saving new item: \(error.localizedDescription)")
                } else {
                    print("New item saved successfully: \(newItem.title)")
                    NotificationCenter.default.post(name: .newItemAdded, object: nil, userInfo: ["item": newItem])
                }
            }
    }

    // Replaces the old fetchGettingThere() — fetches all needed user fields in one call.
    private func fetchUserData() {
        guard let uId = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore()
            .collection("users")
            .document(uId)
            .getDocument { [weak self] document, error in
                if let error = error {
                    print("Error fetching user data: \(error)")
                    return
                }
                guard let data = document?.data() else {
                    print("User document does not exist")
                    return
                }

                DispatchQueue.main.async {
                    guard let self = self else { return }

                    // Restore the existing gettingThere behaviour
                    if let fetchedGettingThere = data["gettingThere"] as? Int {
                        self.gettingThere = fetchedGettingThere
                    }

                    // Compute isAdult from the stored birthday (TimeInterval)
                    if let birthday = data["birthday"] as? TimeInterval {
                        let birthDate = Date(timeIntervalSince1970: birthday)
                        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
                        self.isAdult = age >= 18
                    }
                    // If birthday is missing (legacy account), treat them as an adult
                    // so existing users are not suddenly locked out of the feature.
                    else {
                        self.isAdult = true
                    }
                }
            }
    }

    var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard dueDate >= Date().addingTimeInterval(-86400) else { return false }
        return true
    }
}
