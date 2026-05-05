//
//  ApplianceGridSelector.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

/// Catálogo decodificado del JSON estático.
struct ApplianceCatalogEntry: Codable, Hashable, Identifiable {
    let categoryKey: String
    let category: String
    let displayName: String
    let sfSymbol: String
    let nominalWatts: Int
    let estimatedHoursDaily: Double
    let standbyWatts: Int
    let canBeShutOff: Bool
    let priorityWeight: Int
    let notes: String?

    var id: String { categoryKey }
}

/// Grid 2×N de tarjetas tappables para selección de aparatos.
/// Usado en onboarding y en edición de perfil.
struct ApplianceGridSelector: View {

    let catalog: [ApplianceCatalogEntry]
    @Binding var selectedKeys: Set<String>

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(catalog) { entry in
                applianceCard(entry)
            }
        }
    }

    private func applianceCard(_ entry: ApplianceCatalogEntry) -> some View {
        let isSelected = selectedKeys.contains(entry.categoryKey)

        return Button {
            toggle(entry.categoryKey)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: entry.sfSymbol)
                    .font(.title)
                    .foregroundStyle(isSelected ? DesignTokens.accentSage : Color.secondary)

                Text(entry.displayName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? DesignTokens.bgGreen : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? DesignTokens.accentSage : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.accentSage)
                        .background(Circle().fill(Color.white))
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.displayName). \(isSelected ? "Seleccionado" : "No seleccionado").")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(_ key: String) {
        if selectedKeys.contains(key) {
            selectedKeys.remove(key)
        } else {
            selectedKeys.insert(key)
        }
    }
}
