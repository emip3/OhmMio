//
//  RootView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI
import SwiftData

/// Decide qué pantalla mostrar al iniciar la app:
/// - Si el usuario aún no completó onboarding → `OnboardingView`
/// - Si ya lo completó → `MainTabView`
///
/// Mantiene una sola fuente de verdad (`User` desde SwiftData) y
/// construye el `StorageService` compartido para toda la app.
struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    @State private var storage: StorageService?
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if let storage {
                content(storage: storage)
                    .preferredColorScheme(preferredColorScheme)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignTokens.bgGreen.ignoresSafeArea())
            }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            bootstrap()
        }
    }

    @ViewBuilder
    private func content(storage: StorageService) -> some View {
        if let user = users.first, user.hasCompletedOnboarding {
            MainTabView(storage: storage)
        } else {
            OnboardingView(
                viewModel: OnboardingViewModel(storage: storage),
                onComplete: {
                    // El cambio en `user.hasCompletedOnboarding` triggerea
                    // automáticamente la rama del if gracias a @Query.
                }
            )
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        let service = StorageService(context: modelContext)
        // Asegura que existe un User (se crea si no había).
        _ = try? service.loadOrCreateUser()
        storage = service
    }

    // MARK: - Color scheme

    private var preferredColorScheme: ColorScheme? {
        guard let pref = users.first?.preferences.preferredColorScheme else { return nil }
        switch pref {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
