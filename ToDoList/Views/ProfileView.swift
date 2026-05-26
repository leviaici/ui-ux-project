//
//  ProfileView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel = ProfileViewViewModel()
    @State private var isWalking: Bool = true
    @State private var showingDeleteConfirmation = false
    @State private var showingLogoutConfirmation = false
    @State private var showingNameChangeDialog = false
    @State private var showingEmailChangeDialog = false
    @State private var showingPasswordChangeConfirmation = false
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var currentPassword = ""
    @State private var showingPasswordResetSuccess = false
    @State private var showingEmailChangeSuccess = false
    @State private var showingEmailChangeError = false
    @State private var emailChangeErrorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let user = viewModel.user {
                    VStack(spacing: 8) {
                        // Avatar and Name Section
                        HStack(spacing: 24) {
                            Image(systemName: "person.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.appColor)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(Color.appColor.opacity(0.1))
                                        .frame(width: 88, height: 88)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.title3)
                                    .fontWeight(.bold)

                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 16) {
                                    Button(action: {
                                        newName = user.name
                                        showingNameChangeDialog = true
                                    }) {
                                        Label("Edit Name", systemImage: "pencil")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.appColor)
                                    }

                                    Button(action: {
                                        newEmail = user.email
                                        currentPassword = ""
                                        showingEmailChangeDialog = true
                                    }) {
                                        Label("Edit Email", systemImage: "envelope")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.appColor)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                        // Stats Row
                        HStack(spacing: 16) {
                            StatCard(
                                icon: "calendar",
                                title: "Member since",
                                value: Date(timeIntervalSince1970: user.joined).formatted(date: .abbreviated, time: .omitted)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )

                            StatCard(
                                icon: "graduationcap",
                                title: "Current Streak",
                                value: user.streak > 1 ? "\(user.streak) tasks" : "\(user.streak) task"
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                        }
                        .padding(.top, 12)
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    VStack(spacing: 24) {
                        // Transportation Preference — adults only
                        if viewModel.isAdult {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: isWalking ? "figure.walk" : "car.fill")
                                        .foregroundColor(.appColor)
                                        .font(.system(size: 20))
                                        .frame(width: 30)

                                    Toggle(isOn: $isWalking) {
                                        Text(isWalking ? "Getting there: by foot" : "Getting there: by car")
                                            .font(.headline)
                                    }
                                    .toggleStyle(ToggleButton())
                                    .onChange(of: isWalking) { newValue in
                                        viewModel.user?.gettingThere = newValue ? 0 : 1
                                        viewModel.updateGettingThere()
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                            .padding(.horizontal)
                        }

                        // Action Buttons
                        VStack(spacing: 16) {
                            ActionButton(
                                title: "Change Password",
                                icon: "lock.rotation",
                                color: Color.appColor
                            ) {
                                showingPasswordChangeConfirmation = true
                            }

                            ActionButton(
                                title: "Log out",
                                icon: "rectangle.portrait.and.arrow.right",
                                color: Color.appColor
                            ) {
                                showingLogoutConfirmation = true
                            }

                            ActionButton(
                                title: "Delete Account",
                                icon: "trash",
                                color: Color.red
                            ) {
                                showingDeleteConfirmation = true
                            }
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding(.top, 16)

                } else {
                    // Loading State
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.bottom, 8)

                        Text("Loading profile...")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        ActionButton(
                            title: "Log out",
                            icon: "rectangle.portrait.and.arrow.right",
                            color: Color.appColor
                        ) {
                            showingLogoutConfirmation = true
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Log Out", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) { viewModel.logout() }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { viewModel.deleteAccount() }
            } message: {
                Text("Are you sure you want to delete your account? This will permanently remove all your data from our database and cannot be undone.")
            }
            .alert("Change Password", isPresented: $showingPasswordChangeConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send Email", role: .none) {
                    if viewModel.sendPasswordResetEmail() {
                        showingPasswordResetSuccess = true
                    }
                }
            } message: {
                Text("We'll send a password reset link to your email address. Would you like to proceed?")
            }
            .alert("Email Sent", isPresented: $showingPasswordResetSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A password reset link has been sent to your email address. Please check your inbox.")
            }
            .alert("Email Updated", isPresented: $showingEmailChangeSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your email has been successfully updated. Please use your new email for future logins.")
            }
            .alert("Error", isPresented: $showingEmailChangeError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(emailChangeErrorMessage)
            }
            .sheet(isPresented: $showingNameChangeDialog) {
                DialogView(title: "Update Your Name") {
                    TextField("New Name", text: $newName)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .padding(.bottom)

                    HStack(spacing: 15) {
                        Button("Cancel") { showingNameChangeDialog = false }
                            .buttonStyle(SecondaryButtonStyle())

                        Button("Save") {
                            if !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.updateUserName(newName: newName)
                                showingNameChangeDialog = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .sheet(isPresented: $showingEmailChangeDialog) {
                DialogView(title: "Update Your Email") {
                    TextField("New Email", text: $newEmail)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .padding(.bottom, 10)

                    SecureField("Current Password", text: $currentPassword)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .padding(.bottom, 20)

                    HStack(spacing: 15) {
                        Button("Cancel") { showingEmailChangeDialog = false }
                            .buttonStyle(SecondaryButtonStyle())

                        Button("Update") {
                            if !newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !currentPassword.isEmpty {
                                viewModel.updateUserEmail(newEmail: newEmail, currentPassword: currentPassword) { success, message in
                                    if success {
                                        showingEmailChangeSuccess = true
                                        showingEmailChangeDialog = false
                                    } else {
                                        emailChangeErrorMessage = message
                                        showingEmailChangeError = true
                                    }
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetch()
        }
        .onReceive(viewModel.$user) { user in
            if let user = user {
                isWalking = (user.gettingThere == 0)
            }
        }
    }
}

// MARK: - Supporting Views (unchanged)

struct StatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.appColor)
                .font(.system(size: 18))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.appColor.opacity(0.1)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 24)
                Text(title)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(height: 54)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 3)
            )
        }
    }
}

struct DialogView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
                .padding(.top, 20)
            content
                .padding(.horizontal)
        }
        .frame(width: 320)
        .padding(.vertical, 15)
        .presentationDetents([.height(280)])
    }
}

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.appColor, lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 30)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appColor)
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .padding(.vertical, 12)
            .padding(.horizontal, 30)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
                    .opacity(configuration.isPressed ? 0.6 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
