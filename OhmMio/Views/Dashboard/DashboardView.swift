//
//  DashboardView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

struct DashboardView: View {

    @State var viewModel: DashboardViewModel
    var onNavigateToCarbonMap: () -> Void = {}

    @State private var showDetailsSheet = false

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header

                    switch viewModel.state {
                    case .loading:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                    case .empty:
                        emptyState
                    case .error(let message):
                        errorState(message)
                    case .loaded(let data):
                        loadedContent(data)
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.load()
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("OhMio")
                    .font(.largeTitle.weight(.bold))
                Text(todayString)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func loadedContent(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(spacing: 24) {
            // Anillo de margen
            VStack(spacing: 12) {
                MarginRingView(
                    percentage: data.marginPercentage,
                    riskLevel: data.riskLevel
                )
                Text("Te quedan \(data.marginKwh) kWh este mes dentro de tu presupuesto.")
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }

            // Sección consejo del día
            VStack(alignment: .leading, spacing: 12) {
                Text("TU CONSEJO DE HOY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)

                ActionCardView(
                    decision: data.actionDecision,
                    narrativeText: data.narrativeText,
                    onTapDetails: { showDetailsSheet = true }
                )
            }

            // Sección estado de la red
            VStack(alignment: .leading, spacing: 12) {
                Text("ESTADO DE LA RED")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)

                carbonCard(data)
            }
        }
        .sheet(isPresented: $showDetailsSheet) {
            decisionDetailsSheet(data)
        }
    }

    private func carbonCard(_ data: DashboardViewModel.DashboardData) -> some View {
        HStack(spacing: 12) {
            Image(systemName: data.currentCarbonLevel == .clean ? "leaf.fill" : "flame.fill")
                .font(.title2)
                .foregroundStyle(DesignTokens.carbonColor(for: data.currentCarbonLevel))

            VStack(alignment: .leading, spacing: 4) {
                Text(carbonTitle(data.currentCarbonLevel))
                    .font(.headline)
                Text(data.currentCarbonAdvice)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button {
                onNavigateToCarbonMap()
            } label: {
                HStack(spacing: 4) {
                    Text("Mapa")
                    Image(systemName: "arrow.right")
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(DesignTokens.accentSage)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(DesignTokens.accentSage)
            Text("Aún no tenemos tu recibo")
                .font(.headline)
            Text("Escanea tu primer recibo CFE desde tu Perfil para empezar.")
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(DesignTokens.heroRed)
            Text("Algo salió mal")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.accentSage)
        }
        .padding()
    }

    private func decisionDetailsSheet(_ data: DashboardViewModel.DashboardData) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(data.actionDecision.applianceDisplayName)
                        .font(.title.weight(.bold))
                    Text(data.narrativeText)
                        .font(.body)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Impacto estimado").font(.headline)
                        detailRow("kWh ahorrados/día",
                                  String(format: "%.1f", data.actionDecision.estimatedKwhSaved))
                        detailRow("kg CO₂ evitados",
                                  String(format: "%.2f", data.actionDecision.estimatedCO2Saved))
                        detailRow("Ahorro estimado/mes",
                                  String(format: "$%.0f MXN", data.actionDecision.estimatedMXNSaved))
                    }
                }
                .padding()
            }
            .navigationTitle("Detalle del consejo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.secondary)
            Spacer()
            Text(value).font(.body.weight(.medium))
        }
    }

    // MARK: - Helpers

    private var backgroundColor: Color {
        if case .loaded(let data) = viewModel.state {
            return DesignTokens.atmosphericBackground(for: data.riskLevel)
        }
        return DesignTokens.bgGreen
    }

    private func carbonTitle(_ level: CarbonIntensity.Level) -> String {
        switch level {
        case .clean:  return "Red limpia"
        case .medium: return "Red en mezcla típica"
        case .dirty:  return "Pico de demanda"
        }
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).capitalized
    }
}
