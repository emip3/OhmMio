//
//  ActionCardView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

/// Tarjeta del consejo del día en el Dashboard.
/// Muestra el aparato priorizado, narrativa contextual y métricas de impacto.
struct ActionCardView: View {

    let decision: ActionDecision
    let narrativeText: String
    var onTapDetails: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header con ícono y nombre del aparato
            HStack(spacing: 12) {
                Image(systemName: decision.applianceSFSymbol)
                    .font(.title2)
                    .foregroundStyle(DesignTokens.accentSage)
                    .frame(width: 36, height: 36)
                    .background(DesignTokens.bgGreen)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("OhMio dice")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Text(decision.applianceDisplayName)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                }

                Spacer()

                urgencyChip
            }

            // Narrativa generada por Foundation Models (con fallback)
            Text(narrativeText)
                .font(.body)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Métricas de impacto (grid 2x1)
            HStack(spacing: 16) {
                metric(
                    label: "kWh ahorrados",
                    value: String(format: "%.1f", decision.estimatedKwhSaved)
                )
                Divider().frame(height: 32)
                metric(
                    label: "kg CO₂ evitados",
                    value: String(format: "%.2f", decision.estimatedCO2Saved)
                )
            }

            // Botón "Ver más detalles"
            if let onTapDetails {
                Button(action: onTapDetails) {
                    HStack {
                        Text("Ver más detalles")
                        Image(systemName: "arrow.right")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DesignTokens.accentSage)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Consejo: \(decision.applianceDisplayName). \(narrativeText)"
        )
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var urgencyChip: some View {
        let (text, color) = urgencyStyle
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var urgencyStyle: (String, Color) {
        switch decision.urgency {
        case .high:   return ("Urgente", DesignTokens.heroRed)
        case .medium: return ("Importante", DesignTokens.heroPeach)
        case .low:    return ("Aprovecha", DesignTokens.heroGreen)
        }
    }
}
