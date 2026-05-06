//
//  LocationService.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import CoreLocation

/// Servicio de ubicación → mapeo a municipio → tarifa CFE.
/// Lee `MunicipalityTariffs.json` de Resources.
@MainActor
final class LocationService: NSObject {

    enum LocationError: Error, LocalizedError {
        case permissionDenied
        case unavailable
        case mappingFailed
        case fileNotFound
        case timedOut

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Necesitamos tu ubicación para asignar tu tarifa."
            case .unavailable:      return "Ubicación no disponible."
            case .mappingFailed:    return "No pudimos identificar tu municipio."
            case .fileNotFound:     return "Datos de tarifas no disponibles."
            case .timedOut:         return "El GPS está tardando demasiado. Intenta de nuevo o elige tu municipio manualmente."
            }
        }
    }

    private let manager = CLLocationManager()

    // Continuación para la solicitud de ubicación (didUpdateLocations / didFailWithError)
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    // Continuación para la solicitud de autorización (locationManagerDidChangeAuthorization)
    // Es separada porque las dos cosas ocurren en momentos distintos del flujo.
    private var authContinuation: CheckedContinuation<Void, Never>?

    /// Caché de municipios (evita re-leer el JSON cada vez que se mapea).
    private var cachedMunicipalities: [MunicipalityEntry]?
    private var cachedStateFallbacks: [StateFallback]?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Solicita ubicación y devuelve la `Region` correspondiente.
    /// Si el usuario nunca ha respondido al diálogo de permisos, lo muestra y espera.
    func detectRegion() async throws -> Region {
        let location = try await requestLocation()
        let placemark = try await reverseGeocode(location)
        return try mapToRegion(placemark: placemark)
    }

    /// Permite construir `Region` manualmente desde un nombre de municipio
    /// (útil para el flujo "Ingresar manualmente" en onboarding).
    func region(forMunicipality name: String) throws -> Region {
        let table = try loadMunicipalities()
        guard let entry = table.first(where: {
            $0.municipality.lowercased() == name.lowercased()
        }) else {
            throw LocationError.mappingFailed
        }
        return entry.toRegion()
    }

    /// Lista completa de municipios disponibles. Útil para el picker manual.
    func allMunicipalities() throws -> [Region] {
        try loadMunicipalities().map { $0.toRegion() }
    }

    // MARK: - CoreLocation

    private func requestLocation() async throws -> CLLocation {
        let status = manager.authorizationStatus

        // Caso 1: ya denegado o restringido — error inmediato.
        if status == .denied || status == .restricted {
            throw LocationError.permissionDenied
        }

        // Caso 2: nunca preguntado — pedir y ESPERAR la respuesta del usuario.
        if status == .notDetermined {
            await requestAuthorizationAndWait()
        }

        // Caso 3: revisar el estado DESPUÉS de que el usuario respondió.
        let finalStatus = manager.authorizationStatus
        guard finalStatus == .authorizedWhenInUse || finalStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }

        // Caso 4: ya tenemos permiso, pedir ubicación real con timeout.
        // `requestLocation()` puede tardar 5–15s indoor; si CoreLocation no
        // responde en 12s, fallamos para que la UI no quede colgada.
        return try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask { @MainActor [weak self] in
                guard let self else { throw LocationError.unavailable }
                return try await withCheckedThrowingContinuation { cont in
                    self.locationContinuation = cont
                    self.manager.requestLocation()
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 12_000_000_000) // 12s
                throw LocationError.timedOut
            }
            // El primer resultado gana (ubicación real o timeout).
            let result = try await group.next()!
            group.cancelAll()
            // Limpiar la continuación pendiente si el timeout ganó.
            if let pending = self.locationContinuation {
                self.locationContinuation = nil
                pending.resume(throwing: LocationError.timedOut)
            }
            return result
        }
    }

    /// Muestra el diálogo de permisos y espera (sin bloquear) a que el usuario decida.
    /// La respuesta llega vía `locationManagerDidChangeAuthorization`.
    private func requestAuthorizationAndWait() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.authContinuation = cont
            manager.requestWhenInUseAuthorization()
        }
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> CLPlacemark {
        let geocoder = CLGeocoder()
        // Forzamos locale español para que los nombres lleguen consistentes
        // con los del JSON (acentos, "Ciudad de México" en vez de "Mexico City", etc.).
        let placemarks = try await geocoder.reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "es_MX")
        )
        guard let first = placemarks.first else { throw LocationError.mappingFailed }
        return first
    }

    // MARK: - Mapeo

    private struct MunicipalityEntry: Codable {
        let id: String
        let municipality: String
        let state: String
        let assignedTariffCode: String
        let averageSummerMinTemp: Double

        func toRegion() -> Region {
            Region(
                id: id,
                municipality: municipality,
                state: state,
                assignedTariffCode: assignedTariffCode,
                averageSummerMinTemp: averageSummerMinTemp
            )
        }
    }

    private struct StateFallback: Codable {
        let state: String
        let defaultTariff: String
    }

    /// El JSON real tiene la forma `{ "metadata": {...}, "municipalities": [...], "stateFallbacks": [...] }`
    /// por eso decodificamos con un wrapper en lugar de `[MunicipalityEntry].self` directo.
    private struct MunicipalityFile: Codable {
        let municipalities: [MunicipalityEntry]
        let stateFallbacks: [StateFallback]?
    }

    private func loadMunicipalities() throws -> [MunicipalityEntry] {
        if let cached = cachedMunicipalities { return cached }
        let file = try loadMunicipalityFile()
        cachedMunicipalities = file.municipalities
        cachedStateFallbacks = file.stateFallbacks ?? []
        return file.municipalities
    }

    private func loadStateFallbacks() throws -> [StateFallback] {
        if let cached = cachedStateFallbacks { return cached }
        _ = try loadMunicipalities() // llena ambos cachés
        return cachedStateFallbacks ?? []
    }

    private func loadMunicipalityFile() throws -> MunicipalityFile {
        guard let url = Bundle.main.url(forResource: "MunicipalityTariffs", withExtension: "json") else {
            throw LocationError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MunicipalityFile.self, from: data)
    }

    /// Estrategia en cascada:
    /// 1. Match exacto por nombre, CRUZADO con estado (resuelve duplicados como "Cuauhtémoc"
    ///    que existe como alcaldía de CDMX y como municipio de Chihuahua).
    /// 2. Match normalizado (sin tildes, sin sufijos como "de Morelos", "San Pedro ", etc.)
    ///    cruzado con estado.
    /// 3. Match exacto por nombre solo (sin estado), por si Apple no devolvió `administrativeArea`.
    /// 4. Fallback por estado: usa el primer municipio del estado o `stateFallbacks` para
    ///    obtener al menos la tarifa correcta aunque el nombre del municipio no esté en la tabla.
    private func mapToRegion(placemark: CLPlacemark) throws -> Region {
        let table = try loadMunicipalities()
        let stateName = normalizeState(placemark.administrativeArea)

        // Candidatos de nombre. ORDEN IMPORTANTE: en CDMX `subLocality` y
        // `subAdministrativeArea` son la alcaldía; `locality` suele ser
        // "Ciudad de México". Probamos primero los más específicos para
        // captar nombres como "Cuauhtémoc" (alcaldía), pero el filtro por
        // estado evita confundirla con Cuauhtémoc, Chihuahua.
        let nameCandidates: [String] = [
            placemark.subLocality,
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        // 1. Match exacto cruzado con estado.
        if let state = stateName {
            for name in nameCandidates {
                if let entry = table.first(where: {
                    $0.municipality.lowercased() == name.lowercased() &&
                    normalize($0.state) == state
                }) {
                    return entry.toRegion()
                }
            }
        }

        // 2. Match normalizado (sin tildes, sin sufijos comunes) cruzado con estado.
        if let state = stateName {
            for name in nameCandidates {
                let normName = normalize(name)
                if let entry = table.first(where: {
                    matchesMunicipality(normalized: normName, entry: $0) &&
                    normalize($0.state) == state
                }) {
                    return entry.toRegion()
                }
            }
        }

        // 3. Match exacto solo por nombre (Apple a veces no llena `administrativeArea`).
        for name in nameCandidates {
            if let entry = table.first(where: {
                $0.municipality.lowercased() == name.lowercased()
            }) {
                return entry.toRegion()
            }
        }

        // 4. Fallback por estado: si tenemos estado pero no el municipio en la tabla,
        // devolvemos una región sintética con la tarifa default del estado.
        if let state = stateName,
           let region = regionFromStateFallback(normalizedState: state, placemark: placemark) {
            return region
        }

        throw LocationError.mappingFailed
    }

    /// Construye una `Region` sintética cuando solo conocemos el estado.
    /// Usa el `assignedTariffCode` de `stateFallbacks` (con fallback a "1") y
    /// preserva el nombre del municipio real reportado por Apple, para que
    /// el usuario vea "Coyoacán, Ciudad de México" aunque Coyoacán no esté
    /// listado individualmente en la tabla.
    private func regionFromStateFallback(normalizedState: String, placemark: CLPlacemark) -> Region? {
        guard let fallbacks = try? loadStateFallbacks() else { return nil }
        guard let match = fallbacks.first(where: { normalize($0.state) == normalizedState }) else {
            return nil
        }

        // Tomar la temperatura promedio del estado desde los municipios listados
        // (mejor que inventar un número).
        let table = (try? loadMunicipalities()) ?? []
        let stateMunicipalities = table.filter { normalize($0.state) == normalizedState }
        let avgTemp: Double = {
            guard !stateMunicipalities.isEmpty else { return 18.0 }
            let sum = stateMunicipalities.map { $0.averageSummerMinTemp }.reduce(0, +)
            return sum / Double(stateMunicipalities.count)
        }()

        let municipalityName = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.subLocality
            ?? match.state

        return Region(
            id: "mx-fallback-\(normalizedState)",
            municipality: municipalityName,
            state: match.state, // estado canónico desde la tabla (con capitalización oficial)
            assignedTariffCode: match.defaultTariff,
            averageSummerMinTemp: avgTemp
        )
    }

    // MARK: - Normalización de nombres

    /// Quita tildes, lower-case, colapsa espacios.
    /// "Querétaro" → "queretaro", "  San Pedro " → "san pedro".
    private func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeState(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return normalize(s)
    }

    /// Match tolerante para municipios con sufijos largos. Apple a veces devuelve
    /// "Ecatepec de Morelos" cuando la tabla solo dice "Ecatepec", o
    /// "San Pedro Tlaquepaque" cuando la tabla dice "Tlaquepaque".
    /// La regla: coincidencia por palabras completas; uno tiene que ser
    /// subconjunto (en palabras) del otro.
    private func matchesMunicipality(normalized name: String, entry: MunicipalityEntry) -> Bool {
        let entryNorm = normalize(entry.municipality)
        if name == entryNorm { return true }
        // Coincidencia por palabras completas (evita que "leon" matchee "nuevo leon").
        let nameWords = Set(name.split(separator: " ").map(String.init))
        let entryWords = Set(entryNorm.split(separator: " ").map(String.init))
        // Si todas las palabras del entry están en el name, o todas las del name en el entry.
        if !entryWords.isEmpty && !nameWords.isEmpty {
            if entryWords.isSubset(of: nameWords) || nameWords.isSubset(of: entryWords) {
                return true
            }
        }
        return false
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    /// Se llama cuando el usuario responde al diálogo de permisos.
    /// Crítico para que `requestAuthorizationAndWait()` no quede colgado.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            // Si el estado sigue indeterminado, no resolver todavía (iOS a veces dispara
            // este delegate con .notDetermined antes de mostrar el diálogo).
            if manager.authorizationStatus == .notDetermined { return }
            guard let cont = self.authContinuation else { return }
            self.authContinuation = nil
            cont.resume(returning: ())
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last, let cont = self.locationContinuation else { return }
            self.locationContinuation = nil
            cont.resume(returning: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let cont = self.locationContinuation else { return }
            self.locationContinuation = nil
            cont.resume(throwing: error)
        }
    }
}
