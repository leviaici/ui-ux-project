//
//  ItemViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import FirebaseFirestore
import FirebaseAuth
import Foundation

class ItemViewViewModel: ObservableObject {
    @Published var showingModifiedItemViewModel = false

    /// Whether the current user is 18 or older. Defaults to false until the
    /// Firestore fetch completes, so location and transport stay hidden while loading.
    @Published var isAdult: Bool = false

    init() {
        fetchUserData()
    }

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
                guard let data = document?.data() else { return }

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let birthday = data["birthday"] as? TimeInterval {
                        let age = Calendar.current.dateComponents([.year], from: Date(timeIntervalSince1970: birthday), to: Date()).year ?? 0
                        self.isAdult = age >= 18
                    } else {
                        // Legacy account with no birthday — treat as adult.
                        self.isAdult = true
                    }
                }
            }
    }

    func toggleIsDone(item: Item) {
        var copy = item
        copy.setDone(!item.isDone)

        guard let uId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users")
            .document(uId)
            .collection("todos")
            .document(copy.id)
            .setData(copy.asDictionary())

        var streak = 0

        db.collection("users")
            .document(uId)
            .getDocument { snapshot, error in
                guard let data = snapshot?.data(), error == nil else { return }
                DispatchQueue.main.async {
                    streak = data["streak"] as? Int ?? 0
                    if copy.isDone && !copy.streaked {
                        if copy.dueDate >= Date().timeIntervalSince1970 {
                            db.collection("users")
                                .document(uId)
                                .setData(["streak": streak + 1], merge: true)
                        }
                        db.collection("users")
                            .document(uId)
                            .collection("todos")
                            .document(copy.id)
                            .setData(["streaked": true], merge: true)
                    }

                    if copy.isDone {
                        self.removeNotification(for: copy)
                    } else {
                        self.scheduleNotification(for: copy)
                    }
                }
            }
    }

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

        if scheduledNotifications.contains(item.id) { return }

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
}
