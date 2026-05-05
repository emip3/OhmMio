//
//  OnboardingViewModel.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftUI
import SwiftData
import UIKit

@MainActor
@Observable
final class OnboardingViewModel {

    enum Step {
        case welcome
        case scanReceipt
        case selectAppliances
    }

    // MARK: - Estado público

    var step: Step = .welcome
    var isProcessing: Bool = false
    var errorMessage: String?

    // Datos parciales recolectados durante el flujo
    var parsedReceipt: ReceiptParser.ParsedReceipt?
    var capturedImage: UIImage?
    var selectedKeys: Set<String> = []
    var catalog: [ApplianceCatalogEntry] = []

    // MARK: - Dependencias

    private let storage: StorageService
    private let locationService: LocationService

    init(storage: StorageService, locationService: LocationService) {
        self.storage = storage
        self.locationService = locationService
        loadCatalog()
    }

    convenience init(storage: StorageService) {
        self.init(storage: storage, locationService: LocationService())
    }

    // MARK: - Navegación entre pasos

    func advanceFromWelcome() {
        step = .scanReceipt
    }

    func advanceToAppliances() {
        step = .selectAppliances
    }

    // MARK: - Captura de recibo

    func handleCapturedImage(_ image: UIImage) async {
        capturedImage = image
        isProcessing = true
        errorMessage = nil

        do {
            let lines = try await ReceiptScanner.scan(image: image)
            parsedReceipt = ReceiptParser.parse(lines)
        } catch {
            errorMessage = error.localizedDescription
            // Aún así permitimos continuar con entrada manual
            parsedReceipt = ReceiptParser.ParsedReceipt()
        }

        isProcessing = false
    }

    func skipToManualEntry() {
        parsedReceipt = ReceiptParser.ParsedReceipt()
    }

    // MARK: - Catálogo de aparatos

    private func loadCatalog() {
        guard let url = Bundle.main.url(forResource: "ApplianceCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            errorMessage = "No pudimos cargar el catálogo de aparatos."
            return
        }

        struct Wrapper: Codable {
            let appliances: [ApplianceCatalogEntry]
        }

        do {
            let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
            catalog = wrapper.appliances
        } catch {
            errorMessage = "Catálogo con formato inválido."
        }
    }

    // MARK: - Finalización

    func completeOnboarding() async -> Bool {
        guard let parsed = parsedReceipt,
              let kwh = parsed.kwhConsumed,
              let tariff = parsed.tariffCode else {
            errorMessage = "Faltan datos del recibo. Edita los valores y reintenta."
            return false
        }

        do {
            // 1. Detectar región (con fallback silencioso)
            let region = try? await locationService.detectRegion()

            // 2. Construir Receipt
            let receipt = Receipt(
                kwhConsumed: kwh,
                tariffCode: tariff,
                billingPeriodStart: parsed.billingPeriodStart ?? Date().addingTimeInterval(-60*24*60*60),
                billingPeriodEnd: parsed.billingPeriodEnd ?? Date(),
                totalAmountMXN: parsed.totalAmountMXN ?? 0,
                twelveMonthAverage: parsed.twelveMonthAverage,
                source: capturedImage != nil ? .scanned : .manual
            )

            // 3. Construir Appliances seleccionados
            let appliances = catalog
                .filter { selectedKeys.contains($0.categoryKey) }
                .map { entry in
                    Appliance(
                        categoryKey: entry.categoryKey,
                        category: Appliance.Category(rawValue: entry.category) ?? .electronics,
                        displayName: entry.displayName,
                        sfSymbol: entry.sfSymbol,
                        nominalWatts: entry.nominalWatts,
                        estimatedHoursDaily: entry.estimatedHoursDaily,
                        standbyWatts: entry.standbyWatts,
                        canBeShutOff: entry.canBeShutOff,
                        priorityWeight: entry.priorityWeight,
                        notes: entry.notes
                    )
                }

            // 4. Persistir todo
            let user = try storage.loadOrCreateUser()
            user.region = region
            user.hasCompletedOnboarding = true

            receipt.owner = user
            user.receiptHistory.append(receipt)
            storage.insert(receipt)

            for appliance in appliances {
                appliance.owner = user
                user.selectedAppliances.append(appliance)
                storage.insert(appliance)
            }

            try storage.save()
            return true

        } catch {
            errorMessage = "No pudimos guardar tu información: \(error.localizedDescription)"
            return false
        }
    }
}
