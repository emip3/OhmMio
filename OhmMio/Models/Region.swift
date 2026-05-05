//
//  Region.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

struct Region: Codable, Identifiable, Equatable, Hashable {
    let id: String                    // identificador único del municipio
    let municipality: String          // ej. "Puebla"
    let state: String                 // ej. "Puebla"
    let assignedTariffCode: String    // "1", "1A", "1B", "1C", "1D", "1E", "1F"
    let averageSummerMinTemp: Double  // °C
}
