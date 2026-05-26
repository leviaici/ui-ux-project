//
//  ModifyItemViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 07.09.2023.
//  Updated with encryption on 22.04.2025
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

class ModifyItemViewViewModel: ObservableObject {
    @Published var title = ""
    @Published var dueDate = Date()
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var locationDescription: String = "no location information"
    @Published var showAlert = false
    @Published var toBeCopied = false
    @Published var gettingThere: Int
    @Published var selectedTag: String = ""
    @Published var tagColorIndex: Int = 0

    /// Whether the current user is 18 or older. Defaults to false until the
    /// Firestore fetch completes, so the location section stays hidden while loading.
    @Published var isAdult: Bool = false

    private var item: Item

    init(item: Item) {
        self.title = item.title
        self.dueDate = Date(timeIntervalSince1970: item.dueDate)
        self.selectedTag = item.tagName
        self.tagColorIndex = item.tagColorIndex
        self.longitude = item.longitude
        self.latitude = item.latitude
        self.locationDescription = item.locationDescription
        self.gettingThere = item.gettingThere
        self.item = item

        fetchUserData()
    }

    func modify() {
        guard canModify else { return }
        guard let uId = Auth.auth().currentUser?.uid else { return }

        removeNotification(for: item)

        let updatedItem = Item(
            id: item.id,
            title: self.title,
            dueDate: self.dueDate.timeIntervalSince1970,
            tagName: self.selectedTag,
            tagColorIndex: self.tagColorIndex,
            createdDate: item.createdDate,
            isDone: item.isDone,
            recentlyDeleted: false,
            streaked: item.streaked,
            latitude: isAdult ? self.latitude : nil,
            longitude: isAdult ? self.longitude : nil,
            locationDescription: isAdult ? self.locationDescription : "no location information",
            gettingThere: self.gettingThere
        )

        Firestore.firestore()
            .collection("users")
            .document(uId)
            .collection("todos")
            .document(item.id)
            .setData(updatedItem.asDictionary(), merge: true) { error in
                if let error = error {
                    print("Error updating document: \(error)")
                } else {
                    print("Document successfully updated with encrypted location data")
                    self.scheduleNotification(for: updatedItem)
                }
            }
    }

    func copy() {
        guard canModify else { return }
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

        Firestore.firestore()
            .collection("users")
            .document(uId)
            .collection("todos")
            .document(newId)
            .setData(newItem.asDictionary()) { error in
                if let error = error {
                    print("Error copying item: \(error.localizedDescription)")
                } else {
                    print("Item copied successfully with encrypted location data")
                    NotificationCenter.default.post(name: .newItemAdded, object: nil, userInfo: ["item": newItem])
                }
            }

        scheduleNotification(for: newItem)
    }

    // Fetches both gettingThere and birthday in a single Firestore call.
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

                    // Compute isAdult from the stored birthday (TimeInterval)
                    if let birthday = data["birthday"] as? TimeInterval {
                        let birthDate = Date(timeIntervalSince1970: birthday)
                        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
                        self.isAdult = age >= 18
                    }
                    // If birthday is missing (legacy account), treat as adult so
                    // existing users are not suddenly locked out of the feature.
                    else {
                        self.isAdult = true
                    }
                }
            }
    }

    // MARK: - Notifications

    private func removeNotification(for item: Item) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id])

        var scheduledNotifications = UserDefaults.standard.array(forKey: "Scheduled1HourReminder") as? [String] ?? []
        if let index = scheduledNotifications.firstIndex(of: item.id) {
            scheduledNotifications.remove(at: index)
            UserDefaults.standard.set(scheduledNotifications, forKey: "Scheduled1HourReminder")
        }
    }

    func scheduleNotification(for item: Item) {
        var scheduledNotifications = UserDefaults.standard.array(forKey: "Scheduled1HourReminder") as? [String] ?? []

        if scheduledNotifications.contains(item.id) || item.isDone { return }

        let notificationTime = item.dueDate - 3600

        if notificationTime > Date().timeIntervalSince1970 {
            let content = UNMutableNotificationContent()
            content.title = "Upcoming Task Due"
            content.body = "Your task '\(item.title)' is due in one hour."
            content.sound = .default

            let triggerDate = Date(timeIntervalSince1970: notificationTime)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: triggerDate
                ),
                repeats: false
            )

            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            ) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }

            scheduledNotifications.append(item.id)
            UserDefaults.standard.set(scheduledNotifications, forKey: "Scheduled1HourReminder")
        }
    }

    var canModify: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard dueDate >= Date().addingTimeInterval(-86400) else { return false }
        return true
    }
}
