//
//  MonthYearPickerView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.03.2025.
//

import SwiftUI

struct MonthYearPickerView: View {
    @Binding var date: Date
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var displayedYears: [Int] = []
    
    // Constants for layout
    private let months = Calendar.current.monthSymbols
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let yearRange = 10 // Years to show before and after current year
    
    // Colors
    private let backgroundColor = Color(.systemBackground)
    private let accentColor = Color.appColor
    private let secondaryTextColor = Color(.secondaryLabel)
    private let primaryTextColor = Color(.label)
    
    init(date: Binding<Date>) {
        self._date = date
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date.wrappedValue)
        let month = calendar.component(.month, from: date.wrappedValue) - 1
        
        // Initialize state variables
        self._selectedYear = State(initialValue: year)
        self._selectedMonth = State(initialValue: month)
        
        // Create array of years (current year ± yearRange)
        let minYear = currentYear - yearRange
        let maxYear = currentYear + yearRange
        self._displayedYears = State(initialValue: Array(minYear...maxYear))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with current selection - fixed to display year correctly
            Text("\(months[selectedMonth]) \(String(selectedYear))")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(primaryTextColor)
                .padding(.top, 12)
            
            // Today button - moved to the top for better access
            Button(action: {
                let today = Date()
                let calendar = Calendar.current
                selectedYear = calendar.component(.year, from: today)
                selectedMonth = calendar.component(.month, from: today) - 1
                updateDate()
            }) {
                HStack {
                    Image(systemName: "calendar")
                    Text("Today")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(accentColor)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Divider()
                .padding(.horizontal)
            
            HStack(spacing: 0) {
                // Month selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Month")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(secondaryTextColor)
                        .padding(.leading)
                    
                    // Optimized scroll view for better performance
                    ScrollViewReader { scrollProxy in
                        ScrollView(showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(0..<months.count, id: \.self) { index in
                                    MonthButton(
                                        month: months[index],
                                        isSelected: selectedMonth == index,
                                        accentColor: accentColor,
                                        primaryTextColor: primaryTextColor
                                    ) {
                                        selectedMonth = index
                                        updateDate()
                                    }
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(maxHeight: 250)
                        .onAppear {
                            // Scroll to selected month
                            scrollProxy.scrollTo(selectedMonth, anchor: .center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Vertical divider
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: 1, height: 250)
                    .padding(.vertical, 8)
                
                // Year selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Year")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(secondaryTextColor)
                        .padding(.leading)
                    
                    // Optimized scroll view for better performance
                    ScrollViewReader { scrollProxy in
                        ScrollView(showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(displayedYears, id: \.self) { year in
                                    YearButton(
                                        year: year,
                                        isSelected: selectedYear == year,
                                        accentColor: accentColor,
                                        primaryTextColor: primaryTextColor
                                    ) {
                                        selectedYear = year
                                        updateDate()
                                    }
                                    .id(year)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(maxHeight: 250)
                        .onAppear {
                            // Scroll to selected year
                            scrollProxy.scrollTo(selectedYear, anchor: .center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Spacer to push content up
            Spacer()
        }
        .background(backgroundColor)
        .cornerRadius(16)
        .padding(.bottom, 10)
    }
    
    private func updateDate() {
        var dateComponents = DateComponents()
        dateComponents.year = selectedYear
        dateComponents.month = selectedMonth + 1
        dateComponents.day = 1
        if let newDate = Calendar.current.date(from: dateComponents) {
            date = newDate
        }
    }
}
