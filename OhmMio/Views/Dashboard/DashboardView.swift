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
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // El header custom de 42pt se reemplazó por el
                        // navigationTitle con large display (más Apple).
                        // Solo dejamos la fecha como subtítulo discreto.
                        HStack {
                            Text(todayString)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)

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
                .scrollIndicators(.hidden)
                .refreshable {
                    await viewModel.load()
                }
            }
            .navigationTitle("OhMio")
            .navigationBarTitleDisplayMode(.large)
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

    @ViewBuilder
    private func loadedContent(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(spacing: 16) {
            heroCard(data)
            actionCard(data)
            carbonNetworkCard(data)
        }
        .sheet(isPresented: $showDetailsSheet) {
            decisionDetailsSheet(data)
        }
    }

    // MARK: - Hero card (margen DAC)

    private func heroCard(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            // Chip "Margen antes del DAC" — más pequeño y refinado
            Text("Margen antes del DAC")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.22), in: Capsule())
                .foregroundStyle(.white)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heroTitle(for: data.riskLevel))
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(heroSubtitle(for: data.riskLevel, margin: data.marginKwh))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: -2) {
                    // El número grande baja de 64pt a .ohmHero (largeTitle
                    // rounded heavy ≈ 34pt en default, escalable).
                    Text(heroMarginPrefix(for: data.riskLevel) + "\(abs(data.marginKwh))")
                        .font(.ohmHero)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(heroMarginSuffix(for: data.riskLevel))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.vertical, 4)

            VStack(spacing: 6) {
                GeometryReader { geo in
                    let pct = CGFloat(min(1, max(0, data.marginPercentage / 100)))
                    let fillW = geo.size.width * pct
                    let boltSize: CGFloat = 32
                    let barH: CGFloat = 18
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: barH)
                        Capsule()
                            .fill(.white)
                            .frame(width: fillW, height: barH)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(dynamicHeroColor)
                            .frame(width: boltSize, height: boltSize)
                            .background(Color.white, in: Circle())
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                            .offset(x: min(max(0, fillW - boltSize / 2), geo.size.width - boltSize))
                    }
                    .frame(height: boltSize, alignment: .center)
                }
                .frame(height: 32)

                HStack {
                    Text("0%")
                    Spacer()
                    Text("\(Int(data.marginPercentage))% de margen")
                    Spacer()
                    Text("Límite")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(18)
        .background(dynamicHeroColor, in: RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Action card (consejo del día)

    private func actionCard(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TU CONSEJO DE HOY")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Color.secondary)
                .padding(.bottom, 8)

            Button(action: { showDetailsSheet = true }) {
                VStack(alignment: .leading, spacing: 14) {
                    // Aparato + urgencia
                    HStack(spacing: 12) {
                        Image(systemName: data.actionDecision.applianceSFSymbol)
                            .font(.title3)
                            .foregroundStyle(dynamicHeroColor)
                            .frame(width: 36, height: 36)
                            .background(dynamicHeroColor.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 1) {
                            Text("OhMio dice")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                            Text(data.actionDecision.applianceDisplayName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.primary)
                        }
                        Spacer()
                        urgencyChip(for: data.actionDecision.urgency)
                    }

                    // Narrativa
                    Text(data.narrativeText)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    // Stats inline
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: "%.1f", data.actionDecision.estimatedKwhSaved))
                                .font(.ohmStatNumber)
                                .foregroundStyle(Color.primary)
                                .contentTransition(.numericText())
                            Text("kWh ahorrados")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider().frame(height: 32)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: "%.2f", data.actionDecision.estimatedCO2Saved))
                                .font(.ohmStatNumber)
                                .foregroundStyle(Color.primary)
                                .contentTransition(.numericText())
                            Text("kg CO\u{2082} evitados")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 14)
                    }

                    // CTA
                    HStack(spacing: 4) {
                        Text("Ver más detalles")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(dynamicHeroColor)
                        Image(systemName: "arrow.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(dynamicHeroColor)
                    }
                }
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
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
            .font(.caption2.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }

    // MARK: - Card de estado de la red

    private func carbonNetworkCard(_ data: DashboardViewModel.DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ESTADO DE LA RED")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Color.secondary)

            HStack(spacing: 12) {
                Image(systemName: carbonIcon(for: data.currentCarbonLevel))
                    .font(.title3)
                    .foregroundStyle(carbonColor(for: data.currentCarbonLevel))
                    .frame(width: 38, height: 38)
                    .background(
                        carbonColor(for: data.currentCarbonLevel).opacity(0.12),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(carbonTitle(for: data.currentCarbonLevel))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(data.currentCarbonAdvice)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
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
        VStack(spacing: 14) {
            Image(systemName: "doc.text.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(DesignTokens.accentSage)
            Text("Aún no tenemos tu recibo")
                .font(.headline)
            Text("Escanea tu primer recibo CFE desde tu Perfil para empezar.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
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
                VStack(alignment: .leading, spacing: 14) {
                    Text(data.actionDecision.applianceDisplayName)
                        .font(.title3.weight(.bold))
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
            .presentationDragIndicator(.visible)
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
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: Date()).capitalized
    }
}
