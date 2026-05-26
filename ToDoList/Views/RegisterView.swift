//
//  RegisterView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import SwiftUI

struct RegisterView: View {
    @StateObject var viewModel = RegisterViewViewModel()
    @State private var isKeyboardVisible = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                // Header
                HeaderView(title: "To Do List", subtitle: "Account registration", angle: -30, background: .cuteBlue)
                
                // Registration Form
                Form {
                    TextField("Full name", text: $viewModel.name)
                        .textFieldStyle(DefaultTextFieldStyle()).bold()
                        .autocorrectionDisabled()
                    
                    DatePicker("Date of Birth", selection: $viewModel.birthday, in: ...Date(), displayedComponents: .date)
                    
                    TextField("Email Address", text: $viewModel.email)
                        .textFieldStyle(DefaultTextFieldStyle()).bold()
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(DefaultTextFieldStyle()).bold()
                    
                    TLButton(title: "Create Account", background: .cuteBlue) {
                        // Attempt to register an account
                        viewModel.register { success in
                            if success {
                                alertMessage = "A verification email has been sent. Please check your inbox."
                                showAlert = true
                            } else {
                                alertMessage = "Failed to send verification email. Please try again."
                                showAlert = true
                            }
                        }
                    }
                }
                .scrollDisabled(true)
                .ignoresSafeArea(.keyboard)
                .padding(.top, isKeyboardVisible ? -175 : -5)
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
                
                // Create Account
                VStack {
                    Text("Already have an Account?")
                    NavigationLink("Login", destination: LoginView())
                        .foregroundColor(.cuteBlue)
                }
                .padding(.bottom, 30)
                .ignoresSafeArea(.keyboard)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Registration"), message: Text(alertMessage), dismissButton: .default(Text("OK"), action: {
                    if alertMessage.contains("verification email has been sent") {
                        presentationMode.wrappedValue.dismiss() // Go back to login page
                    }
                }))
            }
            .ignoresSafeArea(.keyboard)
        }
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(.keyboard)
    }
}
