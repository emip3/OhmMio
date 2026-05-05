//
//  StorageService.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftData

/// Única excepción a la regla "servicios sin estado": mantiene el contrato
/// con el contenedor de persistencia.
///
/// - SwiftData (`ModelContext`) para entidades del dominio: User, Receipt, Appliance.
/// - UserDefaults para flags ligeros de UI (onboarding, ajustes).
@MainActor
final class StorageService {

    // MARK: - SwiftData

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Devuelve el usuario actual o crea uno nuevo si no existe.
    /// La app es single-user (un perfil por dispositivo).
    func loadOrCreateUser() throws -> User {
        let descriptor = FetchDescriptor<User>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let new = User()
        context.insert(new)
        try context.save()
        return new
    }

    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    func insert<T: PersistentModel>(_ model: T) {
        context.insert(model)
    }

    func delete<T: PersistentModel>(_ model: T) {
        context.delete(model)
    }

    // MARK: - UserDefaults (flags de UI)

    private enum Keys {
        static let hasSeenWelcome = "ohmio.hasSeenWelcome"
        static let lastRefreshDate = "ohmio.lastRefreshDate"
    }

    var hasSeenWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasSeenWelcome) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasSeenWelcome) }
    }

    var lastRefreshDate: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastRefreshDate) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastRefreshDate) }
    }
}
