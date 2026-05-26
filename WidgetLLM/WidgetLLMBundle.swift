//
//  WidgetLLMBundle.swift
//  WidgetLLM
//
//  Created by Adrian Leventiu on 24.03.2025.
//

import WidgetKit
import SwiftUI
import Firebase

@main
struct WidgetLLMBundle: WidgetBundle {
    init() {
        // Configure Firebase only once
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    var body: some Widget {
        WidgetLLM()
    }
}
