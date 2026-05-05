//
//  PriorityAgent.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

/// A3 — Priority Agent (Agente Orquestador).
/// Única responsabilidad de la app que selecciona la "siguiente acción" (§5.4).
/// Aplica las reglas de priorización del PRD.
struct PriorityAgent {

    static func decide(
        assessment: DACCalculator.Assessment,
        recommendations: ApplianceRanker.RecommendationSet,
        carbon: CarbonIntensity
    ) -> ActionDecision? {

        guard let topAppliance = recommendations.topAppliance else { return nil }

        let strategy = selectStrategy(
            riskLevel: assessment.margin.riskLevel,
            carbonLevel: carbon.level,
            topApplianceDailyKwh: topAppliance.totalDailyKwh
        )

        let urgency = mapUrgency(strategy: strategy, riskLevel: assessment.margin.riskLevel)

        let kwhSaved = estimateKwhSaved(strategy: strategy, appliance: topAppliance)
        let co2Saved = kwhSaved * carbon.kgCO2PerKwh
        let mxnSaved = estimateMXNSaved(kwhSaved: kwhSaved, riskLevel: assessment.margin.riskLevel)

        let fallback = fallbackText(
            strategy: strategy,
            applianceName: topAppliance.displayName,
            kwhSaved: kwhSaved
        )

        return ActionDecision(
            appliance: topAppliance,
            strategy: strategy,
            estimatedKwhSaved: kwhSaved,
            estimatedCO2Saved: co2Saved,
            estimatedMXNSaved: mxnSaved,
            urgency: urgency,
            fallbackText: fallback
        )
    }

    // MARK: - Reglas de priorización (§5.4)

    private static func selectStrategy(
        riskLevel: DACMargin.RiskLevel,
        carbonLevel: CarbonIntensity.Level,
        topApplianceDailyKwh: Double
    ) -> ActionDecision.Strategy {
        // Regla 1: peligro DAC siempre gana
        if riskLevel == .danger { return .reduceUrgent }
        // Regla 2: red sucia + aparato pesado → posponer
        if carbonLevel == .dirty && topApplianceDailyKwh > 5 { return .postponeForCarbon }
        // Regla 3: red limpia → aprovechar
        if carbonLevel == .clean { return .takeAdvantage }
        // Default
        return .reduceModerate
    }

    private static func mapUrgency(
        strategy: ActionDecision.Strategy,
        riskLevel: DACMargin.RiskLevel
    ) -> ActionDecision.Urgency {
        switch strategy {
        case .reduceUrgent:      return .high
        case .postponeForCarbon: return riskLevel == .warning ? .high : .medium
        case .takeAdvantage:     return .low
        case .reduceModerate:    return .medium
        }
    }

    // MARK: - Estimaciones de impacto

    private static func estimateKwhSaved(
        strategy: ActionDecision.Strategy,
        appliance: Appliance
    ) -> Double {
        let daily = appliance.totalDailyKwh
        switch strategy {
        case .reduceUrgent:      return daily * 0.30  // reducción agresiva 30%
        case .postponeForCarbon: return daily * 0.15  // mover horario, ahorro modesto en kWh
        case .takeAdvantage:     return 0             // no ahorras kWh, optimizas huella
        case .reduceModerate:    return daily * 0.10  // ajuste suave 10%
        }
    }

    private static func estimateMXNSaved(kwhSaved: Double, riskLevel: DACMargin.RiskLevel) -> Double {
        // Tarifa promedio subsidiada vs DAC
        let pricePerKwh: Double = riskLevel == .danger ? 6.0 : 1.5
        return kwhSaved * pricePerKwh * 30 // proyección mensual
    }

    // MARK: - Fallback (obligatorio si Foundation Models falla)

    private static func fallbackText(
        strategy: ActionDecision.Strategy,
        applianceName: String,
        kwhSaved: Double
    ) -> String {
        let kwhFormatted = String(format: "%.1f", kwhSaved)
        switch strategy {
        case .reduceUrgent:
            return "Reduce el uso de \(applianceName.lowercased()) hoy. Estás cerca del límite DAC."
        case .postponeForCarbon:
            return "Pospón el uso de \(applianceName.lowercased()) — la red está sucia ahora."
        case .takeAdvantage:
            return "Buen momento para usar \(applianceName.lowercased()). La red está limpia."
        case .reduceModerate:
            return "Ajusta el uso de \(applianceName.lowercased()) para ahorrar ~\(kwhFormatted) kWh al día."
        }
    }
}
