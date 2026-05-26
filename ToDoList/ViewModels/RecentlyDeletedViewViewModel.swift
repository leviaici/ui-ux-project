//
//  RecentlyDeletedViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.09.2023.
//

import FirebaseFirestore
import Foundation

class RecentlyDeletedViewViewModel: ObservableObject {
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    func delete(id: String) {
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .collection("todos")
            .document(id)
            .delete()
    }
    
    func recover(id: String) {
        let db = Firestore.firestore()
        let itemRef = db.collection("users")
            .document(userId)
            .collection("todos")
            .document(id)

        // Set recentlyDeleted to false
        itemRef.setData(["recentlyDeleted": false], merge: true)

        // Fetch the item details to reschedule the notification
        itemRef.getDocument { document, error in
            guard let document = document, document.exists, let data = document.data() else {
                print("Error fetching item data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // Extract Firestore data
            guard let title = data["title"] as? String,
                  let dueDate = data["dueDate"] as? TimeInterval,
                  let tagName = data["tagName"] as? String,
                  let tagColorIndex = data["tagColorIndex"] as? Int,
                  let createdDate = data["createdDate"] as? TimeInterval,
                  let isDone = data["isDone"] as? Bool,
                  let recentlyDeleted = data["recentlyDeleted"] as? Bool,
                  let streaked = data["streaked"] as? Bool,
                  let locationDescription = data["locationDescription"] as? String else {
                print("Error: Missing required item properties.")
                return
            }

            // Handle optional values safely
            let latitude = data["latitude"] as? Double
            let longitude = data["longitude"] as? Double
            let gettingThere = data["gettingThere"] as? Int ?? 0 // Default to walking

            // Create the Item object
            let item = Item(
                id: id,
                title: title,
                dueDate: dueDate,
                tagName: tagName,
                tagColorIndex: tagColorIndex,
                createdDate: createdDate,
                isDone: isDone,
                recentlyDeleted: recentlyDeleted,
                streaked: streaked,
                latitude: latitude,
                longitude: longitude,
                locationDescription: locationDescription,
                gettingThere: gettingThere
            )

            // Reschedule the notification
            self.scheduleNotification(for: item)
        }
    }
    
    func scheduleNotification(for item: Item) {
        // Retrieve the list of scheduled notification IDs
        var scheduledNotifications = UserDefaults.standard.array(forKey: "Scheduled1HourReminder") as? [String] ?? []
        
        // If the notification is already scheduled for this item, skip it
        if scheduledNotifications.contains(item.id) || item.isDone {
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

    
    func deleteAllItems() {
        let db = Firestore.firestore()
        let todosRef = db.collection("users")
            .document(userId)
            .collection("todos")
            
        todosRef.whereField("recentlyDeleted", isEqualTo: true)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error getting documents: \(error)")
                } else {
                    for document in querySnapshot!.documents {
                        let documentID = document.documentID
                        todosRef.document(documentID).delete { (error) in
                            if let error = error {
                                print("Error deleting document: \(error)")
                            } else {
                                print("Document successfully deleted")
                            }
                        }
                    }
                }
            }
    }
}
