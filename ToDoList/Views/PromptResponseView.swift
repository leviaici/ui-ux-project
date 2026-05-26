//
//  PromptResponseView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.03.2025.
//

import SwiftUI

struct PromptResponseView: View {
    @Binding var isPresented: Bool
    @Binding var response: String
    @Binding var isLoading: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with close button
            HStack {
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            Spacer()
            
            if isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(2.0)
                        .padding()
                    
                    Text("Generating your daily insight...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Response display
                VStack(spacing: 30) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    Text("Tomorrow's Insight")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(response)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.appColor.opacity(0.1))
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                    
                    Text("Have a great and productive day!")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 15)
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Done button
            Button {
                isPresented = false
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appColor)
                    .cornerRadius(15)
                    .shadow(color: Color.appColor.opacity(0.5), radius: 5, x: 0, y: 2)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }
}

struct PromptResponseView_Previews: PreviewProvider {
    static var previews: some View {
        PromptResponseView(
            isPresented: .constant(true),
            response: .constant("Get ready for a productive day ahead! You've got a team meeting in the morning, followed by your project deadline in the afternoon."),
            isLoading: .constant(false)
        )
    }
}
