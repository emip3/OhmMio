//
//  User.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var preferences: UserPreferences
    var region: Region?

    @Relationship(deleteRule: .cascade, inverse: \Receipt.owner)
    var receiptHistory: [Receipt] = []

    @Relationship(deleteRule: .cascade, inverse: \Appliance.owner)
    var selectedAppliances: [Appliance] = []

    init(
        id: UUID = UUID(),
        hasCompletedOnboarding: Bool = false,
        preferences: UserPreferences = UserPreferences(),
        region: Region? = nil
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.preferences = preferences
        self.region = region
    }

    /// Recibo más reciente del usuario, calculado desde `receiptHistory`.
    /// Centraliza la verdad en una sola colección y evita inconsistencias.
    var currentReceipt: Receipt? {
        receiptHistory.max(by: { $0.scannedAt < $1.scannedAt })
    }
}

// MARK: - UserPreferences

struct UserPreferences: Codable, Equatable, Hashable {
    var notificationsEnabled: Bool
    var preferredColorScheme: ColorSchemePreference
    var hasAcceptedAILimitations: Bool

    init(
        notificationsEnabled: Bool = true,
        preferredColorScheme: ColorSchemePreference = .system,
        hasAcceptedAILimitations: Bool = false
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.preferredColorScheme = preferredColorScheme
        self.hasAcceptedAILimitations = hasAcceptedAILimitations
    }

    enum ColorSchemePreference: String, Codable, CaseIterable, Hashable {
        case system, light, dark
    }
}
