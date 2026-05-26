//
//  Item.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//  Updated with encryption on 22.04.2025
//

import Foundation

struct Item: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let dueDate: TimeInterval
    var tagName: String
    var tagColorIndex: Int
    let createdDate: TimeInterval
    var isDone: Bool
    var recentlyDeleted: Bool
    var streaked: Bool = false
    
    // Encrypted properties (stored as encrypted strings)
    private var encryptedLatitude: String?
    private var encryptedLongitude: String?
    private var encryptedLocationDescription: String
    
    var gettingThere: Int = 0 // 0 - walk, 1 - car, 2 - bus (TBA)
    
    // Computed properties for decrypted access
    var latitude: Double? {
        get {
            guard let encrypted = encryptedLatitude else { return nil }
            return EncryptionService.decryptToDouble(encrypted)
        }
        set {
            if let value = newValue {
                encryptedLatitude = EncryptionService.encrypt(value)
            } else {
                encryptedLatitude = nil
            }
        }
    }
    
    var longitude: Double? {
        get {
            guard let encrypted = encryptedLongitude else { return nil }
            return EncryptionService.decryptToDouble(encrypted)
        }
        set {
            if let value = newValue {
                encryptedLongitude = EncryptionService.encrypt(value)
            } else {
                encryptedLongitude = nil
            }
        }
    }
    
    var locationDescription: String {
        get {
            return EncryptionService.decrypt(encryptedLocationDescription) ?? "no location information"
        }
        set {
            encryptedLocationDescription = EncryptionService.encrypt(newValue) ?? ""
        }
    }
    
    // Custom initializer to handle encryption
    init(id: String,
         title: String,
         dueDate: TimeInterval,
         tagName: String,
         tagColorIndex: Int,
         createdDate: TimeInterval,
         isDone: Bool,
         recentlyDeleted: Bool,
         streaked: Bool = false,
         latitude: Double? = nil,
         longitude: Double? = nil,
         locationDescription: String = "no location information",
         gettingThere: Int = 0) {
        
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.tagName = tagName
        self.tagColorIndex = tagColorIndex
        self.createdDate = createdDate
        self.isDone = isDone
        self.recentlyDeleted = recentlyDeleted
        self.streaked = streaked
        self.gettingThere = gettingThere
        
        // Encrypt the location data
        if let lat = latitude {
            self.encryptedLatitude = EncryptionService.encrypt(lat)
        } else {
            self.encryptedLatitude = nil
        }
        
        if let long = longitude {
            self.encryptedLongitude = EncryptionService.encrypt(long)
        } else {
            self.encryptedLongitude = nil
        }
        
        self.encryptedLocationDescription = EncryptionService.encrypt(locationDescription) ?? ""
    }
    
    // Manual Codable implementation to handle the encryption/decryption
    enum CodingKeys: String, CodingKey {
        case id, title, dueDate, tagName, tagColorIndex, createdDate, isDone, recentlyDeleted, streaked
        case encryptedLatitude, encryptedLongitude, encryptedLocationDescription, gettingThere
    }
    
    mutating func setDone(_ state: Bool) {
        isDone = state
    }
    
    mutating func setRecentlyDeleted(_ state: Bool) {
        recentlyDeleted = state
    }
    
    // Helper method to convert Item to dictionary for Firestore
    func asDictionary() -> [String: Any] {
        return [
            "id": id,
            "title": title,
            "dueDate": dueDate,
            "tagName": tagName,
            "tagColorIndex": tagColorIndex,
            "createdDate": createdDate,
            "isDone": isDone,
            "recentlyDeleted": recentlyDeleted,
            "streaked": streaked,
            "encryptedLatitude": encryptedLatitude as Any,
            "encryptedLongitude": encryptedLongitude as Any,
            "encryptedLocationDescription": encryptedLocationDescription,
            "gettingThere": gettingThere
        ]
    }
}
