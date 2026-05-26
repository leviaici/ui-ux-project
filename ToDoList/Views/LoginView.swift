//
//  LoginView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import SwiftUI
import UIKit

extension Color {
    static let coralPink = Color(red: 249/255, green: 157/255, blue: 140/255)
    static let cuteBlue = Color(red: 140/255, green: 157/255, blue: 249/255)
    static let appColor = Color(red: 236/255, green: 96/255, blue: 80/255)
}

struct LoginView: View {
    @StateObject private var viewModel = LoginViewViewModel()
    @State private var isKeyboardVisible = false

    var body: some View {
        NavigationView {
            VStack {
                // Header
                HeaderView(title: "To Do List", subtitle: "Never forget things again", angle: 30, background: .coralPink)
                
                // Login Form
                Form {
                    TextField("Email Address", text: $viewModel.email)
                        .textFieldStyle(DefaultTextFieldStyle())
                        .bold()
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(DefaultTextFieldStyle())
                        .bold()
                    
                    TLButton(title: "Login", background: .coralPink) {
                        viewModel.login()
                    }
                }
                .padding(.bottom, 30)
                .padding(.top, isKeyboardVisible ? -150 : 0)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    withAnimation {
                        isKeyboardVisible = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation {
                        isKeyboardVisible = false
                    }
                }
                .alert(isPresented: $viewModel.showAlert) {
                    Alert(
                        title: Text("Login Message"),
                        message: Text(viewModel.errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
                
                // Additional Options
                VStack {
                    Text("New here?")
                    NavigationLink("Create an Account", destination: RegisterView())
                        .foregroundColor(.coralPink)
                    
                    Button("Forgot your password?") {
                        popForgotPasswordAlert()
                    }
                    .foregroundColor(.coralPink)
                    
                    Button("Resend verification email") {
                        popResendVerificationAlert()
                    }
                    .foregroundColor(.coralPink)
                }
                .padding(.bottom, 10)
                
                Spacer()
            }
            .ignoresSafeArea(.keyboard)
        }
        .navigationBarBackButtonHidden(true)
    }
    
    func popForgotPasswordAlert() {
        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Reset Password",
            message: "Please provide the email address used for your account.",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "your_email@example.com"
            textField.text = viewModel.email // Pre-fill with current email if available
        }
        
        alert.addAction(UIAlertAction(
            title: "Send",
            style: .default,
            handler: { _ in
                if let emailTextField = alert.textFields?.first, let email = emailTextField.text {
                    viewModel.reset(email: email)
                }
            }
        ))

        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: nil
        ))

        viewController.present(alert, animated: true, completion: nil)
    }
    
    func popResendVerificationAlert() {
        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Resend Verification Email",
            message: "Please provide the email address for your unverified account.",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "your_email@example.com"
            textField.text = viewModel.email // Pre-fill with current email if available
        }
        
        alert.addAction(UIAlertAction(
            title: "Resend",
            style: .default,
            handler: { _ in
                if let emailTextField = alert.textFields?.first, let email = emailTextField.text {
                    viewModel.resendVerificationEmail(email: email)
                }
            }
        ))

        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: nil
        ))

        viewController.present(alert, animated: true, completion: nil)
    }
}
