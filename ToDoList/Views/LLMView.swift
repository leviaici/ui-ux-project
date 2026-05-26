//
//  LLMView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.03.2025.
//

import FirebaseFirestoreSwift
import FirebaseFirestore
import SwiftUI

struct LLMView: View {
    @StateObject var viewModel: LLMViewViewModel
    @FirestoreQuery var items: [Item]
    @State private var selectedItem: Item?
    @State private var isModifyItemViewPresented = false
    private var userId: String
    @State private var toBeCopied: Bool = false
    @State private var currentTime = Date()
    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    @State private var lastPrompt: String = ""
    @State private var lastPromptDate: Date?
    
    // Color options to match the ones in ModifyItemView
    private let colorOptions: [Color] = [
        Color.blue, Color.red, Color.green, Color.purple, Color.orange,
        Color.pink, Color.yellow, Color.indigo, Color.cyan, Color.brown
    ]

    init(userId: String) {
        self._items = FirestoreQuery(collectionPath: "users/\(userId)/todos")
        self._viewModel = StateObject(
            wrappedValue: LLMViewViewModel(userId: userId)
        )
        self.userId = userId
    }
    
    var shownItems: [Item] {
        return items.filter { !$0.recentlyDeleted }
    }

    // Get only tomorrow's items
    var tomorrowItems: [Item] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!
        
        return shownItems.filter { item in
            let itemDate = Date(timeIntervalSince1970: item.dueDate)
            let itemDay = calendar.startOfDay(for: itemDate)
            return itemDay >= tomorrow && itemDay < dayAfterTomorrow
        }
    }
    
    // Check if button should be shown (between 9 PM and 12 AM, and lastToken is yesterday or earlier)
    var shouldShowButton: Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: currentTime)
        let currentHour = components.hour ?? 0
        
        let isCorrectTimeWindow = (currentHour >= 21 && currentHour <= 23)
        
        if let lastTokenDate = viewModel.getLastTokenDate() {
            let today = calendar.startOfDay(for: Date())
            let lastTokenDay = calendar.startOfDay(for: lastTokenDate)
            let isLastTokenOld = lastTokenDay < today
            
            return isCorrectTimeWindow && isLastTokenOld
        }
        
        // If lastToken doesn't exist, show button during the time window
        return isCorrectTimeWindow
    }
    
    func fetchLastPromptFromFirebase() {
        let db = Firestore.firestore()
        
        db.collection("users")
            .document(userId)
            .getDocument { snapshot, error in
                guard let data = snapshot?.data(), error == nil else {
                    return
                }
                
                DispatchQueue.main.async {
                    if let promptText = data["lastPrompt"] as? String {
                        self.lastPrompt = promptText
                    }
                    
                    if let tokenTimestamp = data["lastToken"] as? TimeInterval {
                        self.lastPromptDate = Date(timeIntervalSince1970: tokenTimestamp)
                    }
                }
            }
    }
    
    var streak: Int {
        return viewModel.sendStreak()
    }

    var body: some View {
        NavigationStack {
            List {
                // Button for generating insights
                if shouldShowButton {
                    Section {
                        Button(action: {
                            viewModel.completeDay()
                        }) {
                            HStack {
                                Image(systemName: "lightbulb.min.fill")
                                Text("Generate Insights")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .listRowInsets(EdgeInsets()) // Remove default list row insets
                        .listRowBackground(Color.clear) // Clear background for custom styling
                        .padding()
                        .listRowSeparator(.hidden)
                    }
                }
                
                // Last prompt display
                if !lastPrompt.isEmpty, let lastDate = lastPromptDate {
                    Section {
                        lastPromptView(date: lastDate, prompt: lastPrompt)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(5)
                }
                
                // Tomorrow's items section
                Section {
                    if !tomorrowItems.isEmpty {
                        ForEach(tomorrowItems) { item in
                            showItems(item: item)
                        }
                    } else {
                        VStack(spacing: 25) {
                            VStack(spacing: 16) {
                                Image(systemName: "sun.max.circle")
                                    .font(.system(size: 80))
                                    .foregroundColor(.appColor)
                                    .padding(.bottom, 10)
                                
                                Text("Tomorrow Looks Clear!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("You don't have any tasks scheduled for tomorrow.\nEnjoy your free time or plan ahead!")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 40)
                            }
                            
                            // Tip section
                            VStack(spacing: 10) {
                                Text("Tip:")
                                    .font(.headline)
                                    .foregroundColor(.appColor)
                                
                                Text("Plan your tasks for tomorrow in the evening to get AI-powered insights about your day.")
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
                        .padding()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .frame(maxWidth: .infinity)
                    }                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("My Tomorrow")
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
                    existingTags: [],
                    tagColorMap: [:]
                )
            }
            .sheet(isPresented: $viewModel.isPromptSheetPresented) {
                PromptResponseView(
                    isPresented: $viewModel.isPromptSheetPresented,
                    response: $viewModel.promptResponse,
                    isLoading: $viewModel.isLoading
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
                    existingTags: [],
                    tagColorMap: [:]
                )
            }
        }
        .onAppear {
            viewModel.items = items
            currentTime = Date()
            fetchLastPromptFromFirebase()
        }
        .onChange(of: items) { newItems in
            viewModel.items = newItems
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onChange(of: viewModel.promptResponse) { newResponse in
            if !newResponse.isEmpty {
                lastPrompt = newResponse
                lastPromptDate = viewModel.lastTokenDate // Get the updated date from view model
            }
        }
    }

    // Helper method to create the last prompt view
    func lastPromptView(date: Date, prompt: String) -> some View {
        let calendar = Calendar.current
        let promptForDate = calendar.date(byAdding: .day, value: 1, to: date) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        return VStack(alignment: .leading) {
            Text("Your Insight")
                .font(.headline)
                .padding(.bottom, 2)
            
            Text(prompt)
                .font(.body)
                .multilineTextAlignment(.center) // Center the text
                .frame(maxWidth: .infinity) // Make text take full width
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appColor.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appColor, lineWidth: 1)
                )
            
            Text("Requested for \(dateFormatter.string(from: promptForDate))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
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

struct LLMView_Previews: PreviewProvider {
    static var previews: some View {
        LLMView(userId: "4GYnXVlMCMR8LQ0JErKq1OPRTeh2")
    }
}
