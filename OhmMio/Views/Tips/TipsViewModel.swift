//
//  TipsViewModel.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TipsViewModel {

    enum Category: String, CaseIterable {
        case timing = "Por hora"
        case devices = "Por aparato"
<<<<<<< HEAD
=======

        /// Retorna el nombre del SF Symbol correspondiente
        var sfSymbol: String {
            switch self {
            case .timing:
                return "clock.badge.checkmark" // Representa el tiempo y el análisis
            case .devices:
                return "chart.bar.fill" // Representa el desglose por aparatos
            }
        }
>>>>>>> origin/main
    }

    enum State {
        case loading
        case loaded(ApplianceRanker.RecommendationSet, nextCleanHour: Int?, pricePerKwh: Double)
        case empty
        case error(String)
    }

    var state: State = .loading
    var selectedCategory: Category = .devices

    private let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
    }

    func load() async {
        state = .loading

        do {
            let user = try storage.loadOrCreateUser()
            guard let receipt = user.currentReceipt,
                  !user.selectedAppliances.isEmpty else {
                state = .empty
                return
            }

            guard let tariff = try loadTariff(code: receipt.tariffCode) else {
                state = .error("Tarifa no reconocida.")
                return
            }

            let hour = Calendar.current.component(.hour, from: Date())
            let assessment = DACCalculator.evaluate(
                receipt: receipt,
                tariff: tariff,
                history: user.receiptHistory
            )
            let carbon = try CarbonIntensityService.intensity(for: hour)
            let nextClean = try CarbonIntensityService.nextCleanHour(after: hour)

            let recommendations = ApplianceRanker.generate(
                appliances: user.selectedAppliances,
                assessment: assessment,
                currentHour: hour,
                carbon: carbon
            )

            let pricePerKwh: Double = receipt.kwhConsumed > 0
                ? receipt.totalAmountMXN / Double(receipt.kwhConsumed)
                : 1.8 // estimado promedio CFE si no hay recibo

            state = .loaded(recommendations, nextCleanHour: nextClean, pricePerKwh: pricePerKwh)

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func loadTariff(code: String) throws -> Tariff? {
        guard let url = Bundle.main.url(forResource: "TariffLimits", withExtension: "json") else {
            return nil
        }
        let data = try Data(contentsOf: url)
        let tariffs = try JSONDecoder().decode([Tariff].self, from: data)
        return tariffs.first { $0.code == code }
    }
}
