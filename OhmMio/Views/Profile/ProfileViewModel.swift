//
//  ProfileViewModel.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ProfileViewModel {

    enum State {
        case loading
        case loaded(User, Tariff?)
        case error(String)
    }

    var state: State = .loading
    var catalog: [ApplianceCatalogEntry] = []

    let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
        loadCatalog()
    }

    func load() async {
        state = .loading
        do {
            let user = try storage.loadOrCreateUser()
            let tariff = try? loadTariff(code: user.currentReceipt?.tariffCode ?? "")
            state = .loaded(user, tariff)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func updateAppliances(selectedKeys: Set<String>) async {
        guard case .loaded(let user, _) = state else { return }
        do {
            // Eliminar los que ya no están seleccionados
            for appliance in user.selectedAppliances where !selectedKeys.contains(appliance.categoryKey) {
                user.selectedAppliances.removeAll { $0.id == appliance.id }
                storage.delete(appliance)
            }
            // Agregar los nuevos
            let existingKeys = Set(user.selectedAppliances.map { $0.categoryKey })
            let newKeys = selectedKeys.subtracting(existingKeys)
            for key in newKeys {
                if let entry = catalog.first(where: { $0.categoryKey == key }) {
                    let appliance = Appliance(
                        categoryKey: entry.categoryKey,
                        category: Appliance.Category(rawValue: entry.category) ?? .electronics,
                        displayName: entry.displayName,
                        sfSymbol: entry.sfSymbol,
                        nominalWatts: entry.nominalWatts,
                        estimatedHoursDaily: entry.estimatedHoursDaily,
                        standbyWatts: entry.standbyWatts,
                        canBeShutOff: entry.canBeShutOff,
                        priorityWeight: entry.priorityWeight,
                        notes: entry.notes,
                        owner: user
                    )
                    user.selectedAppliances.append(appliance)
                    storage.insert(appliance)
                }
            }
            try storage.save()
            await load()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func updateReceipt(parsed: ReceiptParser.ParsedReceipt) async {
        guard case .loaded(let user, _) = state,
              let kwh = parsed.kwhConsumed,
              let tariff = parsed.tariffCode else { return }

        let receipt = Receipt(
            kwhConsumed: kwh,
            tariffCode: tariff,
            billingPeriodStart: parsed.billingPeriodStart ?? Date().addingTimeInterval(-60*24*60*60),
            billingPeriodEnd: parsed.billingPeriodEnd ?? Date(),
            totalAmountMXN: parsed.totalAmountMXN ?? 0,
            twelveMonthAverage: parsed.twelveMonthAverage,
            source: .manual,
            owner: user
        )
        user.receiptHistory.append(receipt)
        storage.insert(receipt)
        do {
            try storage.save()
            await load()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func loadCatalog() {
        guard let url = Bundle.main.url(forResource: "ApplianceCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        struct Wrapper: Codable { let appliances: [ApplianceCatalogEntry] }
        catalog = (try? JSONDecoder().decode(Wrapper.self, from: data).appliances) ?? []
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
