//
//  HeaderView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import SwiftUI

struct HeaderView: View {
    let title: String
    let subtitle: String
    let angle: Double
    let background: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .foregroundColor(background)
                .rotationEffect(Angle(degrees: angle))
                .offset(y: -50)
                .shadow(radius: 15)
            
            
            VStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 45))
                    .bold()
                Text(subtitle)
                    .foregroundColor(.white)
                    .font(.system(size: 25))
            }.padding(.top, -25)
        }
        .frame(width: UIScreen.main.bounds.width * 3, height: 400)
        .offset(y: -100)
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView(title: "Title", subtitle: "Subtitle", angle: 30, background: .coralPink)
    }
}
