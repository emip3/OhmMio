//
//  ActionDecision.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

struct ActionDecision: Codable, Equatable, Hashable {
    // Snapshot del aparato (no referencia a @Model para mantener Codable)
    let applianceID: UUID
    let applianceDisplayName: String
    let applianceSFSymbol: String
    let applianceCategoryKey: String

    let strategy: Strategy
    let estimatedKwhSaved: Double
    let estimatedCO2Saved: Double
    let estimatedMXNSaved: Double
    let urgency: Urgency
    let fallbackText: String   // texto si Foundation Models falla o expira

    enum Strategy: String, Codable, CaseIterable {
        case reduceUrgent       // peligro DAC inminente
        case postponeForCarbon  // red sucia, pospón si puedes
        case takeAdvantage      // red limpia, aprovecha
        case reduceModerate     // default
    }

    enum Urgency: String, Codable, CaseIterable {
        case high, medium, low
    }
}

// MARK: - Conveniencia para construir desde un Appliance @Model

extension ActionDecision {
    init(
        appliance: Appliance,
        strategy: Strategy,
        estimatedKwhSaved: Double,
        estimatedCO2Saved: Double,
        estimatedMXNSaved: Double,
        urgency: Urgency,
        fallbackText: String
    ) {
        self.applianceID = appliance.id
        self.applianceDisplayName = appliance.displayName
        self.applianceSFSymbol = appliance.sfSymbol
        self.applianceCategoryKey = appliance.categoryKey
        self.strategy = strategy
        self.estimatedKwhSaved = estimatedKwhSaved
        self.estimatedCO2Saved = estimatedCO2Saved
        self.estimatedMXNSaved = estimatedMXNSaved
        self.urgency = urgency
        self.fallbackText = fallbackText
    }
}
