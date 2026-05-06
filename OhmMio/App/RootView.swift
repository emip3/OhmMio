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
///
/// También aplica la preferencia global de tamaño de letra que el
/// usuario controla desde Perfil → Ajustes → Tamaño de letra.
struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    @State private var storage: StorageService?
    @State private var didBootstrap = false

    /// Preferencia persistida del tamaño de letra. Default `.medium`,
    /// que corresponde al tamaño base del sistema (Dynamic Type).
    @AppStorage("preferredTextSize") private var preferredTextSizeRaw: String = AppTextSize.medium.rawValue

    private var preferredTextSize: AppTextSize {
        AppTextSize(rawValue: preferredTextSizeRaw) ?? .medium
    }

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
        // Una sola línea hace que TODA la app respete el tamaño de letra
        // elegido. Funciona en cualquier vista que use estilos semánticos
        // (.body, .title, .headline, etc.) en vez de tamaños hardcoded.
        .dynamicTypeSize(preferredTextSize.dynamicTypeSize)
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
