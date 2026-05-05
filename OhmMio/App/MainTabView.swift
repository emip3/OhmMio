//
//  MainTabView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

/// Tab bar principal con las 4 pestañas del PRD (§6).
/// El tinte del tab activo cambia según el estado de riesgo actual del usuario.
struct MainTabView: View {

    let storage: StorageService

    @State private var selection: Tab = .home
    @State private var dashboardViewModel: DashboardViewModel
    @State private var tipsViewModel: TipsViewModel
    @State private var carbonMapViewModel: CarbonMapViewModel
    @State private var profileViewModel: ProfileViewModel

    enum Tab: Hashable {
        case home, tips, carbon, profile
    }

    init(storage: StorageService) {
        self.storage = storage
        _dashboardViewModel  = State(initialValue: DashboardViewModel(storage: storage))
        _tipsViewModel       = State(initialValue: TipsViewModel(storage: storage))
        _carbonMapViewModel  = State(initialValue: CarbonMapViewModel())
        _profileViewModel    = State(initialValue: ProfileViewModel(storage: storage))
    }

    var body: some View {
        TabView(selection: $selection) {

            DashboardView(
                viewModel: dashboardViewModel,
                onNavigateToCarbonMap: { selection = .carbon }
            )
            .tabItem {
                Label("Inicio", systemImage: "house.fill")
            }
            .tag(Tab.home)

            TipsView(viewModel: tipsViewModel)
                .tabItem {
                    Label("Consejos", systemImage: "lightbulb.fill")
                }
                .tag(Tab.tips)

            CarbonMapView(viewModel: carbonMapViewModel)
                .tabItem {
                    Label("Red", systemImage: "calendar")
                }
                .tag(Tab.carbon)

            ProfileView(viewModel: profileViewModel)
                .tabItem {
                    Label("Perfil", systemImage: "gearshape.fill")
                }
                .tag(Tab.profile)
        }
        .tint(activeTabTint)
    }

    /// Tinte dinámico del tab activo según riesgo (§6 del PRD).
    /// Lee del último cómputo del Dashboard; default sage.
    private var activeTabTint: Color {
        if case .loaded(let data) = dashboardViewModel.state {
            return DesignTokens.accentTabColor(for: data.riskLevel)
        }
        return DesignTokens.accentSage
    }
}
