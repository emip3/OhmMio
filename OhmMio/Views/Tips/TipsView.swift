//
//  TipsView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

struct TipsView: View {

    @State var viewModel: TipsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Categoría", selection: $viewModel.selectedCategory) {
                        ForEach(TipsViewModel.Category.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch viewModel.state {
                    case .loading:
                        ProgressView().padding(.top, 40)
                    case .empty:
                        emptyState
                    case .error(let msg):
                        errorState(msg)
                    case .loaded(let recs, let nextClean):
                        content(recs: recs, nextCleanHour: nextClean)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Consejos")
            .background(DesignTokens.bgGreen.ignoresSafeArea())
        }
        .task { await viewModel.load() }
    }

    // MARK: - Estados

    @ViewBuilder
    private func content(recs: ApplianceRanker.RecommendationSet, nextCleanHour: Int?) -> some View {
        switch viewModel.selectedCategory {
        case .timing:
            timingMode(recs: recs, nextCleanHour: nextCleanHour)
        case .devices:
            devicesMode(recs: recs)
        }
    }

    // Modo timing
    private func timingMode(recs: ApplianceRanker.RecommendationSet, nextCleanHour: Int?) -> some View {
        VStack(spacing: 16) {
            ForEach(recs.timingTips) { tip in
                tipCard(title: tip.title, description: tip.description)
            }

            if let next = nextCleanHour {
                tipCard(
                    title: "Próxima ventana limpia",
                    description: "Alrededor de las \(next):00 puedes aprovechar la red más limpia para lavar, planchar o cargar dispositivos."
                )
            }
        }
        .padding(.horizontal)
    }

    // Modo aparatos
    private func devicesMode(recs: ApplianceRanker.RecommendationSet) -> some View {
        VStack(spacing: 12) {
            ForEach(recs.deviceTips) { tip in
                deviceCard(tip)
            }
        }
        .padding(.horizontal)
    }

    private func tipCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func deviceCard(_ tip: ApplianceRanker.DeviceTip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("#\(tip.rank)")
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.accentSage)
                .frame(width: 36)

            Image(systemName: tip.appliance.sfSymbol)
                .font(.title2)
                .foregroundStyle(Color.primary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text(tip.appliance.displayName)
                    .font(.headline)
                Text(String(format: "%.1f kWh/día · %.0f%% del total",
                            tip.dailyKwh, tip.percentageOfTotal))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(tip.advice)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 50))
                .foregroundStyle(Color.secondary)
            Text("Sin datos suficientes")
                .font(.headline)
            Text("Agrega tus aparatos en Perfil para recibir consejos.")
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.heroRed)
                .font(.system(size: 50))
            Text(msg).foregroundStyle(Color.secondary)
            Button("Reintentar") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.accentSage)
        }
        .padding(.top, 40)
    }
}
