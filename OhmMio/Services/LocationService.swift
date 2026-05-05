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
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Solicita ubicación y devuelve la `Region` correspondiente.
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

    // MARK: - CoreLocation

    private func requestLocation() async throws -> CLLocation {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            throw LocationError.permissionDenied
        }
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
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

    private func loadMunicipalities() throws -> [MunicipalityEntry] {
        guard let url = Bundle.main.url(forResource: "MunicipalityTariffs", withExtension: "json") else {
            throw LocationError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([MunicipalityEntry].self, from: data)
    }

    private func mapToRegion(placemark: CLPlacemark) throws -> Region {
        let municipality = placemark.locality ?? placemark.subAdministrativeArea ?? ""
        guard !municipality.isEmpty else { throw LocationError.mappingFailed }
        return try region(forMunicipality: municipality)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last, let cont = self.continuation else { return }
            self.continuation = nil
            cont.resume(returning: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let cont = self.continuation else { return }
            self.continuation = nil
            cont.resume(throwing: error)
        }
    }
}
