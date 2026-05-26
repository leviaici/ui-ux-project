//
//  ItemsView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import FirebaseFirestoreSwift
import SwiftUI

struct ItemsView: View {
    @StateObject var viewModel: ItemsViewViewModel
    @FirestoreQuery var items: [Item]
    @State private var selectedItem: Item?
    @State private var isModifyItemViewPresented = false
    private var userId: String
    @State private var toBeCopied: Bool = false
    @State private var searchText: String = ""
    @State private var selectedTagFilters: Set<String> = []
    @State private var showUndoneOnly: Bool = false
    
    // Color options to match the ones in ModifyItemView
    private let colorOptions: [Color] = [
        Color.blue, Color.red, Color.green, Color.purple, Color.orange,
        Color.pink, Color.yellow, Color.indigo, Color.cyan, Color.brown
    ]

    init(userId: String) {
        self._items = FirestoreQuery(collectionPath: "users/\(userId)/todos")
        self._viewModel = StateObject(
            wrappedValue: ItemsViewViewModel(userId: userId)
        )
        self.userId = userId
    }
    
    var shownItems: [Item] {
        return items.filter { !$0.recentlyDeleted }
    }

    var overdueItems: [Item] {
        return shownItems.filter { $0.dueDate < Date().timeIntervalSince1970 }
    }

    var upcomingItems: [Item] {
        return shownItems.filter { $0.dueDate >= Date().timeIntervalSince1970 }
    }
    
    var streak: Int {
        return viewModel.sendStreak()
    }
    
    // Get unique tags from all items
    var uniqueTags: [String] {
        let allTags = shownItems.map { $0.tagName }
        return Array(Set(allTags)).sorted()
    }
    
    // Filter by tags, search text, and undone status
    var filteredOverdueItems: [Item] {
        var filtered = overdueItems
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        if !selectedTagFilters.isEmpty {
            filtered = filtered.filter { selectedTagFilters.contains($0.tagName) }
        }
        
        if showUndoneOnly {
            filtered = filtered.filter { !$0.isDone }
        }
        
        return filtered
    }
    
    var filteredUpcomingItems: [Item] {
        var filtered = upcomingItems
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        if !selectedTagFilters.isEmpty {
            filtered = filtered.filter { selectedTagFilters.contains($0.tagName) }
        }
        
        if showUndoneOnly {
            filtered = filtered.filter { !$0.isDone }
        }
        
        return filtered
    }
    
    // Helper function to create a dictionary mapping tags to their color indices
    func createTagColorMap() -> [String: Int] {
        var tagColorMap: [String: Int] = [:]
        
        for tag in uniqueTags {
            tagColorMap[tag] = getTagColorIndex(forTag: tag)
        }
        
        return tagColorMap
    }

    var body: some View {
        NavigationView {
            VStack {
                if !overdueItems.isEmpty || !upcomingItems.isEmpty {
                    List {
                        // Search bar
                        SearchBar(text: $searchText)
                            .listRowSeparator(.hidden)
                            .padding(.bottom, 5)
                        
                        // Filters section
                        VStack(alignment: .leading, spacing: 12) {
                            // Tag filters header
                            HStack {
                                Label("Filters", systemImage: "line.3.horizontal.decrease.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.appColor)
                                
                                Spacer()
                                
                                Button(action: {
                                    showUndoneOnly.toggle()
                                }) {
                                    HStack(spacing: 6) {
                                        Text("Undone Tasks")
                                            .font(.subheadline)
                                        Image(systemName: showUndoneOnly ? "checkmark.circle.fill" : "circle")
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(showUndoneOnly ? Color.appColor : Color(.systemGray6))
                                    .cornerRadius(8)
                                    .foregroundColor(showUndoneOnly ? .white : .primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Tag filters scrolling area with fixed tag icon
                            HStack(spacing: 0) {
                                // Fixed tag icon
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.appColor)
                                    .frame(width: 30)
                                    .padding(.trailing, 8)
                                
                                // Scrollable tags
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        Text("All")
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedTagFilters.isEmpty ? Color.appColor : Color(.systemGray6))
                                            .cornerRadius(8)
                                            .foregroundColor(selectedTagFilters.isEmpty ? .white : .primary)
                                            .onTapGesture {
                                                selectedTagFilters.removeAll()
                                            }
                                        
                                        ForEach(uniqueTags, id: \.self) { tag in
                                            let tagColorIndex = getTagColorIndex(forTag: tag)
                                            let tagColor = getColor(forIndex: tagColorIndex)
                                            let isSelected = selectedTagFilters.contains(tag)
                                            
                                            Text(tag)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? tagColor : Color(.systemGray6))
                                                .cornerRadius(8)
                                                .foregroundColor(isSelected ? .white : .primary)
                                                .onTapGesture {
                                                    if isSelected {
                                                        selectedTagFilters.remove(tag)
                                                    } else {
                                                        selectedTagFilters.insert(tag)
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.trailing, 8)
                                }
                            }
                            .frame(height: 44)
                            
                            // Active filters indicator
                            if !selectedTagFilters.isEmpty || showUndoneOnly {
                                HStack {
                                    Text("Active filters: \(selectedTagFilters.count + (showUndoneOnly ? 1 : 0))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Clear All") {
                                        selectedTagFilters.removeAll()
                                        showUndoneOnly = false
                                    }
                                    .font(.caption)
                                    .foregroundColor(.appColor)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .cornerRadius(10)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        
                        // Overdue items section
                        if !filteredOverdueItems.isEmpty {
                            Section(header: Text("Overdue Items").foregroundColor(.appColor)) {
                                ForEach(filteredOverdueItems) { item in
                                    showItems(item: item)
                                }
                            }
                        }
                        
                        // Upcoming items section
                        if !filteredUpcomingItems.isEmpty {
                            Section(header: Text("Upcoming items").foregroundColor(.appColor)) {
                                ForEach(filteredUpcomingItems) { item in
                                    showItems(item: item)
                                }
                            }
                        }
                    }
                } else {
                    // Enhanced empty state design
                    VStack(spacing: 25) {
                        if searchText.isEmpty && selectedTagFilters.isEmpty && !showUndoneOnly {
                            // No items at all
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 80))
                                    .foregroundColor(.appColor)
                                    .padding(.bottom, 10)
                                
                                Text("All Caught Up!")
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text("You have no tasks to complete right now.\nEnjoy your free time!")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 40)
                            }
                        } else {
                            // No results from search/filters
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                Text("No Matching Tasks")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                VStack(spacing: 8) {
                                    if !searchText.isEmpty {
                                        Text("No tasks found containing \"\(searchText)\"")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if !selectedTagFilters.isEmpty {
                                        Text("No tasks with the selected tag filters")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if showUndoneOnly {
                                        Text("No undone tasks")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .multilineTextAlignment(.center)
                                
                                Button {
                                    searchText = ""
                                    selectedTagFilters.removeAll()
                                    showUndoneOnly = false
                                } label: {
                                    Text("Clear All Filters")
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 5)
                            }
                        }
                        
                        // Show a tip only when there are no tasks at all
                        if shownItems.isEmpty {
                            VStack(spacing: 10) {
                                Text("Tip:")
                                    .font(.headline)
                                    .foregroundColor(.appColor)
                                
                                Text("Swipe left on tasks to delete them or swipe right to edit and duplicate tasks.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("My List")
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

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)
                .padding(10)
            TextField("Search items...", text: $text)
                .foregroundStyle(.gray)
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) // Dismiss the keyboard
                }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.gray)
                        .padding(10)
                }
                .buttonStyle(PlainButtonStyle()) // Disable button animation
            }
        }
        .frame(height: 40)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ItemsView_Previews: PreviewProvider {
    static var previews: some View {
        ItemsView(userId: "4GYnXVlMCMR8LQ0JErKq1OPRTeh2")
    }
}
