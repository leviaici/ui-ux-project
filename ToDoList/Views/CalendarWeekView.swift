//
//  CalendarWeekView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.03.2025.
//

import SwiftUI

struct CalendarWeekView: View {
    let weekOffset: Int
    @Binding var selectedDate: Date
    let weekDates: [Date]
    let hasItems: (Date) -> Bool
    let onSwipe: (SwipeDirection) -> Void
    
    @State private var dragOffset: CGFloat = 0
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Week days header
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    let date = weekDates[index]
                    Text(weekdayFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Week dates
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    DateButton(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        hasItems: hasItems(date),
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        dragOffset = 0
                        
                        if value.translation.width > threshold {
                            // Swipe right - previous week
                            onSwipe(.right)
                        } else if value.translation.width < -threshold {
                            // Swipe left - next week
                            onSwipe(.left)
                        }
                    }
            )
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding()
    }
}
