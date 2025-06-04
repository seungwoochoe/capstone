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
    @State private var authSession:      ASWebAuthenticationSession?
    @State private var contextProvider = WebAuthContextProvider()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                category: #file)
    
    var body: some View {
        Button("Sign in with Apple") { startHostedUISignIn() }
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

private extension URL {
    func queryItem(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == name })?.value
    }
}

#Preview {
    SignInView()
}
