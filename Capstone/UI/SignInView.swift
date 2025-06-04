//
//  SignInView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-06-03.
//

import SwiftUI
import AuthenticationServices
import OSLog

final class WebAuthContextProvider: NSObject,
                                    ASWebAuthenticationPresentationContextProviding {
    
    func presentationAnchor(for session: ASWebAuthenticationSession)
    -> ASPresentationAnchor {
        
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        ?? ASPresentationAnchor()
    }
}

struct SignInView: View {
    
    @Environment(\.injected) private var injected
    @State private var authSession: ASWebAuthenticationSession?
    @State private var contextProvider = WebAuthContextProvider()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                category: #file)
    
    var body: some View {
        ZStack {
            // Optional: background color or gradient
            Color(.systemGray6)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Welcome to\n3D Room Scanner")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button(action: startHostedUISignIn) {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        
                        Text("Sign in with Apple")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.vertical, 60)
        }
    }
    
    private func startHostedUISignIn() {
        let domain      = "capstone-auth.auth.ap-northeast-2.amazoncognito.com"
        let clientId    = "4oliffdd79l5mmkibr801lcn16"
        let redirectUri = "capstone://auth/callback"
        let state       = UUID().uuidString
        let nonce       = UUID().uuidString
        
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host   = domain
        comps.path   = "/oauth2/authorize"
        comps.queryItems = [
            .init(name: "response_type",     value: "code"),
            .init(name: "client_id",         value: clientId),
            .init(name: "redirect_uri",      value: redirectUri),
            .init(name: "scope",             value: "openid email profile"),
            .init(name: "identity_provider", value: "SignInWithApple"),
            .init(name: "state",             value: state),
            .init(name: "nonce",             value: nonce)
        ]
        
        guard let authURL = comps.url else { return }
        
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "capstone") { callbackURL, error in
                
                guard let url = callbackURL,
                      let code = url.queryItem(named: "code") else { return }
                
                Task {
                    do {
                        try await injected.interactors.authInteractor.completeSignIn(authorizationCode: code)
                    } catch {
                        logger.error("Failed to complete sign in: \(error)")
                    }
                }
            }
        
        authSession?.presentationContextProvider = contextProvider
        authSession?.prefersEphemeralWebBrowserSession = true  // optional
        authSession?.start()
    }
}

#Preview {
    SignInView()
}
