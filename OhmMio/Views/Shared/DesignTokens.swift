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

// MARK: - Tipografía escalable (respeta Dynamic Type del sistema y la
// preferencia del usuario en Perfil → Tamaño de letra).
//
// Regla: usar SIEMPRE estos helpers en vez de `.system(size:)`. Cualquier
// tamaño hardcoded queda fuera del sistema de escalado.

extension Font {

    /// Hero number (margen DAC, kg CO₂ destacado). Antes era 56–64pt fijo.
    static var ohmHero: Font {
        .system(.largeTitle, design: .rounded, weight: .heavy)
    }

    /// Títulos grandes de pantalla. Antes era 42pt fijo.
    static var ohmDisplay: Font {
        .system(.title, design: .rounded, weight: .heavy)
    }

    /// Números destacados en cards (stats, kg CO₂ por hora).
    static var ohmStatNumber: Font {
        .system(.title2, design: .rounded, weight: .heavy)
    }

    /// Hora en celdas del grid. Antes era 20pt fijo.
    static var ohmGridHour: Font {
        .system(.callout, design: .rounded, weight: .bold)
    }

    /// Etiquetas de sección (AHORA, HOY POR HORAS, LEYENDA).
    static var ohmSectionLabel: Font {
        .footnote.weight(.heavy)
    }
}

// MARK: - Preferencia de tamaño de letra del usuario
//
// Usamos @AppStorage en vez de SwiftData para evitar migrar el schema
// de UserPreferences (es Codable y agregar campos podría romper datos
// existentes). DynamicTypeSize ya hace todo el trabajo pesado: solo se
// aplica una vez en el root con `.dynamicTypeSize(...)`.

enum AppTextSize: String, CaseIterable, Identifiable {
    case xSmall  = "xSmall"
    case small   = "small"
    case medium  = "medium"   // default — equivale al tamaño del sistema
    case large   = "large"
    case xLarge  = "xLarge"

    var id: String { rawValue }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .xSmall: return .xSmall
        case .small:  return .small
        case .medium: return .medium
        case .large:  return .large
        case .xLarge: return .xLarge
        }
    }

    var displayName: String {
        switch self {
        case .xSmall: return "Compacto"
        case .small:  return "Pequeño"
        case .medium: return "Mediano"
        case .large:  return "Grande"
        case .xLarge: return "Extra grande"
        }
    }

    /// Multiplicador relativo, útil para previsualizar la escala
    /// en el slider del perfil.
    var previewScale: CGFloat {
        switch self {
        case .xSmall: return 0.85
        case .small:  return 0.92
        case .medium: return 1.00
        case .large:  return 1.10
        case .xLarge: return 1.20
        }
    }
}
