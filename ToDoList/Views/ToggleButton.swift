//
//  ToggleButton.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.11.2024.
//

import SwiftUI

struct ToggleButton: ToggleStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Rectangle()
                .foregroundColor(configuration.isOn ? .appColor : .appColor)
                .frame(width: 51, height: 31)
                .overlay(
                    Circle()
                        .foregroundColor(.white)
                        .padding(3)
                        .overlay(
                            Image(systemName: configuration.isOn ? "figure.walk" : "car")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                                .foregroundColor(configuration.isOn ? .appColor : .appColor)
                        )
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.smooth(duration: 0.25), value: configuration.isOn)
                )
                .cornerRadius(20)
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.25)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}
