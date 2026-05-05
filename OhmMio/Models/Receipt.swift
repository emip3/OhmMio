//
//  Receipt.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftData

@Model
final class Receipt {
    @Attribute(.unique) var id: UUID
    var kwhConsumed: Int
    var tariffCode: String
    var billingPeriodStart: Date
    var billingPeriodEnd: Date
    var totalAmountMXN: Double
    var twelveMonthAverage: Double?
    var scannedAt: Date
    var source: Source

    /// Inversa de `User.receiptHistory`. SwiftData la infiere automáticamente
    /// gracias al `@Relationship` declarado en User.
    var owner: User?

    init(
        id: UUID = UUID(),
        kwhConsumed: Int,
        tariffCode: String,
        billingPeriodStart: Date,
        billingPeriodEnd: Date,
        totalAmountMXN: Double,
        twelveMonthAverage: Double? = nil,
        scannedAt: Date = Date(),
        source: Source,
        owner: User? = nil
    ) {
        self.id = id
        self.kwhConsumed = kwhConsumed
        self.tariffCode = tariffCode
        self.billingPeriodStart = billingPeriodStart
        self.billingPeriodEnd = billingPeriodEnd
        self.totalAmountMXN = totalAmountMXN
        self.twelveMonthAverage = twelveMonthAverage
        self.scannedAt = scannedAt
        self.source = source
        self.owner = owner
    }

    enum Source: String, Codable, CaseIterable {
        case scanned   // capturado por OCR (Vision)
        case manual    // ingresado o editado a mano
    }
}
