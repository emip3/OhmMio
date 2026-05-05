//
//  DashboardViewModel.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class DashboardViewModel {

    struct DashboardData {
        let marginPercentage: Double
        let marginKwh: Int
        let riskLevel: DACMargin.RiskLevel
        let actionDecision: ActionDecision
        let narrativeText: String
        let currentCarbonLevel: CarbonIntensity.Level
        let currentCarbonAdvice: String
    }

    enum State {
        case loading
        case loaded(DashboardData)
        case empty            // sin recibo aún
        case error(String)
    }

    var state: State = .loading

    private let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
    }

    func load() async {
        state = .loading

        do {
            let user = try storage.loadOrCreateUser()
            guard let receipt = user.currentReceipt else {
                state = .empty
                return
            }

            // Lookup de tariff desde el JSON estático
            guard let tariff = try loadTariff(code: receipt.tariffCode) else {
                state = .error("Tarifa \(receipt.tariffCode) no reconocida.")
                return
            }

            let now = Date()
            let hour = Calendar.current.component(.hour, from: now)

            // Ejecuta agentes en paralelo (§5.5 antipatrón 2)
            async let assessmentTask = DACCalculator.evaluate(
                receipt: receipt,
                tariff: tariff,
                history: user.receiptHistory,
                referenceDate: now
            )
            async let carbonTask = try CarbonIntensityService.intensity(for: hour, date: now)

            let assessment = await assessmentTask
            let carbon = try await carbonTask

            let recommendations = ApplianceRanker.generate(
                appliances: user.selectedAppliances,
                assessment: assessment,
                currentHour: hour,
                carbon: carbon
            )

            guard let decision = PriorityAgent.decide(
                assessment: assessment,
                recommendations: recommendations,
                carbon: carbon
            ) else {
                state = .error("No hay aparatos registrados para generar consejo.")
                return
            }

            // LLM con timeout y fallback (§5.3 M2)
            let narrative = await NarrativeService.narrate(decision: decision)

            let data = DashboardData(
                marginPercentage: assessment.margin.percentage,
                marginKwh: Int(assessment.margin.marginKwh),
                riskLevel: assessment.margin.riskLevel,
                actionDecision: decision,
                narrativeText: narrative,
                currentCarbonLevel: carbon.level,
                currentCarbonAdvice: carbonAdvice(for: carbon.level)
            )

            state = .loaded(data)

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func loadTariff(code: String) throws -> Tariff? {
        guard let url = Bundle.main.url(forResource: "TariffLimits", withExtension: "json") else {
            return nil
        }
        let data = try Data(contentsOf: url)
        let tariffs = try JSONDecoder().decode([Tariff].self, from: data)
        return tariffs.first { $0.code == code }
    }

    private func carbonAdvice(for level: CarbonIntensity.Level) -> String {
        switch level {
        case .clean:  return "Red limpia ahorita — buen momento para usar aparatos pesados."
        case .medium: return "Red en mezcla típica. Operación normal."
        case .dirty:  return "Pico de demanda: operan plantas de respaldo."
        }
    }
}
