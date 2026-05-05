//
//  DACMargin.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

struct DACMargin: Codable, Equatable, Hashable {
    let currentConsumption: Double  // kWh consumidos en el período actual
    let limit: Double               // límite de la tarifa asignada
    let projectedMonthEnd: Double   // proyección al cierre del bimestre

    var marginKwh: Double {
        max(0, limit - currentConsumption)
    }

    var percentage: Double {
        guard limit > 0 else { return 0 }
        return (marginKwh / limit) * 100.0
    }

    /// True si el usuario ya cruzó el umbral (entra en zona DAC en el cómputo).
    var hasExceeded: Bool {
        currentConsumption > limit
    }

    var riskLevel: RiskLevel {
        switch percentage {
        case ..<15:    return .danger
        case 15..<40:  return .warning
        default:       return .safe
        }
    }

    enum RiskLevel: String, Codable, CaseIterable {
        case safe      // verde — margen > 40%
        case warning   // ámbar — margen 15–40%
        case danger    // rojo — margen < 15%
    }
}
