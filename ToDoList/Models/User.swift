//
//  User.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import Foundation

struct User: Codable {
    let id: String
    let email: String
    let name: String
    let joined: TimeInterval
    let birthday: TimeInterval
    let streak: Int
    let lastToken: TimeInterval
    let lastPrompt: String
    var gettingThere: Int
    
    var isAdult: Bool {
        let age = Calendar.current.dateComponents([.year], from: Date(timeIntervalSince1970: birthday), to: Date()).year ?? 0
        return age >= 18
    }
}
