import SwiftUI
import Supabase

enum AppScreen: Hashable {
    case intro
    case signIn
    case signUp
    case home
}

@MainActor
@Observable
final class AppRouter {
    var currentScreen: AppScreen = .intro
    var isLoading = true

    func checkAuth() async {
        do {
            _ = try await supabase.auth.session
            currentScreen = .home
        } catch {
            currentScreen = .intro
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
        currentScreen = .home
    }

    func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(email: email, password: password)
        currentScreen = .home
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentScreen = .intro
    }
}
