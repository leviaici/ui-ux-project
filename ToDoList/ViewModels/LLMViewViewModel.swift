//
//  LLMViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.03.2025.
//

import FirebaseFirestore
import Foundation
import UserNotifications
import CoreLocation

class LLMViewViewModel: ObservableObject {
    @Published var showingNewItemViewModel = false
    @Published var showingModifiedItemViewModel = false
    @Published var items: [Item] = []
    @Published var lastTokenDate: Date? = nil
    @Published var isPromptSheetPresented = false
    @Published var promptResponse = ""
    @Published var isLoading = false

    private let userId: String
    @Published var streak: Int = 0
    
    init(userId: String) {
        self.userId = userId
        requestNotificationPermission()
        fetchStreak()
        fetchLastToken()
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
    
    // Function to fetch the last token date asynchronously
    func fetchLastToken() {
        let db = Firestore.firestore()
        
        db.collection("users")
            .document(userId)
            .getDocument { [weak self] snapshot, error in
                guard let data = snapshot?.data(), error == nil else {
                    return
                }
                
                if let lastTokenTimestamp = data["lastToken"] as? TimeInterval {
                    DispatchQueue.main.async {
                        self?.lastTokenDate = Date(timeIntervalSince1970: lastTokenTimestamp)
                    }
                }
            }
    }
    
    // Function to get the last token date without refetching
    func getLastTokenDate() -> Date? {
        return lastTokenDate
    }
    
    func completeDay() {
        // Show the prompt sheet
        isPromptSheetPresented = true
        
        // Generate a Tomorrow Insight via Llama API
        performLlamaRequest()
    }
        
    func saveLastPrompt(content: String) {
        // Save the prompt response to UserDefaults
        UserDefaults.standard.set(content, forKey: "lastPrompt_\(userId)")
        
        // Save current date to UserDefaults
        let currentDate = Date()
        UserDefaults.standard.set(currentDate, forKey: "lastToken_\(userId)")
        
        // Update local properties immediately
        self.lastTokenDate = currentDate
        self.promptResponse = content
        
        // Update lastToken in Firestore
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .setData([
                "lastToken": currentDate.timeIntervalSince1970,
                "lastPrompt": content
            ], merge: true) { error in
                if let error = error {
                    print("Error updating lastToken in Firestore: \(error.localizedDescription)")
                }
            }
    }
        
    // Perform the Llama API request
    func performLlamaRequest() {
        isLoading = true
        
        // Create an instance of TogetherClient
        let togetherClient = TogetherClient(apiKey: TogetherAPIConfig.apiKey)
        
        // Get tomorrow's date range
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrow)!
        
        // Convert dates to timestamps
        let tomorrowTimestamp = tomorrow.timeIntervalSince1970
        let tomorrowEndTimestamp = tomorrowEnd.timeIntervalSince1970
        
        // Filter the items array for tomorrow's tasks
        let tomorrowTasks = items.filter { item in
            return item.dueDate >= tomorrowTimestamp &&
            item.dueDate < tomorrowEndTimestamp &&
            !item.recentlyDeleted &&
            !item.isDone
        }
        
        // Check if we have any tasks for tomorrow
        var taskListString = ""
        
        if !tomorrowTasks.isEmpty {
            for task in tomorrowTasks {
                taskListString += " - \(task.title);"
            }
        }
        
        // If there are no tasks, use a default message
        if taskListString.isEmpty {
            let freeMessages = [
                "Enjoy your free day tomorrow - no tasks scheduled!",
                "Clear schedule ahead! Tomorrow's looking wide open.",
                "Nothing on your to-do list for tomorrow. Time to relax!",
                "Tomorrow's your day - no tasks scheduled!",
                "You're free of obligations tomorrow. Enjoy your day!"
            ]
            let randomMessage = freeMessages.randomElement() ?? "You have no tasks scheduled for tomorrow."
            self.promptResponse = randomMessage
            self.saveLastPrompt(content: randomMessage)
            self.isLoading = false
            return
        }
        
        // Create the prompt with the task list
        let prompt = "Make a really short and catchy notification in english that summarizes my next day (no bullet points):\(taskListString)"
        
        // Send request to Llama
        let message = Message(role: "user", content: prompt)
        
        // Make the API call
        togetherClient.createChatCompletion(
            model: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
            messages: [message]
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                    case .success(let content):
                        let formattedContent: String
                        if content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("\"") {
                            formattedContent = self.formatLlamaResponse(content: content)
                        } else {
                            formattedContent = content
                        }
                        self.promptResponse = formattedContent
                        
                        // Save to user defaults
                        self.saveLastPrompt(content: formattedContent)
                        
                    case .failure(let error):
                        print("Error with Llama request: \(error.localizedDescription)")
                        self.promptResponse = "Sorry, I couldn't get your summary for tomorrow. Please make sure you have internet access and try again later."
                    }
            }
        }
    }
    
    // Format the Llama response by removing the pipe characters
    private func formatLlamaResponse(content: String) -> String {
        // Remove pipe characters if they exist
        return String(content.dropFirst().dropLast())
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

struct TogetherAPIConfig {
    static let apiKey: String = {
        guard let path = Bundle.main.path(forResource: "apikey-llama", ofType: "txt") else {
            fatalError("API key file not found")
        }
        do {
            return try String(contentsOfFile: path).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            fatalError("Failed to read API key: \(error)")
        }
    }()
}
