//
//  CalendarViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.03.2025.
//

import FirebaseFirestore
import Foundation
import UserNotifications
import CoreLocation

class CalendarViewViewModel: ObservableObject {
    @Published var showingNewItemViewModel = false
    @Published var showingModifiedItemViewModel = false
    @Published var items: [Item] = []

    private let userId: String
    @Published var streak: Int = 0
    
    init(userId: String) {
        self.userId = userId
        requestNotificationPermission()
        fetchStreak()
        scheduleNotificationsForItems()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewItem(_:)), name: .newItemAdded, object: nil)
    }

    @objc private func handleNewItem(_ notification: Notification) {
        guard let item = notification.userInfo?["item"] as? Item else { return }
        print("New item received for scheduling: \(item.title)")
        scheduleNotification(for: item)
    }
    
    var shownItems: [Item] {
        return items.filter { $0.recentlyDeleted == false }
    }

    var overdueItems: [Item] {
        return shownItems.filter { $0.dueDate < Date().timeIntervalSince1970 }
    }
    
    func fetchStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayTimestamp = today.timeIntervalSince1970
        
        for item in overdueItems {
            if !item.streaked && item.dueDate < todayTimestamp {
                let db = Firestore.firestore()
                db.collection("users")
                  .document(userId)
                  .setData(["streak": 0], merge: true)
                
                db.collection("users")
                    .document(userId)
                    .collection("todos")
                    .document(item.id)
                    .setData(["streaked": true], merge: true)
                break
            }
        }
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .getDocument { [weak self] snapshot, error in
                guard let data = snapshot?.data(), error == nil else {
                    return
                }
                DispatchQueue.main.async {
                    self?.streak = data["streak"] as? Int ?? 0
                }
            }
    }
    
    func sendStreak() -> Int {
        fetchStreak()
        return streak
    }
    
    func sendToRecentlyDeleted(id: String) {
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .collection("todos")
            .document(id)
            .setData(["recentlyDeleted": true], merge: true)
        
        self.removeNotification(for: id)
    }
    
    // Function to remove a notification
    private func removeNotification(for id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        
        // Also remove from scheduled list in UserDefaults
        var scheduledNotifications = UserDefaults.standard.array(forKey: "Scheduled1HourReminder") as? [String] ?? []
        if let index = scheduledNotifications.firstIndex(of: id) {
            scheduledNotifications.remove(at: index)
            UserDefaults.standard.set(scheduledNotifications, forKey: "Scheduled1HourReminder")
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notifications permission: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotificationsForItems() {
//        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Clear scheduled notifications list in UserDefaults
        UserDefaults.standard.removeObject(forKey: "Scheduled1HourReminder")
        
        for item in shownItems {
            if !item.isDone {
                scheduleNotification(for: item)
            }
        }
    }

    func scheduleNotification(for item: Item) {
        // Retrieve the list of scheduled notification IDs
        var scheduledNotifications = UserDefaults.standard.array(forKey: "Scheduled1HourReminder") as? [String] ?? []
        
        // If the notification is already scheduled for this item, skip it
        if scheduledNotifications.contains(item.id) {
            return
        }

        // Calculate one hour before the due date
        let notificationTime = item.dueDate - 3600 // 3600 seconds in one hour
        
        if notificationTime > Date().timeIntervalSince1970 {
            let content = UNMutableNotificationContent()
            content.title = "Upcoming Task Due"
            content.body = "Your task '\(item.title)' is due in one hour."
            content.sound = .default

            let triggerDate = Date(timeIntervalSince1970: notificationTime)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate),
                repeats: false
            )

            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
            
            // Add the item ID to the list of scheduled notifications and save it
            scheduledNotifications.append(item.id)
            UserDefaults.standard.set(scheduledNotifications, forKey: "Scheduled1HourReminder")
        }
    }
}
