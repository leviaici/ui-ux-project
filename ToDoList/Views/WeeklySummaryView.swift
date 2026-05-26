//
//  WeeklySummaryView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 20.03.2025.
//

import SwiftUI
import FirebaseFirestoreSwift

struct WeeklySummaryView: View {
    @StateObject var viewModel: WeeklySummaryViewViewModel
    @FirestoreQuery var items: [Item]
    @State private var showingNewItemViewModel = false
    @Environment(\.colorScheme) var colorScheme
    
    private let colorOptions: [Color] = [
        Color.blue, Color.red, Color.green, Color.purple, Color.orange,
        Color.pink, Color.yellow, Color.indigo, Color.cyan, Color.brown
    ]
    
    private var userId: String
    
    init(userId: String) {
        self._items = FirestoreQuery(collectionPath: "users/\(userId)/todos")
        self._viewModel = StateObject(
            wrappedValue: WeeklySummaryViewViewModel(userId: userId)
        )
        self.userId = userId
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Weekly Progress Summary - tappable
                    Button {
                        viewModel.showDailyProgress = true
                    } label: {
                        WeeklyProgressView(viewModel: viewModel, colorScheme: colorScheme)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Tag Cards
                    ForEach(viewModel.tagStats.keys.sorted(), id: \.self) { tag in
                        if let stats = viewModel.tagStats[tag] {
                            TagCard(
                                tag: tag,
                                stats: stats,
                                color: getColor(forIndex: stats.colorIndex),
                                isExpanded: viewModel.expandedTags.contains(tag),
                                relatedItems: viewModel.getItemsForTag(tag),
                                isAdult: viewModel.isAdult,
                                onToggle: { viewModel.toggleTag(tag) },
                                onItemToggle: { item in viewModel.toggleItemDone(item) },
                                colorScheme: colorScheme
                            )
                        }
                    }
                    
                    if viewModel.tagStats.isEmpty {
                        EmptyStateView(
                            colorScheme: colorScheme,
                            onAddTask: { showingNewItemViewModel = true }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("My Weekly Summary")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Text("Streak: \(viewModel.streak)")
                            .fixedSize()
                        Image(systemName: "graduationcap")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewItemViewModel = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(.appColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: RecentlyDeletedView(userId: userId)) {
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.appColor)
                }
            }
            .onAppear {
                viewModel.setupWithItems(items)
                viewModel.fetchStreak()
            }
            .onChange(of: items) { newItems in
                viewModel.setupWithItems(newItems)
            }
            .sheet(isPresented: $showingNewItemViewModel) {
                NewItemView(
                    newItemPresented: $showingNewItemViewModel,
                    existingTags: Array(viewModel.tagStats.keys).sorted(),
                    tagColorMap: viewModel.createTagColorMap()
                )
            }
            .sheet(isPresented: $viewModel.showDailyProgress) {
                DailyProgressView(viewModel: viewModel, colorScheme: colorScheme)
            }
        }
    }
    
    func getColor(forIndex index: Int) -> Color {
        guard index >= 0 && index < colorOptions.count else { return Color.blue }
        return colorOptions[index]
    }
}

// MARK: - Weekly Progress View

struct WeeklyProgressView: View {
    @ObservedObject var viewModel: WeeklySummaryViewViewModel
    var colorScheme: ColorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Weekly Progress")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.weeklyCompletionPercentage, specifier: "%.0f")%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.appColor)
            }
            
            ProgressBar(value: viewModel.weeklyCompletionPercentage / 100)
                .frame(height: 10)
                .padding(.top, 8)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.weeklyCompletedTasks)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Remaining")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.weeklyTotalTasks - viewModel.weeklyCompletedTasks)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .padding(.top, 8)
            
            HStack {
                Spacer()
                Text("Tap for daily breakdown")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    var value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color(.systemGray5))
                    .cornerRadius(10)
                Rectangle()
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width))
                    .foregroundColor(Color.appColor)
                    .cornerRadius(10)
                    .animation(.easeInOut, value: value)
            }
        }
    }
}

// MARK: - Tag Card

struct TagCard: View {
    var tag: String
    var stats: TagStats
    var color: Color
    var isExpanded: Bool
    var relatedItems: [Item]
    var isAdult: Bool                  // ← NEW
    var onToggle: () -> Void
    var onItemToggle: (Item) -> Void
    var colorScheme: ColorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tag Header
            Button(action: onToggle) {
                HStack {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                    
                    Text(tag)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(stats.completionPercentage, specifier: "%.0f")%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("\(stats.completed)/\(stats.total) tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
                .padding()
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Tasks List (Expandable)
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                    ForEach(relatedItems) { item in
                        TaskRow(
                            item: item,
                            color: color,
                            isAdult: isAdult,      // ← passed down
                            onToggle: { onItemToggle(item) }
                        )
                        if item.id != relatedItems.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .transition(.opacity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
        }
        .cornerRadius(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .clipped()
    }
}

// MARK: - Task Row

struct TaskRow: View {
    var item: Item
    var color: Color
    var isAdult: Bool                  // ← NEW
    var onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .background(Circle().fill(item.isDone ? color : Color.clear))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .opacity(item.isDone ? 1 : 0)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .strikethrough(item.isDone)
                        .foregroundColor(item.isDone ? .secondary : .primary)
                    
                    // Show location only for adults, and only when there's a real value
                    if isAdult &&
                       !item.locationDescription.isEmpty {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(item.locationDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Text(formatDate(item.dueDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var colorScheme: ColorScheme
    var onAddTask: () -> Void
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        VStack(spacing: 25) {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 80))
                    .foregroundColor(.appColor)
                    .padding(.bottom, 10)
                
                Text("No Weekly Data Yet")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Create tasks with tags to see your weekly progress and summary. Track your productivity across different categories!")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 10) {
                Text("Tip:")
                    .font(.headline)
                    .foregroundColor(.appColor)
                Text("Use tags consistently to organize your tasks and get better insights about your productivity patterns.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 20)
    }
}

struct WeeklySummaryView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklySummaryView(userId: "4GYnXVlMCMR8LQ0JErKq1OPRTeh2")
    }
}
