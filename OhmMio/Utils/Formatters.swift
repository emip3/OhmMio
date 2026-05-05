//
//  Formatters.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

/// Formatters centralizados de OhMio.
/// Todos los formatters cachean sus instancias (crear un NumberFormatter es caro).
enum Formatters {

    // MARK: - Locale base de la app

    static let mxLocale = Locale(identifier: "es_MX")

    // MARK: - Energía (kWh)

    /// Formatea kWh con 0 decimales para valores grandes (consumo total).
    /// Ej: 1247 → "1,247 kWh"
    static let kwhInteger: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = mxLocale
        return f
    }()

    /// Formatea kWh con 1 decimal para valores pequeños (consumo diario por aparato).
    /// Ej: 3.7 → "3.7 kWh"
    static let kwhDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        f.locale = mxLocale
        return f
    }()

    // MARK: - Carbono (kg CO₂)

    /// Formatea kg CO₂ con 2 decimales.
    /// Ej: 0.42 → "0.42"
    static let co2: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.locale = mxLocale
        return f
    }()

    // MARK: - Dinero (MXN)

    /// Formatea pesos mexicanos con 2 decimales y símbolo $.
    /// Ej: 1247.50 → "$1,247.50"
    static let mxn: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "MXN"
        f.currencySymbol = "$"
        f.locale = mxLocale
        return f
    }()

    /// Formatea pesos mexicanos sin decimales (para estimaciones aproximadas).
    /// Ej: 890 → "$890"
    static let mxnRounded: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "MXN"
        f.currencySymbol = "$"
        f.maximumFractionDigits = 0
        f.locale = mxLocale
        return f
    }()

    // MARK: - Porcentajes

    /// Formatea porcentaje sin decimales.
    /// Ej: 67.4 → "67%"
    static let percent: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        f.locale = mxLocale
        return f
    }()

    // MARK: - Fechas

    /// Fecha corta. Ej: "5 may 2026"
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = mxLocale
        f.dateStyle = .medium
        return f
    }()

    /// Solo el día de la semana. Ej: "Martes"
    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = mxLocale
        f.dateFormat = "EEEE"
        return f
    }()

    /// Periodo de facturación corto. Ej: "01 mar – 30 abr"
    static let billingPeriod: DateFormatter = {
        let f = DateFormatter()
        f.locale = mxLocale
        f.dateFormat = "dd MMM"
        return f
    }()

    /// Hora del día. Ej: "14:00"
    static let hour: DateFormatter = {
        let f = DateFormatter()
        f.locale = mxLocale
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: - Helpers compositivos

    /// Devuelve "01 mar – 30 abr" a partir de dos fechas.
    static func billingRange(from start: Date, to end: Date) -> String {
        "\(billingPeriod.string(from: start)) – \(billingPeriod.string(from: end))"
    }

    /// Devuelve "1,247 kWh" o "3.7 kWh" según magnitud.
    static func formatKwh(_ value: Double) -> String {
        let formatter = value >= 100 ? kwhInteger : kwhDecimal
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(number) kWh"
    }

    /// Devuelve "0.42 kg CO₂".
    static func formatCO2(_ value: Double) -> String {
        let number = co2.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(number) kg CO₂"
    }
}
