//
//  MarginRingView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

/// Anillo circular animado del Dashboard.
/// Muestra el porcentaje de margen DAC con color según riesgo.
struct MarginRingView: View {

    let percentage: Double
    let riskLevel: DACMargin.RiskLevel
    var size: CGFloat = 220

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Track de fondo
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 16)

            // Trazo de progreso
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    DesignTokens.heroColor(for: riskLevel),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? .none : .easeOut(duration: 0.6),
                    value: clampedProgress
                )

            // Texto central — antes 56pt fijo, ahora estilo semántico
            // que respeta Dynamic Type y el tamaño elegido por el usuario.
            VStack(spacing: 2) {
                Text("\(Int(percentage))%")
                    .font(.ohmHero)
                    .foregroundStyle(Color.primary)
                    .contentTransition(.numericText())
                Text("margen")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityNarrative)
    }

    private var clampedProgress: Double {
        max(0, min(1, percentage / 100))
    }

    private var accessibilityNarrative: String {
        let p = Int(percentage)
        switch riskLevel {
        case .safe:
            return "\(p) por ciento de margen. Vas muy bien este bimestre."
        case .warning:
            return "\(p) por ciento de margen. Estás en zona de precaución."
        case .danger:
            return "\(p) por ciento de margen. Riesgo de cruzar el límite DAC."
        }
    }
}
