//
//  ToDoListApp.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import FirebaseCore
import SwiftUI
import CoreLocation
import FirebaseAuth

@main
struct ToDoListApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(locationManager)
                .onAppear {
                    // Connect the app delegate to the location manager
                    appDelegate.setLocationManager(locationManager)
                    
                    // Set up Firebase authentication listener
                    Auth.auth().addStateDidChangeListener { auth, user in
                        if let user = user {
                            locationManager.updateUserId(user.uid)
                            if let userDefaults = UserDefaults(suiteName: "group.com.yourappidentifier.widgetkit") {
                                print("DEBUG: Setting user ID in shared UserDefaults: \(user.uid)")
                                userDefaults.set(user.uid, forKey: "currentUserId")
                                userDefaults.synchronize()  // <-- Ensure it's written immediately
                                
                                // Immediately verify the set value
                                let storedUserId = userDefaults.string(forKey: "currentUserId")
                                print("DEBUG: Stored user ID after setting: \(storedUserId ?? "nil")")
                            } else {
                                print("DEBUG: Failed to create shared UserDefaults")
                            }
                        } else {
                            locationManager.clearUserId()
                            print("DEBUG: No user found, clearing user ID")
                            
                            if let userDefaults = UserDefaults(suiteName: "group.com.yourappidentifier.widgetkit") {
                                userDefaults.removeObject(forKey: "currentUserId")
                                print("DEBUG: Removed currentUserId from shared UserDefaults")
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    locationManager.applicationDidEnterBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    locationManager.applicationDidEnterForeground()
                }
        }
    }
}
