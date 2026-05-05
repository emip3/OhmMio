//
//  ApplianceRanker.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

/// A2 — Recommendation Engine (Agente).
/// Rankea aparatos por impacto y genera consejos por categoría.
/// **No invoca al LLM** (§5.4).
struct ApplianceRanker {

    struct RecommendationSet: Equatable {
        let timingTips: [TimingTip]
        let deviceTips: [DeviceTip]
        let topAppliance: Appliance?
    }

    struct TimingTip: Equatable, Identifiable {
        let id: UUID
        let title: String
        let description: String
        let recommendedHour: Int?
    }

    struct DeviceTip: Equatable, Identifiable {
        let id: UUID
        let appliance: Appliance
        let rank: Int
        let dailyKwh: Double
        let percentageOfTotal: Double
        let advice: String

        static func == (lhs: DeviceTip, rhs: DeviceTip) -> Bool {
            lhs.id == rhs.id && lhs.appliance.id == rhs.appliance.id
        }
    }

    static func generate(
        appliances: [Appliance],
        assessment: DACCalculator.Assessment,
        currentHour: Int,
        carbon: CarbonIntensity
    ) -> RecommendationSet {

        let ranked = rankByImpact(appliances)
        let totalKwh = ranked.reduce(0) { $0 + $1.totalDailyKwh }

        let deviceTips = ranked.enumerated().map { index, appliance in
            DeviceTip(
                id: UUID(),
                appliance: appliance,
                rank: index + 1,
                dailyKwh: appliance.totalDailyKwh,
                percentageOfTotal: totalKwh > 0
                    ? (appliance.totalDailyKwh / totalKwh) * 100
                    : 0,
                advice: deviceAdvice(for: appliance, carbon: carbon)
            )
        }

        let timingTips = generateTimingTips(carbon: carbon, currentHour: currentHour)

        return RecommendationSet(
            timingTips: timingTips,
            deviceTips: deviceTips,
            topAppliance: ranked.first
        )
    }

    // MARK: - Ranking

    /// Score = consumo diario × peso de prioridad (definido en ApplianceCatalog.json).
    static func rankByImpact(_ appliances: [Appliance]) -> [Appliance] {
        appliances.sorted { lhs, rhs in
            let scoreL = lhs.totalDailyKwh * Double(lhs.priorityWeight)
            let scoreR = rhs.totalDailyKwh * Double(rhs.priorityWeight)
            return scoreL > scoreR
        }
    }

    // MARK: - Generación de consejos (templates, no LLM)

    private static func deviceAdvice(for appliance: Appliance, carbon: CarbonIntensity) -> String {
        switch appliance.categoryKey {
        case "miniSplit":
            return carbon.level == .dirty
                ? "Sube 2°C el termostato durante el pico vespertino. Cada grado ahorra ~6%."
                : "Programa el A/C para apagarse 30 min antes de salir."
        case "refrigerator":
            return "Verifica el sello de la puerta y mantén libre el condensador trasero."
        case "washer":
            return carbon.level == .clean
                ? "Aprovecha — la red está limpia ahora. Buen momento para lavar."
                : "Pospón ciclos de lavado a horas de red limpia (10 AM – 3 PM)."
        case "dryer":
            return "Tender al aire libre ahorra ~2 kWh por ciclo. La secadora pesa fuerte."
        case "gamingPC":
            return "Suspende en lugar de dejar encendido. Standby consume ~5W constantes."
        case "console":
            return "Apaga completamente — el modo reposo consume ~10W (88 kWh/año)."
        case "tv":
            return "Desconecta de la corriente cuando viajes. El standby suma."
        case "heater":
            return "Aísla ventanas y puertas antes de subir el calefactor."
        case "electricStove":
            return "Tapa las ollas para reducir tiempo de cocción ~30%."
        case "airFryer":
            return "Más eficiente que el horno tradicional — buena alternativa."
        case "microwave":
            return "Desconecta cuando no lo uses. Standby ~3W constantes."
        case "fan":
            return "Excelente alternativa al A/C — usa ventilador primero."
        case "modem":
            return "Mantén encendido pero desconecta dispositivos no usados."
        default:
            return "Revisa su uso diario para identificar oportunidades de ahorro."
        }
    }

    private static func generateTimingTips(carbon: CarbonIntensity, currentHour: Int) -> [TimingTip] {
        var tips: [TimingTip] = []

        let nowTip = TimingTip(
            id: UUID(),
            title: "Ahora",
            description: timingDescription(for: carbon.level, hour: currentHour),
            recommendedHour: nil
        )
        tips.append(nowTip)

        if let nextClean = nextCleanWindow(currentHour: currentHour) {
            tips.append(TimingTip(
                id: UUID(),
                title: "Próxima ventana limpia",
                description: "Alrededor de las \(nextClean):00 la red estará más limpia.",
                recommendedHour: nextClean
            ))
        }

        return tips
    }

    private static func timingDescription(for level: CarbonIntensity.Level, hour: Int) -> String {
        switch level {
        case .clean:
            return "Red limpia — buen momento para usar electrodomésticos pesados."
        case .medium:
            return "Red en mezcla típica. Operación normal."
        case .dirty:
            return "Pico de demanda: operan plantas de respaldo. Pospón si puedes."
        }
    }

    private static func nextCleanWindow(currentHour: Int) -> Int? {
        // Ventana limpia típica: 10 AM – 3 PM
        if currentHour < 10 { return 10 }
        if currentHour < 15 { return nil } // ya estás dentro o muy cerca
        return nil // siguiente ventana es mañana
    }
}
