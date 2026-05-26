//
//  DailyProgressView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 20.03.2025.
//

import SwiftUI

struct DailyProgressView: View {
    @ObservedObject var viewModel: WeeklySummaryViewViewModel
    @Environment(\.dismiss) private var dismiss
    var colorScheme: ColorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }
    
    private var weekDays: [String] {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Daily Breakdown")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Daily Progress Cards
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<7, id: \.self) { index in
                        let dayStats = viewModel.getDailyStats(forDayOffset: index)
                        
                        DailyProgressCard(
                            dayName: weekDays[index],
                            isToday: viewModel.isToday(dayOffset: index),
                            completedTasks: dayStats.completed,
                            totalTasks: dayStats.total,
                            completionPercentage: dayStats.completionPercentage,
                            colorScheme: colorScheme
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.top, 20)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

struct DailyProgressCard: View {
    var dayName: String
    var isToday: Bool
    var completedTasks: Int
    var totalTasks: Int
    var completionPercentage: Double
    var colorScheme: ColorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }
    
    private var progressColor: Color {
        let percentage = completionPercentage
        if percentage < 30 {
            return .red
        } else if percentage < 70 {
            return .orange
        } else if percentage < 100 {
            return .appColor
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(dayName)
                    .font(.headline)
                    .fontWeight(isToday ? .bold : .regular)
                
                if isToday {
                    Text("(Today)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(completionPercentage, specifier: "%.0f")%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor)
            }
            
            ProgressBar(value: completionPercentage / 100)
                .frame(height: 10)
                .foregroundColor(progressColor)
            
            HStack {
                Text("\(completedTasks)/\(totalTasks) tasks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if totalTasks == 0 {
                    Text("No tasks scheduled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if completionPercentage == 100 {
                    Text("All tasks completed!")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if isToday && completionPercentage < 100 {
                    let tasksRemaining = totalTasks - completedTasks
                    if tasksRemaining > 1 {
                        Text("\(tasksRemaining) tasks remaining today")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("\(tasksRemaining) task remaining today")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isToday ? Color.appColor : Color.clear, lineWidth: isToday ? 2 : 0)
        )
    }
}
