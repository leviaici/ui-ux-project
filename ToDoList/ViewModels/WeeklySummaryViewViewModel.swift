//
//  WeeklySummaryViewViewModel.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 20.03.2025.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

// Statistics for a specific tag
struct TagStats {
    var total: Int
    var completed: Int
    var colorIndex: Int
    
    var completionPercentage: Double {
        if total == 0 { return 0 }
        return Double(completed) / Double(total) * 100
    }
}

// Daily statistics
struct DailyStats {
    var total: Int
    var completed: Int
    
    var completionPercentage: Double {
        if total == 0 { return 0 }
        return Double(completed) / Double(total) * 100
    }
}

class WeeklySummaryViewViewModel: ObservableObject {
    private let userId: String
    @Published var items: [Item] = []
    @Published var tagStats: [String: TagStats] = [:]
    @Published var expandedTags: Set<String> = []
    @Published var streak: Int = 0
    @Published var showDailyProgress: Bool = false

    /// Whether the current user is 18 or older. Defaults to false until the
    /// Firestore fetch completes, so location is hidden while loading.
    @Published var isAdult: Bool = false

    // Weekly statistics
    @Published var weeklyTotalTasks: Int = 0
    @Published var weeklyCompletedTasks: Int = 0
    @Published var weeklyCompletionPercentage: Double = 0
    
    // Daily statistics cache
    private var dailyStatsCache: [Int: DailyStats] = [:]
    private var weekStartDate: Date?
    
    init(userId: String) {
        self.userId = userId
        fetchStreak()
        fetchUserData()
    }
    
    func setupWithItems(_ items: [Item]) {
        self.items = items.filter { !$0.recentlyDeleted }
        calculateWeeklyStats()
        calculateTagStats()
        dailyStatsCache = [:]
    }
    
    func toggleItemDone(_ item: Item) {
        let db = Firestore.firestore()
        let itemRef = db.collection("users/\(userId)/todos").document(item.id)
        
        itemRef.updateData(["isDone": !item.isDone]) { error in
            if let error = error {
                print("Error updating document: \(error)")
            }
        }
    }
    
    func calculateWeeklyStats() {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return }
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else { return }
        
        self.weekStartDate = startOfWeek
        
        let startTimestamp = startOfWeek.timeIntervalSince1970
        let endTimestamp = endOfWeek.timeIntervalSince1970
        
        let weeklyItems = items.filter { $0.dueDate >= startTimestamp && $0.dueDate < endTimestamp }
        
        weeklyTotalTasks = weeklyItems.count
        weeklyCompletedTasks = weeklyItems.filter { $0.isDone }.count
        weeklyCompletionPercentage = weeklyTotalTasks > 0 ?
            Double(weeklyCompletedTasks) / Double(weeklyTotalTasks) * 100 : 0
    }
    
    func calculateTagStats() {
        var newTagStats: [String: TagStats] = [:]
        
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return }
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else { return }
        
        let startTimestamp = startOfWeek.timeIntervalSince1970
        let endTimestamp = endOfWeek.timeIntervalSince1970
        
        let weeklyItems = items.filter { $0.dueDate >= startTimestamp && $0.dueDate < endTimestamp }
        
        for item in weeklyItems {
            let tag = item.tagName
            if var stats = newTagStats[tag] {
                stats.total += 1
                if item.isDone { stats.completed += 1 }
                newTagStats[tag] = stats
            } else {
                newTagStats[tag] = TagStats(
                    total: 1,
                    completed: item.isDone ? 1 : 0,
                    colorIndex: item.tagColorIndex
                )
            }
        }
        
        DispatchQueue.main.async {
            self.tagStats = newTagStats
        }
    }
    
    func getDailyStats(forDayOffset dayOffset: Int) -> DailyStats {
        if let cachedStats = dailyStatsCache[dayOffset] { return cachedStats }
        
        let calendar = Calendar.current
        guard let weekStart = weekStartDate,
              let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: weekStart),
              let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return DailyStats(total: 0, completed: 0)
        }
        
        let dayItems = items.filter {
            $0.dueDate >= dayStart.timeIntervalSince1970 &&
            $0.dueDate < nextDayStart.timeIntervalSince1970 &&
            !$0.recentlyDeleted
        }
        
        let stats = DailyStats(total: dayItems.count, completed: dayItems.filter { $0.isDone }.count)
        dailyStatsCache[dayOffset] = stats
        return stats
    }
    
    func isToday(dayOffset: Int) -> Bool {
        let calendar = Calendar.current
        guard let weekStart = weekStartDate,
              let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { return false }
        return calendar.isDateInToday(dayDate)
    }
    
    func toggleTag(_ tag: String) {
        DispatchQueue.main.async {
            if self.expandedTags.contains(tag) {
                self.expandedTags.remove(tag)
            } else {
                self.expandedTags.insert(tag)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    func getItemsForTag(_ tag: String) -> [Item] {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else { return [] }
        
        return items.filter {
            $0.tagName == tag &&
            $0.dueDate >= startOfWeek.timeIntervalSince1970 &&
            $0.dueDate < endOfWeek.timeIntervalSince1970
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    func createTagColorMap() -> [String: Int] {
        var tagColorMap: [String: Int] = [:]
        for tag in Array(Set(items.map { $0.tagName })).sorted() {
            tagColorMap[tag] = getTagColorIndex(forTag: tag)
        }
        return tagColorMap
    }
    
    func getTagColorIndex(forTag tag: String) -> Int {
        return items.first(where: { $0.tagName == tag })?.tagColorIndex ?? 0
    }
    
    func fetchStreak() {
        let overdueItems = items.filter {
            $0.dueDate < Date().timeIntervalSince1970 && !$0.isDone && !$0.recentlyDeleted
        }
        
        let calendar = Calendar.current
        let todayTimestamp = calendar.startOfDay(for: Date()).timeIntervalSince1970
        
        for item in overdueItems {
            if !item.streaked && item.dueDate < todayTimestamp {
                let db = Firestore.firestore()
                db.collection("users").document(userId).setData(["streak": 0], merge: true)
                db.collection("users").document(userId).collection("todos")
                    .document(item.id).setData(["streaked": true], merge: true)
                break
            }
        }
        
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .getDocument { [weak self] snapshot, error in
                guard let data = snapshot?.data(), error == nil else { return }
                DispatchQueue.main.async {
                    self?.streak = data["streak"] as? Int ?? 0
                }
            }
    }

    // Fetches birthday to determine isAdult. Separate from fetchStreak to keep
    // concerns clean — fetchStreak already does a getDocument call for streak only.
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
    
    func sendToRecentlyDeleted(id: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("todos")
            .document(id).setData(["recentlyDeleted": true], merge: true)
        
        removeNotification(for: id)
        
        if let index = items.firstIndex(where: { $0.id == id }) {
            DispatchQueue.main.async {
                self.items[index].recentlyDeleted = true
                self.calculateWeeklyStats()
                self.calculateTagStats()
            }
        }
    }
    
    private func removeNotification(for id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        var scheduledNotifications = UserDefaults.standard.array(forKey: "Scheduled1HourReminder") as? [String] ?? []
        if let index = scheduledNotifications.firstIndex(of: id) {
            scheduledNotifications.remove(at: index)
            UserDefaults.standard.set(scheduledNotifications, forKey: "Scheduled1HourReminder")
        }
    }
}
