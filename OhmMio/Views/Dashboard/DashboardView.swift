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
            VStack(alignment: .leading, spacing: 4) {
                Text("OhMio")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(DesignTokens.accentSage)
                Text(todayString)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func loadedContent(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(spacing: 20) {
            heroCard(data)
            statsGrid(data)
            actionCard(data)
            // Ya no mostramos la seccion "ESTADO DE LA RED" separada, 
            // el ActionCard ("OhMio dice") ya incluye un buen mensaje. 
            // Si queremos mantener la CarbonCard, la ponemos aquí.
        }
        .sheet(isPresented: $showDetailsSheet) {
            decisionDetailsSheet(data)
        }
    }

    private func heroCard(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Margen antes del DAC")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.25))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heroTitle(for: data.riskLevel))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(0)
                    Text(heroSubtitle(for: data.riskLevel, margin: data.marginKwh))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: -4) {
                    Text(heroMarginPrefix(for: data.riskLevel) + "\(abs(data.marginKwh))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(heroMarginSuffix(for: data.riskLevel))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(.white)
                            .frame(width: geo.size.width * CGFloat(min(1, max(0, data.marginPercentage / 100))), height: 6)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("0 kWh")
                    Spacer()
                    Text("Límite")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(DesignTokens.heroColor(for: data.riskLevel))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func statsGrid(_ data: DashboardViewModel.DashboardData) -> some View {
        HStack(spacing: 16) {
            statCard(
                title: "Impacto diario",
                value: String(format: "%.1f", data.actionDecision.estimatedKwhSaved),
                unit: "kWh evitado",
                chipText: "potencial",
                chipColor: DesignTokens.accentSage
            )
            
            statCard(
                title: "Ahorro al mes",
                value: String(format: "$%.0f", data.actionDecision.estimatedMXNSaved),
                unit: "pesos",
                chipText: "estimado",
                chipColor: DesignTokens.accentTerra
            )
        }
    }
    
    private func statCard(title: String, value: String, unit: String, chipText: String, chipColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.secondary)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            
            Text(chipText)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(chipColor.opacity(0.15))
                .foregroundStyle(chipColor)
                .clipShape(Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func actionCard(_ data: DashboardViewModel.DashboardData) -> some View {
        Button(action: { showDetailsSheet = true }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(DesignTokens.heroColor(for: data.riskLevel))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("OhMio dice")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.heroColor(for: data.riskLevel))
                    
                    Text(data.narrativeText)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DesignTokens.heroColor(for: data.riskLevel).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
    
    private func heroTitle(for risk: DACMargin.RiskLevel) -> String {
        switch risk {
        case .safe: return "Vas muy\nbien"
        case .warning: return "Con\ncuidado"
        case .danger: return "Actúa\nhoy"
        }
    }
    
    private func heroSubtitle(for risk: DACMargin.RiskLevel, margin: Int) -> String {
        switch risk {
        case .safe: return "Margen amplio este bimestre"
        case .warning: return "Te faltan \(margin) kWh"
        case .danger: return "Superaste el límite DAC"
        }
    }

    private func heroMarginPrefix(for risk: DACMargin.RiskLevel) -> String {
        switch risk {
        case .safe: return "+"
        case .warning: return ""
        case .danger: return "-"
        }
    }

    private func heroMarginSuffix(for risk: DACMargin.RiskLevel) -> String {
        switch risk {
        case .safe: return "kWh de margen"
        case .warning: return "kWh restantes"
        case .danger: return "kWh excedidos"
        }
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).capitalized
    }
}
