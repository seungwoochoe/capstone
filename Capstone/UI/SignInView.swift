//
//  SignInView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-06-03.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    
    @Environment(\.injected) private var injected
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSigningIn = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("Welcome")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 8)
            
            Text("Sign in to continue")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if isSigningIn {
                ProgressView {
                    Text("Signing in…")
                }
            } else {
                SignInWithAppleButton(.signIn,
                                      onRequest: { request in
                    // Request the user’s full name and email (optional)
                    request.requestedScopes = [.fullName, .email]
                },
                                      onCompletion: handleAuthorizationResult)
                .signInWithAppleButtonStyle(appleButtonStyle(for: colorScheme))
                .frame(height: 50)
                .cornerRadius(8)
                .padding(.horizontal)
                .shadow(radius: 4)
            }
            
            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Sign-In Failed"),
                  message: Text(alertMessage ?? "Unknown error"),
                  dismissButton: .default(Text("OK")))
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Choose black or white style depending on light/dark mode
    private func appleButtonStyle(for scheme: ColorScheme) -> SignInWithAppleButton.Style {
        switch scheme {
        case .dark:
            return .white
        default:
            return .black
        }
    }
    
    private func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.alertMessage = "Unable to get Apple ID credential."
                self.showAlert = true
                return
            }
            
            // Extract the identity token (this is a JWT from Apple)
            guard let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                self.alertMessage = "Unable to fetch identity token."
                self.showAlert = true
                return
            }
            
            // Call our interactor
            isSigningIn = true
            Task {
                do {
                    try await injected.interactors.authInteractor.signIn(with: tokenString)
                    await MainActor.run {
                        self.isSigningIn = false
                        // Dismiss or navigate away on success
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        self.isSigningIn = false
                        self.alertMessage = error.localizedDescription
                        self.showAlert = true
                    }
                }
            }
            
        case .failure(let error):
            self.alertMessage = error.localizedDescription
            self.showAlert = true
        }
    }
}

#Preview {
    SignInView()
}
