//
//  EncryptionService.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 22.04.2025.
//

import Foundation
import CryptoKit

class EncryptionService {
    private static let key: SymmetricKey = {
        // Generate a key from a passphrase
        let passphrase: String = {
            guard let path = Bundle.main.path(forResource: "key", ofType: "txt") else {
                fatalError("Encryption key file not found")
            }
            do {
                return try String(contentsOfFile: path).trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                fatalError("Failed to read Encryption key: \(error)")
            }
        }()
        let passphraseData = Data(passphrase.utf8)
        let hash = SHA256.hash(data: passphraseData)
        return SymmetricKey(data: hash)
    }()
    
    // Encrypt a string and return base64 encoded string
    static func encrypt(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        
        do {
            let textData = Data(text.utf8)
            let sealedBox = try AES.GCM.seal(textData, using: key)
            
            // Return the combined data as base64 string
            if let combined = sealedBox.combined {
                return combined.base64EncodedString()
            }
            return nil
        } catch {
            print("Encryption error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Decrypt a base64 encoded string
    static func decrypt(_ base64Text: String) -> String? {
        guard !base64Text.isEmpty else { return nil }
        
        do {
            // Convert base64 to Data
            guard let data = Data(base64Encoded: base64Text) else {
                return nil
            }
            
            // Create a sealed box from the combined data
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            
            // Decrypt and convert to string
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Encrypt a Double value
    static func encrypt(_ value: Double) -> String? {
        return encrypt(String(value))
    }
    
    // Decrypt a string to Double
    static func decryptToDouble(_ base64Text: String) -> Double? {
        guard let decryptedString = decrypt(base64Text) else {
            return nil
        }
        return Double(decryptedString)
    }
}
