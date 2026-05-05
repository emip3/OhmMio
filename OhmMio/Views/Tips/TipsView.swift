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
        ZStack {
            DesignTokens.bgGreen.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Consejos")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(DesignTokens.accentSage)
                        .padding(.horizontal)
                        .padding(.top, 24)
                    
                    customSegmentedPicker
                        .padding(.horizontal)
                    
                    switch viewModel.state {
                    case .loading:
                        ProgressView().padding(.top, 40).frame(maxWidth: .infinity)
                    case .empty:
                        emptyState
                    case .error(let msg):
                        errorState(msg)
                    case .loaded(let recs, let nextClean):
                        content(recs: recs, nextCleanHour: nextClean)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .task { await viewModel.load() }
    }
    
    // MARK: - Custom Picker
    
    private var customSegmentedPicker: some View {
        HStack(spacing: 0) {
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
        .padding(6)
        .background(Color(.systemGray5).opacity(0.6))
        .clipShape(Capsule())
    }
    
    private func pickerTab(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body.weight(.bold))
                Text(title)
                    .font(.body.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.white : Color.clear)
            .foregroundStyle(isSelected ? DesignTokens.accentSage : Color.secondary.opacity(0.8))
            .clipShape(Capsule())
            .shadow(color: isSelected ? .black.opacity(0.08) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 20) {
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
        .padding(.top, 8)
    }

    // Modo aparatos
    private func devicesMode(recs: ApplianceRanker.RecommendationSet) -> some View {
        VStack(spacing: 16) {
            ForEach(recs.deviceTips) { tip in
                deviceCard(tip)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func tipCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.accentSage)
            Text(description)
                .font(.body.weight(.medium))
                .foregroundStyle(DesignTokens.accentSage.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: DesignTokens.accentSage.opacity(0.05), radius: 10, y: 4)
    }

    private func deviceCard(_ tip: ApplianceRanker.DeviceTip) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                Text("#\(tip.rank)")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(DesignTokens.accentTerra)
                
                Image(systemName: tip.appliance.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(DesignTokens.accentSage)
            }
            .frame(width: 44, alignment: .top)

            VStack(alignment: .leading, spacing: 6) {
                Text(tip.appliance.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.accentSage)
                
                Text(String(format: "%.1f kWh/día · %.0f%% del total",
                            tip.dailyKwh, tip.percentageOfTotal))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.heroGreen)
                
                Text(tip.advice)
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: DesignTokens.accentSage.opacity(0.05), radius: 10, y: 4)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 60))
                .foregroundStyle(DesignTokens.accentSage.opacity(0.5))
            Text("Sin datos suficientes")
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.accentSage)
            Text("Agrega tus aparatos en Perfil para recibir consejos.")
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.heroRed)
                .font(.system(size: 60))
            Text(msg)
                .font(.body.weight(.medium))
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
