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

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Necesitamos tu ubicación para asignar tu tarifa."
            case .unavailable:      return "Ubicación no disponible."
            case .mappingFailed:    return "No pudimos identificar tu municipio."
            case .fileNotFound:     return "Datos de tarifas no disponibles."
            }
        }
    }

    private let manager = CLLocationManager()

    // Continuación para la solicitud de ubicación (didUpdateLocations / didFailWithError)
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    // Continuación para la solicitud de autorización (locationManagerDidChangeAuthorization)
    // Es separada porque las dos cosas ocurren en momentos distintos del flujo.
    private var authContinuation: CheckedContinuation<Void, Never>?

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

        // Caso 4: ya tenemos permiso, pedir ubicación real.
        return try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont
            manager.requestLocation()
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
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
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

    /// El JSON real tiene la forma `{ "metadata": {...}, "municipalities": [...] }`
    /// por eso decodificamos con un wrapper en lugar de `[MunicipalityEntry].self` directo.
    private struct MunicipalityFile: Codable {
        let municipalities: [MunicipalityEntry]
    }

    private func loadMunicipalities() throws -> [MunicipalityEntry] {
        guard let url = Bundle.main.url(forResource: "MunicipalityTariffs", withExtension: "json") else {
            throw LocationError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(MunicipalityFile.self, from: data)
        return file.municipalities
    }

    private func mapToRegion(placemark: CLPlacemark) throws -> Region {
        // Intentamos varios campos del placemark, porque CLGeocoder no siempre llena `locality`.
        let candidates: [String?] = [
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.subLocality,
            placemark.administrativeArea
        ]

        for candidate in candidates {
            guard let name = candidate, !name.isEmpty else { continue }
            if let region = try? region(forMunicipality: name) {
                return region
            }
        }
        throw LocationError.mappingFailed
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
