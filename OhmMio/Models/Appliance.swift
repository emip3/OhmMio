//
//  Appliance.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftData

@Model
final class Appliance {
    @Attribute(.unique) var id: UUID
    var categoryKey: String
    var category: Category
    var displayName: String
    var sfSymbol: String
    var nominalWatts: Int
    var estimatedHoursDaily: Double
    var standbyWatts: Int
    var canBeShutOff: Bool
    var priorityWeight: Int
    var notes: String?

    /// Inversa de `User.selectedAppliances`.
    var owner: User?

    init(
        id: UUID = UUID(),
        categoryKey: String,
        category: Category,
        displayName: String,
        sfSymbol: String,
        nominalWatts: Int,
        estimatedHoursDaily: Double,
        standbyWatts: Int = 0,
        canBeShutOff: Bool = true,
        priorityWeight: Int = 1,
        notes: String? = nil,
        owner: User? = nil
    ) {
        self.id = id
        self.categoryKey = categoryKey
        self.category = category
        self.displayName = displayName
        self.sfSymbol = sfSymbol
        self.nominalWatts = nominalWatts
        self.estimatedHoursDaily = estimatedHoursDaily
        self.standbyWatts = standbyWatts
        self.canBeShutOff = canBeShutOff
        self.priorityWeight = priorityWeight
        self.notes = notes
        self.owner = owner
    }

    // MARK: - Cómputos derivados (heurística A2)

    var dailyKwh: Double {
        Double(nominalWatts) * estimatedHoursDaily / 1000.0
    }

    var standbyKwhPerDay: Double {
        Double(standbyWatts) * 24.0 / 1000.0
    }

    var totalDailyKwh: Double {
        dailyKwh + standbyKwhPerDay
    }

    var monthlyKwh: Double {
        totalDailyKwh * 30.0
    }

    // MARK: - Category

    enum Category: String, Codable, CaseIterable {
        case climate
        case kitchen
        case laundry
        case electronics

        var displayName: String {
            switch self {
            case .climate:     return "Climatización"
            case .kitchen:     return "Cocina"
            case .laundry:     return "Lavandería"
            case .electronics: return "Electrónicos"
            }
        }
    }
}
