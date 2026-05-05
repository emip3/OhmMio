//
//  CarbonIntensityService.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

/// M3 — Carbon Intensity Lookup.
/// Modelo determinista: hora + escenario → factor kg CO₂/kWh.
/// Lee `CarbonIntensityTable.json` de Resources.
struct CarbonIntensityService {

    enum LookupError: Error {
        case fileNotFound
        case decodingFailed
        case scenarioMissing
    }

    // MARK: - DTOs internos para decodificar el JSON

    private struct Table: Codable {
        let scenarios: [String: Scenario]
    }
    private struct Scenario: Codable {
        let description: String
        let hourlyFactors: [HourlyFactor]
    }
    private struct HourlyFactor: Codable {
        let hour: Int
        let kgCO2PerKwh: Double
        let level: String
        let dominantSources: String?
    }

    // MARK: - Cache estático

    private static var cachedTable: Table?

    private static func loadTable() throws -> Table {
        if let cached = cachedTable { return cached }
        guard let url = Bundle.main.url(forResource: "CarbonIntensityTable", withExtension: "json") else {
            throw LookupError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let table = try JSONDecoder().decode(Table.self, from: data)
        cachedTable = table
        return table
    }

    // MARK: - API pública

    /// Consulta la intensidad de carbono para una hora dada.
    /// - Parameters:
    ///   - hour: 0–23
    ///   - date: fecha de referencia (default: ahora). Determina weekend/summer.
    static func intensity(for hour: Int, date: Date = Date()) throws -> CarbonIntensity {
        let isWeekend = isWeekend(date)
        let isSummer = isSummer(date)
        let scenarioKey = scenarioKey(isWeekend: isWeekend, isSummer: isSummer)

        let table = try loadTable()
        guard let scenario = table.scenarios[scenarioKey],
              let entry = scenario.hourlyFactors.first(where: { $0.hour == hour })
        else {
            throw LookupError.scenarioMissing
        }

        return CarbonIntensity(
            kgCO2PerKwh: entry.kgCO2PerKwh,
            level: CarbonIntensity.Level(rawValue: entry.level) ?? .medium,
            hour: entry.hour,
            isWeekend: isWeekend,
            isSummer: isSummer,
            dominantSources: entry.dominantSources
        )
    }

    /// Devuelve la matriz completa de 24 horas para el escenario actual.
    /// Usado por `CarbonMapView`.
    static func dailyMatrix(for date: Date = Date()) throws -> [CarbonIntensity] {
        try (0..<24).map { try intensity(for: $0, date: date) }
    }

    /// Encuentra la próxima hora con `level == .clean` a partir de `currentHour`.
    static func nextCleanHour(after currentHour: Int, date: Date = Date()) throws -> Int? {
        let matrix = try dailyMatrix(for: date)
        return matrix
            .filter { $0.hour > currentHour && $0.level == .clean }
            .map { $0.hour }
            .first
    }

    // MARK: - Helpers de escenario

    private static func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // domingo, sábado
    }

    private static func isSummer(_ date: Date) -> Bool {
        // Mayo–Octubre en México: temporada cálida
        let month = Calendar.current.component(.month, from: date)
        return (5...10).contains(month)
    }

    private static func scenarioKey(isWeekend: Bool, isSummer: Bool) -> String {
        switch (isWeekend, isSummer) {
        case (false, true):  return "weekday_summer"
        case (false, false): return "weekday_winter"
        case (true, true):   return "weekend_summer"
        case (true, false):  return "weekend_winter"
        }
    }
}
