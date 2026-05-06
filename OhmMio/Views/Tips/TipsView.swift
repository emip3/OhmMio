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
            ZStack {
                DesignTokens.bgGreen.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        customSegmentedPicker
                            .padding(.horizontal)
                            .padding(.top, 8)

                        switch viewModel.state {
                        case .loading:
                            ProgressView().padding(.top, 40).frame(maxWidth: .infinity)
                        case .empty:
                            emptyState
                        case .error(let msg):
                            errorState(msg)
                        case .loaded(let recs, let nextClean, let pricePerKwh):
                            content(recs: recs, nextCleanHour: nextClean, pricePerKwh: pricePerKwh)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            // Title nativo en lugar del custom 42pt en el body.
            .navigationTitle("Consejos")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await viewModel.load() }
    }

    // MARK: - Custom Picker

    private var customSegmentedPicker: some View {
        HStack(spacing: 12) {
            pickerTab(
                title: TipsViewModel.Category.timing.rawValue,
                icon: "clock.fill",
                isSelected: viewModel.selectedCategory == .timing
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.selectedCategory = .timing
                }
            }

            pickerTab(
                title: TipsViewModel.Category.devices.rawValue,
                icon: "bolt.fill",
                isSelected: viewModel.selectedCategory == .devices
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.selectedCategory = .devices
                }
            }
        }
    }

    private func pickerTab(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.white : Color.white.opacity(0.4),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? DesignTokens.accentSage : Color.secondary)
            .shadow(
                color: isSelected ? DesignTokens.accentSage.opacity(0.12) : .clear,
                radius: 8, y: 3
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Estados

    @ViewBuilder
    private func content(recs: ApplianceRanker.RecommendationSet, nextCleanHour: Int?, pricePerKwh: Double) -> some View {
        switch viewModel.selectedCategory {
        case .timing:
            timingMode(recs: recs, nextCleanHour: nextCleanHour)
        case .devices:
            devicesMode(recs: recs, pricePerKwh: pricePerKwh)
        }
    }

    // Modo timing
    private func timingMode(recs: ApplianceRanker.RecommendationSet, nextCleanHour: Int?) -> some View {
        VStack(spacing: 14) {
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
        .padding(.top, 4)
    }

    // Modo aparatos
    private func devicesMode(recs: ApplianceRanker.RecommendationSet, pricePerKwh: Double) -> some View {
        VStack(spacing: 12) {
            // Tarjeta explicativa
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.accentSage)
                    Text("Tu impacto por aparato")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.accentSage)
                }
                Text("Aquí ves qué aparatos consumen más en tu casa. El ranking (#1, #2…) te dice cuál pesa más en tu recibo mensual. La pastilla de color te indica qué tan urgente es actuar.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.accentSage.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 16))

            ForEach(recs.deviceTips) { tip in
                deviceCard(tip, pricePerKwh: pricePerKwh)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func tipCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignTokens.accentSage)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.accentSage.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: DesignTokens.accentSage.opacity(0.04), radius: 6, y: 2)
    }

    private func deviceCard(_ tip: ApplianceRanker.DeviceTip, pricePerKwh: Double) -> some View {
        let impactLevel: (label: String, color: Color) = {
            switch tip.percentageOfTotal {
            case ..<15: return ("Impacto bajo", DesignTokens.heroGreen)
            case ..<40: return ("Impacto medio", DesignTokens.heroPeach)
            default:    return ("Impacto alto", DesignTokens.heroRed)
            }
        }()

        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 8) {
                Text("#\(tip.rank)")
                    .font(.system(.title, design: .rounded, weight: .black))
                    .foregroundStyle(DesignTokens.accentTerra)
                Image(systemName: tip.appliance.sfSymbol)
                    .font(.title)
                    .foregroundStyle(DesignTokens.accentSage)
            }
            .frame(width: 52, alignment: .top)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tip.appliance.displayName)
                        .font(.headline)
                        .foregroundStyle(DesignTokens.accentSage)
                    Spacer()
                    Text(impactLevel.label)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(impactLevel.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(impactLevel.color.opacity(0.15), in: Capsule())
                }

                Text(String(format: "%.1f kWh/día · %.0f%% del consumo total",
                            tip.dailyKwh, tip.percentageOfTotal))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignTokens.heroGreen)

                Text(tip.advice)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: DesignTokens.accentSage.opacity(0.06), radius: 10, y: 4)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "lightbulb.slash")
                .font(.largeTitle)
                .foregroundStyle(DesignTokens.accentSage.opacity(0.5))
            Text("Sin datos suficientes")
                .font(.headline)
                .foregroundStyle(DesignTokens.accentSage)
            Text("Agrega tus aparatos en Perfil para recibir consejos.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.heroRed)
                .font(.largeTitle)
            Text(msg)
                .font(.callout)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.accentSage)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}
