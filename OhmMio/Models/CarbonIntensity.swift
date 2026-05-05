//
//  CarbonIntensity.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

struct CarbonIntensity: Codable, Equatable, Hashable {
    let kgCO2PerKwh: Double
    let level: Level
    let hour: Int                    // 0–23
    let isWeekend: Bool
    let isSummer: Bool
    let dominantSources: String?     // ej. "solar pico máximo"

    enum Level: String, Codable, CaseIterable {
        case clean    // < 0.30 kg CO₂/kWh
        case medium   // 0.30 – 0.50
        case dirty    // > 0.50

        var displayName: String {
            switch self {
            case .clean:  return "Limpia"
            case .medium: return "Media"
            case .dirty:  return "Sucia"
            }
        }
    }
}
