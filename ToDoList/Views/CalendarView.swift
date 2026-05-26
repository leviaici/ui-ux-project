//
//  CalendarView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.03.2025.
//

import FirebaseFirestoreSwift
import SwiftUI

struct CalendarView: View {
    @StateObject var viewModel: CalendarViewViewModel
    @FirestoreQuery var items: [Item]
    @State private var selectedItem: Item?
    @State private var isModifyItemViewPresented = false
    private var userId: String
    @State private var toBeCopied: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var weekOffset: Int = 0
    @State private var showingDatePicker = false
    @State private var pickerDate = Date()
    @State private var animationInProgress = false
    
    // Color options to match the ones in ModifyItemView
    private let colorOptions: [Color] = [
        Color.blue, Color.red, Color.green, Color.purple, Color.orange,
        Color.pink, Color.yellow, Color.indigo, Color.cyan, Color.brown
    ]
    
    // Calendar formatter
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
    
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    init(userId: String) {
        self._items = FirestoreQuery(collectionPath: "users/\(userId)/todos")
        self._viewModel = StateObject(
            wrappedValue: CalendarViewViewModel(userId: userId)
        )
        self.userId = userId
    }
    
    var shownItems: [Item] {
        return items.filter { !$0.recentlyDeleted }
    }
    
    var streak: Int {
        return viewModel.sendStreak()
    }
    
    // Get the week dates for the current weekOffset
    var weekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        // Start of the current week (Sunday)
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }
        
        // Apply the weekOffset
        guard let offsetStartOfWeek = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek) else {
            return []
        }
        
        // Generate dates for the week
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: offsetStartOfWeek)
        }
    }
    
    // Items for the selected date
    var itemsForSelectedDate: [Item] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        
        guard let startTimeInterval = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: startOfDay)?.timeIntervalSince1970,
              let endTimeInterval = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)?.timeIntervalSince1970 else {
            return []
        }
        
        return shownItems.filter { item in
            item.dueDate >= startTimeInterval && item.dueDate <= endTimeInterval
        }
    }
    
    // Check if a specific date has items
    func hasItems(for date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        guard let startTimeInterval = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: startOfDay)?.timeIntervalSince1970,
              let endTimeInterval = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)?.timeIntervalSince1970 else {
            return false
        }
        
        return shownItems.contains { item in
            item.dueDate >= startTimeInterval && item.dueDate <= endTimeInterval
        }
    }
    
    // Helper function to create a dictionary mapping tags to their color indices
    func createTagColorMap() -> [String: Int] {
        var tagColorMap: [String: Int] = [:]
        let uniqueTags = Array(Set(shownItems.map { $0.tagName })).sorted()
        
        for tag in uniqueTags {
            tagColorMap[tag] = getTagColorIndex(forTag: tag)
        }
        
        return tagColorMap
    }
    
    // Helper function to get unique tags
    var uniqueTags: [String] {
        let allTags = shownItems.map { $0.tagName }
        return Array(Set(allTags)).sorted()
    }
    
    // Function to navigate to first week of a month
    func navigateToMonth(date: Date) {
        let calendar = Calendar.current
        if let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
           let firstWeekOfMonth = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstDayOfMonth)) {
            
            // Calculate the new week offset
            let today = Date()
            let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
            
            let weekDifference = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: firstWeekOfMonth).weekOfYear ?? 0
            
            // Update weekOffset with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                weekOffset = weekDifference
                // Set selected date to first day of the month
                selectedDate = firstDayOfMonth
            }
        }
    }
    
    // Function to handle swipe gestures
    func handleSwipe(direction: SwipeDirection) {
        guard !animationInProgress else { return }
        
        animationInProgress = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            switch direction {
            case .left:
                weekOffset += 1
            case .right:
                weekOffset -= 1
            }
        }
        
        // Provide haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // Reset animation lock after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animationInProgress = false
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar header with month and navigation
                HStack {
                    Button(action: {
                        pickerDate = weekDates.first ?? Date()
                        showingDatePicker = true
                    }) {
                        HStack {
                            Text(monthFormatter.string(from: weekDates.first ?? Date()))
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.appColor)
                        }
                        .padding(.leading)
                    }
                    
                    if weekOffset != 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                weekOffset = 0
                                selectedDate = Date()
                            }
                        }) {
                            Text("Go back")
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .background(Color.appColor.opacity(0.2))
                                .foregroundColor(Color.appColor)
                                .cornerRadius(8)
                        }
                        .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 10)
                
                // Calendar week view
                CalendarWeekView(
                    weekOffset: weekOffset,
                    selectedDate: $selectedDate,
                    weekDates: weekDates,
                    hasItems: hasItems,
                    onSwipe: handleSwipe
                )
                
                // Items for selected date
                if itemsForSelectedDate.isEmpty {
                    // Empty state design matching ItemsView
                    VStack(spacing: 25) {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 80))
                                .foregroundColor(.appColor)
                                .padding(.bottom, 10)
                            
                            Text("No Tasks for \(selectedDate, formatter: DateFormatter.dateOnly)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("You don't have any tasks scheduled for this date.\nEnjoy your day!")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                        }
                        
                        // Quick tips section
                        VStack(spacing: 10) {
                            Text("Tip:")
                                .font(.headline)
                                .foregroundColor(.appColor)
                            
                            Text("Swipe left or right on the calendar to navigate between weeks. Tap a date to view tasks for that day.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.top, 10)
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(itemsForSelectedDate) { item in
                            showItems(item: item)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("My Calendar")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack { // Keeps them close together
                        Text("Streak: \(streak)")
                            .fixedSize() // Prevents the text from shrinking/truncating
                        
                        Image(systemName: "graduationcap")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingNewItemViewModel = true
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
            .sheet(isPresented: $viewModel.showingNewItemViewModel) {
                NewItemView(
                    newItemPresented: $viewModel.showingNewItemViewModel,
                    existingTags: uniqueTags,
                    tagColorMap: createTagColorMap()
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationView {
                    MonthYearPickerView(date: $pickerDate)
                        .navigationBarTitle("Select Date", displayMode: .inline)
                        .navigationBarItems(
                            leading: Button("Cancel") {
                                showingDatePicker = false
                            },
                            trailing: Button("Done") {
                                navigateToMonth(date: pickerDate)
                                showingDatePicker = false
                            }
                        )
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: Binding(
            get: { isModifyItemViewPresented && selectedItem != nil },
            set: { newValue in isModifyItemViewPresented = newValue }
        )) {
            if let selectedItem = selectedItem {
                ModifyItemView(
                    item: selectedItem,
                    modifiedItemPresented: $isModifyItemViewPresented,
                    toBeCopied: $toBeCopied,
                    existingTags: uniqueTags,
                    tagColorMap: createTagColorMap()
                )
            }
        }
        .onAppear {
            viewModel.items = items
            // Set initial selected date to today
            selectedDate = Date()
        }
        .onChange(of: items) { newItems in
            viewModel.items = newItems
        }
    }
    
    // Helper function to get tag color index for a specific tag
    func getTagColorIndex(forTag tag: String) -> Int {
        // Find the first item with this tag and get its color index
        if let tagItem = shownItems.first(where: { $0.tagName == tag }) {
            return tagItem.tagColorIndex
        }
        
        // Default to 0 (blue) if not found
        return 0
    }
    
    // Helper function to get color from index
    func getColor(forIndex index: Int) -> Color {
        guard index >= 0 && index < colorOptions.count else {
            return Color.blue // Default color
        }
        return colorOptions[index]
    }

    func showItems(item: Item) -> some View {
        ItemView(item: item)
            .swipeActions(edge: .trailing) {
                Button {
                    viewModel.sendToRecentlyDeleted(id: item.id)
                } label: {
                    Image(systemName: "trash.fill")
                }.tint(.red)
            }
            .swipeActions(edge: .leading) {
                Button {
                    selectedItem = item
                    toBeCopied = false
                    isModifyItemViewPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }.tint(.appColor)
                Button {
                    selectedItem = item
                    toBeCopied = true
                    isModifyItemViewPresented = true
                } label: {
                    Image(systemName: "repeat")
                }.tint(.cuteBlue)
            }
            .listRowSeparator(.hidden)
    }
}

// Define swipe direction enum
enum SwipeDirection {
    case left
    case right
}

// DateButton component - extracted for better organization
struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let hasItems: Bool
    let onTap: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appColor : Color.clear)
                        .frame(width: 35, height: 35)
                    
                    Text(dateFormatter.string(from: date))
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    // Indicator for dates with items
                    if hasItems && !isSelected {
                        Circle()
                            .fill(Color.appColor)
                            .frame(width: 6, height: 6)
                            .offset(y: 16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Optimized button component for months
struct MonthButton: View {
    let month: String
    let isSelected: Bool
    let accentColor: Color
    let primaryTextColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(month)
                    .font(.system(size: 18))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? accentColor : primaryTextColor)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accentColor)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Optimized button component for years
struct YearButton: View {
    let year: Int
    let isSelected: Bool
    let accentColor: Color
    let primaryTextColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(String(year))
                    .font(.system(size: 18))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? accentColor : primaryTextColor)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accentColor)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Extension to create a date-only formatter
extension DateFormatter {
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(userId: "4GYnXVlMCMR8LQ0JErKq1OPRTeh2")
    }
}
