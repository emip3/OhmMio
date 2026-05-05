//
//  OhmMioApp.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI
import SwiftData

@main
struct OhMioApp: App {

    /// Contenedor de SwiftData configurado con todos los @Model del dominio.
    /// Se inyecta vía environment para que cualquier vista pueda acceder al ModelContext.
    let container: ModelContainer = {
        do {
            let schema = Schema([
                User.self,
                Receipt.self,
                Appliance.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
