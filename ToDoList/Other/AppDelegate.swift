//
//  AppDelegate.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 12.10.2024.
//

import UserNotifications
import BackgroundTasks
import FirebaseAuth
import FirebaseCore
import Firebase
import SwiftUI
import MapKit
import CoreLocation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    weak var locationManager: LocationManager?
    let backgroundTaskIdentifier = "com.Levi.ToDoList.refresh"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notifications permissions: \(error.localizedDescription)")
            }
        }
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        // Register the background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Schedule the background task for the first time
        scheduleAppRefresh()
        
        return true
    }
    
    // Set reference to the LocationManager from your main app
    func setLocationManager(_ manager: LocationManager) {
        self.locationManager = manager
    }
    
    // Handle token registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Handle incoming notifications when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Handle background notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    // Schedule the background task
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1800) // Schedule for 30 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled for 30 minutes from now.")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    // Handle the background refresh task
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh first
        scheduleAppRefresh()
        
        // Get the location manager
        guard let locationManager = locationManager else {
            print("LocationManager not available for background refresh")
            task.setTaskCompleted(success: false)
            return
        }
        
        // Request a location update
        locationManager.requestSingleLocationUpdate()
        
        // Set up an expiration handler in case task takes too long
        task.expirationHandler = {
            print("Background task expired before completion")
            task.setTaskCompleted(success: false)
        }
        
        // Set up a timeout to ensure we complete the task
        let timeout = 25.0 // seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if let location = locationManager.location {
                locationManager.processLocationUpdateWithFallback(location)
                print("Background task completed with location")
            } else {
                print("Background task completed without location")
            }
            task.setTaskCompleted(success: true)
        }
    }
}
