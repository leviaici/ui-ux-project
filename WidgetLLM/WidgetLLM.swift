//
//  WidgetLLM.swift
//  WidgetLLM
//
//  Created by Adrian Leventiu on 24.03.2025.
//

import WidgetKit
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import AppIntents

// Custom Color Extensions
extension Color {
    static let appPrimary = Color(red: 236/255, green: 96/255, blue: 80/255)
    static let appBackground = Color(red: 249/255, green: 249/255, blue: 249/255)
    static let appAccent = Color(red: 140/255, green: 157/255, blue: 249/255)
}

// App Intent for Refreshing Widget
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Widget"
    
    func perform() async -> some IntentResult {
        await refreshWidgetData()
        return .result()
    }
    
    private func refreshWidgetData() async {
        guard let userId = UserDefaults(suiteName: "group.com.yourappidentifier.widgetkit")?.string(forKey: "currentUserId"),
              !userId.isEmpty else {
            print("No user ID found")
            return
        }
        
        // Configure Firebase if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            
            guard let data = snapshot.data() else {
                print("No data found for user")
                return
            }
            
            let promptText = data["lastPrompt"] as? String ?? "No recent prompt"
            let tokenTimestamp = data["lastToken"] as? TimeInterval ?? Date().timeIntervalSince1970
            
            // Reload all widget timelines
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Firestore Error: \(error.localizedDescription)")
        }
    }
}

// New struct to represent weekly statistics
struct WeeklyStats {
    let totalTasks: Int
    let completedTasks: Int
    let completionPercentage: Double
    
    init(totalTasks: Int = 0, completedTasks: Int = 0) {
        self.totalTasks = totalTasks //== 0 ? 0 : totalTasks - 1
        self.completedTasks = completedTasks //== 0 ? 0 : completedTasks - 1
        self.completionPercentage = totalTasks > 0 ?
        (Double(completedTasks) / Double(totalTasks) * 100) : 0
    }
}

// Timeline Entry Structure
struct LastPromptEntry: TimelineEntry {
    let date: Date
    let prompt: String
    let promptDate: Date
    let weeklyStats: WeeklyStats
    let widgetSize: WidgetFamily
}

// Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LastPromptEntry {
        LastPromptEntry(
            date: Date(),
            prompt: placeholderText(for: context.family),
            promptDate: Date(),
            weeklyStats: WeeklyStats(),
            widgetSize: context.family
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LastPromptEntry) -> ()) {
        fetchWidgetData(for: context.family) { entry in
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastPromptEntry>) -> ()) {
        fetchWidgetData(for: context.family) { entry in
            let timeline = Timeline(
                entries: [entry],
                policy: .never
            )
            completion(timeline)
        }
    }
    
    private func placeholderText(for family: WidgetFamily) -> String {
        switch family {
        case .systemMedium:
            return "Weekly Progress"
        case .systemLarge:
            return "Your Recent AI Insight"
        default:
            return "Placeholder"
        }
    }
    
    private func fetchWidgetData(for family: WidgetFamily, completion: @escaping (LastPromptEntry) -> Void) {
        guard let userId = UserDefaults(suiteName: "group.com.yourappidentifier.widgetkit")?.string(forKey: "currentUserId"),
              !userId.isEmpty else {
            let errorEntry = LastPromptEntry(
                date: Date(),
                prompt: "No User Found",
                promptDate: Date(),
                weeklyStats: WeeklyStats(),
                widgetSize: family
            )
            completion(errorEntry)
            return
        }

        // Ensure Firebase is configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let db = Firestore.firestore()
        let group = DispatchGroup()
        
        var lastPrompt = "No recent prompt"
        var weeklyStats = WeeklyStats()
        var tokenTimestamp: TimeInterval = Date().timeIntervalSince1970
        
        // Fetch last prompt
        group.enter()
        db.collection("users").document(userId).getDocument { snapshot, error in
            defer { group.leave() }
            if let data = snapshot?.data() {
                lastPrompt = data["lastPrompt"] as? String ?? lastPrompt
                tokenTimestamp = data["lastToken"] as? TimeInterval ?? tokenTimestamp
            }
        }
        
        // Fetch weekly stats
        group.enter()
        db.collection("users").document(userId).collection("todos")
            .whereField("dueDate", isGreaterThanOrEqualTo: weekStartTimestamp())
            .whereField("dueDate", isLessThan: weekEndTimestamp())
            .getDocuments { snapshot, error in
                defer { group.leave() }
                guard let documents = snapshot?.documents else { return }
                
                let deletedTasks = documents.filter {doc in
                    doc.data()["recentlyDeleted"] as? Bool == true
                }.count
                let totalTasks = documents.count - deletedTasks
                let completedTasks = documents.filter { doc in
                    doc.data()["isDone"] as? Bool == true &&
                    doc.data()["recentlyDeleted"] as? Bool == false
                }.count
                
                weeklyStats = WeeklyStats(totalTasks: totalTasks, completedTasks: completedTasks)
            }
        
        group.notify(queue: .main) {
            let modifiedPromptDate = Date(timeIntervalSince1970: tokenTimestamp).addingTimeInterval(TimeInterval((86400)))
            
            let entry = LastPromptEntry(
                date: Date(),
                prompt: lastPrompt,
                promptDate: modifiedPromptDate,
                weeklyStats: weeklyStats,
                widgetSize: family
            )
            
            completion(entry)
        }
    }
    
    // Helper function to get week start timestamp
    private func weekStartTimestamp() -> TimeInterval {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return today.timeIntervalSince1970
        }
        return startOfWeek.timeIntervalSince1970
    }
    
    // Helper function to get week end timestamp
    private func weekEndTimestamp() -> TimeInterval {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return Date().timeIntervalSince1970
        }
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return Date().timeIntervalSince1970
        }
        return endOfWeek.timeIntervalSince1970
    }
}

// ProgressBar View
struct ProgressBar: View {
    var value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(.appPrimary)
                    .animation(.linear, value: value)
            }
            .cornerRadius(45.0)
        }
    }
}

// Widget Entry View
struct WidgetLLMEntryView: View {
    var entry: Provider.Entry
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        switch entry.widgetSize {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            Text("Unsupported Widget Size")
        }
    }
}

// Medium Widget View
struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Weekly Progress")
                    .font(.headline)
                
                Spacer()
                
                Button(intent: RefreshWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color.appPrimary)
                }
                .tint(Color.appPrimary.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Int(entry.weeklyStats.completionPercentage))% Complete")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor)
                
                ProgressBar(value: entry.weeklyStats.completionPercentage / 100)
                    .frame(height: 10)
                    .foregroundColor(progressColor)
                
                Text("\(entry.weeklyStats.completedTasks)/\(entry.weeklyStats.totalTasks) tasks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    private var progressColor: Color {
        let percentage = entry.weeklyStats.completionPercentage
        if percentage < 30 {
            return .red
        } else if percentage < 70 {
            return .orange
        } else if percentage < 100 {
            return Color.appPrimary
        } else {
            return .green
        }
    }
}

// Large Widget View
struct LargeWidgetView: View {
    var entry: Provider.Entry
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your Insights")
                    .font(.headline)
                
                Spacer()
                
                Button(intent: RefreshWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color.appPrimary)
                }
                .tint(Color.appPrimary.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.prompt)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appPrimary.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appPrimary, lineWidth: 1)
                    )
                
                Text("Requested for \(Self.dateFormatter.string(from: entry.promptDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
                
                HStack {
                    Text("Weekly Progress")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(Int(entry.weeklyStats.completionPercentage))% Complete")
                        .font(.subheadline)
                        .foregroundColor(progressColor)
                }
                
                ProgressBar(value: entry.weeklyStats.completionPercentage / 100)
                    .frame(height: 10)
                    .foregroundColor(Color.appPrimary)
            }
        }
        .padding()
    }
    
    private var progressColor: Color {
        let percentage = entry.weeklyStats.completionPercentage
        if percentage < 30 {
            return .red
        } else if percentage < 70 {
            return .orange
        } else if percentage < 100 {
            return Color.appPrimary
        } else {
            return .green
        }
    }
}

// Widget Configuration
struct WidgetLLM: Widget {
    let kind: String = "WidgetLLM"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetLLMEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WidgetLLMEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Weekly Insights")
        .description("Display your weekly progress and insights.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// Previews
#Preview(as: .systemMedium) {
    WidgetLLM()
} timeline: {
    LastPromptEntry(
        date: .now,
        prompt: "Tap to Open",
        promptDate: .now,
        weeklyStats: WeeklyStats(totalTasks: 10, completedTasks: 7),
        widgetSize: .systemMedium
    )
}

#Preview(as: .systemLarge) {
    WidgetLLM()
} timeline: {
    LastPromptEntry(
        date: .now,
        prompt: "This is a sample large widget prompt about your recent AI insights",
        promptDate: .now.addingTimeInterval(24 * 60 * 60),
        weeklyStats: WeeklyStats(totalTasks: 15, completedTasks: 12),
        widgetSize: .systemLarge
    )
}
