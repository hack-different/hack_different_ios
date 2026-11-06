//
//  SessionStore.swift
//  HackDifferent
//

import AudienceKit
import AuthenticationServices
import Foundation
import Observation

/// Authentication state of the Hack Different app.
public enum AuthenticationState: Equatable, Sendable {
    case restoring
    case signedOut
    case signingIn
    case signedIn
}

/// Manages Sign in with Apple, session persistence via `KeychainCredentialStore`,
/// and `AudienceSession.sessionEvents` monitoring.
@MainActor
@Observable
public final class SessionStore {
    public static let credentialStore = KeychainCredentialStore(
        service: "com.hackdifferent.app.session",
        account: "credential"
    )

    public private(set) var state: AuthenticationState = .restoring
    public private(set) var currentUser: SelfUser?
    public private(set) var errorMessage: String?
    public private(set) var sessionEndedBanner: String?
    public private(set) var isReviewSignInAvailable = false

    private let client: AudienceKitClient
    private let api: HackDifferentAPI
    private let configuration: AppConfiguration
    @ObservationIgnored private var eventsTask: Task<Void, Never>?

    public init(client: AudienceKitClient, api: HackDifferentAPI, configuration: AppConfiguration) {
        self.client = client
        self.api = api
        self.configuration = configuration
        observeSessionEvents()
    }

    deinit {
        eventsTask?.cancel()
    }

    public var isSignedIn: Bool {
        state == .signedIn
    }

    public func start() async {
        async let reviewCheck = api.isReviewSignInEnabled()
        await restoreSession()
        isReviewSignInAvailable = await reviewCheck
    }

    public func restoreSession() async {
        guard await client.isSignedIn else {
            state = .signedOut
            return
        }

        do {
            currentUser = try await client.me()
            state = .signedIn
            errorMessage = nil
        } catch let error as AudienceKitError where error.isUnauthenticated {
            currentUser = nil
            state = .signedOut
            sessionEndedBanner = "Your session expired. Please sign in again."
        } catch {
            // Keep signed-in state during transient offline blips
            state = .signedIn
        }
    }

    public func refreshProfile() async {
        guard let me = try? await client.me() else { return }
        currentUser = me
    }

    /// Handles the result of `SignInWithAppleButton` and exchanges the Apple identity token
    /// for an AudienceKit session bound to `hack-different.admin.audiencekit.com`.
    public func handleSignInWithApple(_ result: Result<ASAuthorization, any Error>) {
        errorMessage = nil
        sessionEndedBanner = nil

        let appleCredential: ASAuthorizationAppleIDCredential
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Apple did not return an Apple ID credential."
                state = .signedOut
                return
            }
            appleCredential = credential
        case let .failure(error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                state = .signedOut
                return
            }
            errorMessage = error.localizedDescription
            state = .signedOut
            return
        }

        guard let tokenData = appleCredential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            errorMessage = "Apple did not return an identity token."
            state = .signedOut
            return
        }

        let firstName = appleCredential.fullName?.givenName
        let lastName = appleCredential.fullName?.familyName
        let device = configuration.currentDeviceDescription()

        state = .signingIn
        Task {
            do {
                _ = try await client.signIn(
                    appleIdentityToken: identityToken,
                    firstName: firstName,
                    lastName: lastName,
                    device: device
                )
                currentUser = try? await client.me()
                state = .signedIn
            } catch let error as AudienceKitError {
                errorMessage = error.message
                state = .signedOut
            } catch {
                errorMessage = error.localizedDescription
                state = .signedOut
            }
        }
    }

    /// Signs in using an App Store Review code when enabled on the audience.
    public func signInWithReviewCode(_ code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        sessionEndedBanner = nil
        state = .signingIn

        do {
            let device = configuration.currentDeviceDescription()
            _ = try await api.signInWithReviewCode(trimmed, device: device)
            currentUser = try? await client.me()
            state = .signedIn
        } catch let error as AudienceKitError {
            errorMessage = error.message
            state = .signedOut
        } catch {
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    public func signOut() async {
        do {
            try await client.signOut()
        } catch {
            // Device is already signed out locally even if server revoke failed offline
        }
        currentUser = nil
        state = .signedOut
    }

    private func observeSessionEvents() {
        let stream = client.sessionEvents
        eventsTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                switch event {
                case .signedIn:
                    self.sessionEndedBanner = nil
                    self.state = .signedIn
                case .signedOut:
                    self.currentUser = nil
                    self.state = .signedOut
                case .sessionEnded:
                    self.currentUser = nil
                    self.sessionEndedBanner = "Your session ended. Please sign in again."
                    self.state = .signedOut
                }
            }
        }
    }
}
