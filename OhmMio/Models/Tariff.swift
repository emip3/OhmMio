//
//  Tariff.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

struct Tariff: Codable, Identifiable, Equatable, Hashable {
    let code: String              // "1", "1A", "1B", "1C", "1D", "1E", "1F", "DAC"
    let name: String              // "Tarifa 1 — Templado"
    let monthlyLimitKwh: Int      // 0 cuando es DAC
    let description: String
    let temperatureRange: String
    let exampleStates: [String]

    var id: String { code }

    /// True si la tarifa actual es la sancionada (Doméstica de Alto Consumo).
    var isDAC: Bool { code == "DAC" }
}
