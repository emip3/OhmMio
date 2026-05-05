//
//  DACCalculator.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

/// A1 — DAC Watchdog (Agente).
/// Evalúa el estado de riesgo del usuario respecto al umbral DAC.
/// Calcula promedio móvil de 12 meses, proyecta cierre del bimestre y clasifica riesgo.
struct DACCalculator {

    struct Assessment: Equatable {
        let margin: DACMargin
        let projectedMonthEnd: Double
        let trend: Trend
        let twelveMonthRollingAverage: Double

        enum Trend: String, Equatable {
            case improving, stable, worsening
        }
    }

    /// - Parameters:
    ///   - receipt: Recibo más reciente.
    ///   - tariff: Tarifa asignada al usuario.
    ///   - history: Historial completo (incluyendo o no el actual; se filtra).
    ///   - referenceDate: Fecha de cómputo (default: ahora). Útil para tests.
    static func evaluate(
        receipt: Receipt,
        tariff: Tariff,
        history: [Receipt],
        referenceDate: Date = Date()
    ) -> Assessment {
        let limit = Double(tariff.monthlyLimitKwh)
        let current = Double(receipt.kwhConsumed)

        // Proyección lineal al cierre del período de facturación
        let projected = projectMonthEnd(
            receipt: receipt,
            referenceDate: referenceDate
        )

        let margin = DACMargin(
            currentConsumption: current,
            limit: limit,
            projectedMonthEnd: projected
        )

        let avg12 = twelveMonthAverage(history: history, current: receipt)
        let trend = computeTrend(history: history, current: receipt)

        return Assessment(
            margin: margin,
            projectedMonthEnd: projected,
            trend: trend,
            twelveMonthRollingAverage: avg12
        )
    }

    // MARK: - Helpers

    private static func projectMonthEnd(receipt: Receipt, referenceDate: Date) -> Double {
        let totalDuration = receipt.billingPeriodEnd.timeIntervalSince(receipt.billingPeriodStart)
        guard totalDuration > 0 else { return Double(receipt.kwhConsumed) }

        let elapsed = referenceDate.timeIntervalSince(receipt.billingPeriodStart)
        let progress = max(0.01, min(1.0, elapsed / totalDuration))
        return Double(receipt.kwhConsumed) / progress
    }

    private static func twelveMonthAverage(history: [Receipt], current: Receipt) -> Double {
        let allReceipts = (history + [current])
            .uniquedByKeyPath(\.id)
            .sorted { $0.scannedAt > $1.scannedAt }
            .prefix(6) // 6 recibos bimestrales = 12 meses

        guard !allReceipts.isEmpty else { return 0 }
        let sum = allReceipts.reduce(0) { $0 + $1.kwhConsumed }
        return Double(sum) / Double(allReceipts.count)
    }

    private static func computeTrend(history: [Receipt], current: Receipt) -> Assessment.Trend {
        let sorted = history.sorted { $0.scannedAt > $1.scannedAt }
        guard let previous = sorted.first(where: { $0.id != current.id }) else {
            return .stable
        }
        let delta = current.kwhConsumed - previous.kwhConsumed
        let threshold = Double(previous.kwhConsumed) * 0.05 // ±5%

        if Double(delta) < -threshold { return .improving }
        if Double(delta) > threshold  { return .worsening }
        return .stable
    }
}

// MARK: - Array helper

private extension Array {
    /// Returns a new array with duplicate elements removed, using a key path as the uniqueness key.
    /// This is locally named to avoid clashing with other `uniqued(by:)` helpers in the project.
    func uniquedByKeyPath<T: Hashable>(_ keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
