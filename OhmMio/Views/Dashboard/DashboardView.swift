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

    private var dynamicHeroColor: Color {
        if case .loaded(let data) = viewModel.state {
            return DesignTokens.heroColor(for: data.riskLevel)
        }
        return DesignTokens.accentSage
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("OhMio")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(dynamicHeroColor)
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
            actionCard(data)
            carbonNetworkCard(data)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(heroTitle(for: data.riskLevel))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(heroSubtitle(for: data.riskLevel, margin: data.marginKwh))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: -4) {
                    Text(heroMarginPrefix(for: data.riskLevel) + "\(abs(data.marginKwh))")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(heroMarginSuffix(for: data.riskLevel))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.vertical, 8)

            VStack(spacing: 8) {
                GeometryReader { geo in
                    let pct = CGFloat(min(1, max(0, data.marginPercentage / 100)))
                    let fillW = geo.size.width * pct
                    let boltSize: CGFloat = 40
                    let barH: CGFloat = 24
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: barH)
                        Capsule()
                            .fill(.white)
                            .frame(width: fillW, height: barH)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(dynamicHeroColor)
                            .frame(width: boltSize, height: boltSize)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                            .offset(x: min(max(0, fillW - boltSize / 2), geo.size.width - boltSize))
                    }
                    .frame(height: boltSize, alignment: .center)
                }
                .frame(height: 40)

                HStack {
                    Text("0%")
                    Spacer()
                    Text("\(Int(data.marginPercentage))% de margen")
                    Spacer()
                    Text("Límite")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(20)
        .background(dynamicHeroColor)
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
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline.weight(.medium))
                .foregroundStyle(Color.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.secondary)
            }
            
            Text(chipText)
                .font(.caption.weight(.heavy))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(chipColor.opacity(0.15))
                .foregroundStyle(chipColor)
                .clipShape(Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func actionCard(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("TU CONSEJO DE HOY")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.secondary)
                .padding(.bottom, 12)

            Button(action: { showDetailsSheet = true }) {
                VStack(alignment: .leading, spacing: 16) {
                    // Aparato + urgencia
                    HStack(spacing: 12) {
                        Image(systemName: data.actionDecision.applianceSFSymbol)
                            .font(.title2)
                            .foregroundStyle(dynamicHeroColor)
                            .frame(width: 40, height: 40)
                            .background(dynamicHeroColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("OhMio dice")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Text(data.actionDecision.applianceDisplayName)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.primary)
                        }
                        Spacer()
                        urgencyChip(for: data.actionDecision.urgency)
                    }

                    // Narrativa
                    Text(data.narrativeText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    // Stats inline
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f", data.actionDecision.estimatedKwhSaved))
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(Color.primary)
                            Text("kWh ahorrados")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider().frame(height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.2f", data.actionDecision.estimatedCO2Saved))
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(Color.primary)
                            Text("kg CO\u{2082} evitados")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                    }

                    // CTA
                    HStack(spacing: 4) {
                        Text("Ver más detalles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(dynamicHeroColor)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(dynamicHeroColor)
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
        }
    }

    private func urgencyChip(for urgency: ActionDecision.Urgency) -> some View {
        let (label, color): (String, Color) = switch urgency {
        case .high:   ("Importante", DesignTokens.heroPeach)
        case .medium: ("Sugerido",   DesignTokens.heroGreen)
        case .low:    ("Opcional",   DesignTokens.accentSage)
        }
        return Text(label)
            .font(.caption.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func carbonNetworkCard(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ESTADO DE LA RED")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.secondary)

            HStack(spacing: 14) {
                Image(systemName: carbonIcon(for: data.currentCarbonLevel))
                    .font(.title2)
                    .foregroundStyle(carbonColor(for: data.currentCarbonLevel))
                    .frame(width: 44, height: 44)
                    .background(carbonColor(for: data.currentCarbonLevel).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(carbonTitle(for: data.currentCarbonLevel))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.primary)
                    Text(data.currentCarbonAdvice)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        }
    }

    private func carbonTitle(for level: CarbonIntensity.Level) -> String {
        switch level {
        case .clean:  return "Red limpia ahora"
        case .medium: return "Red en mezcla típica"
        case .dirty:  return "Pico de demanda"
        }
    }

    private func carbonIcon(for level: CarbonIntensity.Level) -> String {
        switch level {
        case .clean:  return "leaf.fill"
        case .medium: return "clock.fill"
        case .dirty:  return "exclamationmark.triangle.fill"
        }
    }

    private func carbonColor(for level: CarbonIntensity.Level) -> Color {
        switch level {
        case .clean:  return DesignTokens.heroGreen
        case .medium: return DesignTokens.heroPeach
        case .dirty:  return DesignTokens.heroRed
        }
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
