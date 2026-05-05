//
//  DesignTokens.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

/// Tokens de diseño basados en §6 del PRD.
/// Los fondos atmosféricos cambian según el estado de riesgo del usuario.
enum DesignTokens {

    // MARK: - Fondos atmosféricos (estado de toda la pantalla)

    static let bgGreen = Color(hex: 0xF4FAF8)   // vas bien
    static let bgPeach = Color(hex: 0xFDF8F3)   // precaución
    static let bgRed   = Color(hex: 0xFDF4F4)   // peligro DAC

    // MARK: - Hero cards (color del estado destacado)

    static let heroGreen = Color(hex: 0x7FB5A8)
    static let heroPeach = Color(hex: 0xE8A96A)
    static let heroRed   = Color(hex: 0xB85C5C)

    // MARK: - Acentos (botones, chips)

    static let accentSage    = Color(hex: 0x4A7C6F)
    static let accentTerra   = Color(hex: 0xC17F5A)

    // MARK: - Helpers para estado

    static func atmosphericBackground(for risk: DACMargin.RiskLevel) -> Color {
        switch risk {
        case .safe:    return bgGreen
        case .warning: return bgPeach
        case .danger:  return bgRed
        }
    }

    static func heroColor(for risk: DACMargin.RiskLevel) -> Color {
        switch risk {
        case .safe:    return heroGreen
        case .warning: return heroPeach
        case .danger:  return heroRed
        }
    }

    static func accentTabColor(for risk: DACMargin.RiskLevel) -> Color {
        switch risk {
        case .safe:    return accentSage
        case .warning: return accentTerra
        case .danger:  return heroRed
        }
    }

    // MARK: - Carbon levels

    static func carbonColor(for level: CarbonIntensity.Level) -> Color {
        switch level {
        case .clean:  return Color.green
        case .medium: return Color.orange
        case .dirty:  return Color.red
        }
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
