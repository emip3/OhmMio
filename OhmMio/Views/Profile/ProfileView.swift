//
//  ProfileView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

struct ProfileView: View {

    @State var viewModel: ProfileViewModel
    @State private var showAppliancesSheet = false
    @State private var showReceiptSheet = false
<<<<<<< HEAD
    @State private var showScannerSheet = false
    @State private var showReceiptOptions = false
=======
    @State private var showRegionPickerSheet = false
>>>>>>> origin/main
    @State private var editableReceipt = ReceiptParser.ParsedReceipt()

    @FocusState private var receiptFieldFocus: ReceiptField?

    enum ReceiptField: Hashable {
        case kwh, tariff, total
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .error(let msg):
                    Text(msg).foregroundStyle(Color.secondary)
                case .loaded(let user, let tariff):
                    Form {
                        zoneSection(user: user, tariff: tariff)
                        receiptSection(user: user)
                        appliancesSection(user: user)
                        settingsSection(user: user)
                    }
                }
            }
            .navigationTitle("Perfil")
            .background(DesignTokens.bgGreen.ignoresSafeArea())
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showAppliancesSheet) {
            appliancesEditorSheet
        }
        .sheet(isPresented: $showReceiptSheet) {
            receiptEditorSheet
        }
<<<<<<< HEAD
        .fullScreenCover(isPresented: $showScannerSheet) {
            ScannerView(viewModel: ScannerViewModel(storage: viewModel.storage))
=======
        .sheet(isPresented: $showRegionPickerSheet) {
            regionPickerSheet
>>>>>>> origin/main
        }
    }

    // MARK: - Sección Zona

    private func zoneSection(user: User, tariff: Tariff?) -> some View {
        Section("Tu zona") {
            HStack {
                Text("Municipio")
                Spacer()
                Text(user.region?.municipality ?? "No detectado")
                    .foregroundStyle(Color.secondary)
            }

            if let region = user.region {
                HStack {
                    Text("Estado")
                    Spacer()
                    Text(region.state).foregroundStyle(Color.secondary)
                }
            }

            HStack {
                Text("Tarifa")
                Spacer()
                Text(tariff?.code ?? user.region?.assignedTariffCode ?? "—")
                    .foregroundStyle(Color.secondary)
            }

            if let tariff {
                HStack {
                    Text("Límite bimestral")
                    Spacer()
                    Text("\(tariff.monthlyLimitKwh * 2) kWh")
                        .foregroundStyle(Color.secondary)
                }
            }

            // Acciones de ubicación: detección por GPS o selección manual.
            // Siempre visibles para que el usuario pueda corregir si la detección
            // automática asignó un municipio incorrecto.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.detectRegion() }
                    } label: {
                        Label(
                            user.region == nil ? "Detectar mi municipio" : "Volver a detectar",
                            systemImage: "location.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(DesignTokens.accentSage)
                    .disabled(viewModel.isUpdatingRegion)

                    Button("Elegir manualmente") {
                        viewModel.loadMunicipalitiesForPicker()
                        showRegionPickerSheet = true
                    }
                    .font(.callout)
                    .disabled(viewModel.isUpdatingRegion)
                }

                if viewModel.isUpdatingRegion {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Detectando ubicación…")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }

                if let msg = viewModel.locationStatusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Sección Recibo

    private func receiptSection(user: User) -> some View {
        Section("Tu último recibo") {
            if let receipt = user.currentReceipt {
                HStack {
                    Text("Consumo")
                    Spacer()
                    Text("\(receipt.kwhConsumed) kWh").foregroundStyle(Color.secondary)
                }
                HStack {
                    Text("Total")
                    Spacer()
                    Text(String(format: "$%.2f MXN", receipt.totalAmountMXN))
                        .foregroundStyle(Color.secondary)
                }
            } else {
                Text("Sin recibo registrado").foregroundStyle(Color.secondary)
            }

            Button("Editar recibo") {
                showReceiptOptions = true
            }
            .confirmationDialog("Actualizar recibo", isPresented: $showReceiptOptions) {
                Button("Escanear con cámara") {
                    showScannerSheet = true
                }
                Button("Rellenar manualmente") {
                    editableReceipt = ReceiptParser.ParsedReceipt(
                        kwhConsumed: user.currentReceipt?.kwhConsumed,
                        tariffCode: user.currentReceipt?.tariffCode,
                        totalAmountMXN: user.currentReceipt?.totalAmountMXN,
                        billingPeriodStart: user.currentReceipt?.billingPeriodStart,
                        billingPeriodEnd: user.currentReceipt?.billingPeriodEnd,
                        twelveMonthAverage: user.currentReceipt?.twelveMonthAverage
                    )
                    showReceiptSheet = true
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("¿Cómo deseas actualizar tu recibo?")
            }
        }
    }

    private func appliancesSection(user: User) -> some View {
        Section("Tus aparatos") {
            ForEach(user.selectedAppliances) { appliance in
                HStack {
                    Image(systemName: appliance.sfSymbol)
                        .foregroundStyle(DesignTokens.accentSage)
                    Text(appliance.displayName)
                    Spacer()
                    Text(String(format: "%.1f kWh/d", appliance.totalDailyKwh))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            Button("Editar lista de aparatos") {
                showAppliancesSheet = true
            }
        }
    }

    private func settingsSection(user: User) -> some View {
        Section("Ajustes") {
            Toggle("Notificaciones", isOn: Binding(
                get: { user.preferences.notificationsEnabled },
                set: { user.preferences.notificationsEnabled = $0 }
            ))

            Picker("Apariencia", selection: Binding(
                get: { user.preferences.preferredColorScheme },
                set: { user.preferences.preferredColorScheme = $0 }
            )) {
                Text("Sistema").tag(UserPreferences.ColorSchemePreference.system)
                Text("Claro").tag(UserPreferences.ColorSchemePreference.light)
                Text("Oscuro").tag(UserPreferences.ColorSchemePreference.dark)
            }

            HStack {
                Text("Acerca de OhMio")
                Spacer()
                Text("v1.0").foregroundStyle(Color.secondary)
            }
        }
    }

    // MARK: - Sheets

    private var appliancesEditorSheet: some View {
        NavigationStack {
            ScrollView {
                if case .loaded(let user, _) = viewModel.state {
                    let initialKeys = Set(user.selectedAppliances.map { $0.categoryKey })
                    AppliancesEditorContent(
                        catalog: viewModel.catalog,
                        initialKeys: initialKeys,
                        onSave: { keys in
                            Task {
                                await viewModel.updateAppliances(selectedKeys: keys)
                                showAppliancesSheet = false
                            }
                        }
                    )
                }
            }
            .navigationTitle("Editar aparatos")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var receiptEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Datos del recibo") {
                    HStack {
                        Text("Consumo (kWh)")
                        Spacer()
                        TextField("kWh", value: Binding(
                            get: { editableReceipt.kwhConsumed ?? 0 },
                            set: { editableReceipt.kwhConsumed = $0 }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .focused($receiptFieldFocus, equals: .kwh)
                    }
                    HStack {
                        Text("Tarifa")
                        Spacer()
                        TextField("Ej. 1C", text: Binding(
                            get: { editableReceipt.tariffCode ?? "" },
                            set: { editableReceipt.tariffCode = $0.uppercased() }
                        ))
                        .multilineTextAlignment(.trailing)
                        .focused($receiptFieldFocus, equals: .tariff)
                    }
                    HStack {
                        Text("Total ($MXN)")
                        Spacer()
                        TextField("Total", value: Binding(
                            get: { editableReceipt.totalAmountMXN ?? 0 },
                            set: { editableReceipt.totalAmountMXN = $0 }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($receiptFieldFocus, equals: .total)
                    }
                }
            }
            .navigationTitle("Editar recibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showReceiptSheet = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Guardar") {
                        Task {
                            await viewModel.updateReceipt(parsed: editableReceipt)
                            showReceiptSheet = false
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") {
                        receiptFieldFocus = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var regionPickerSheet: some View {
        NavigationStack {
            RegionPickerContent(
                regions: viewModel.availableMunicipalities,
                onSelect: { region in
                    Task {
                        await viewModel.setRegionManually(region)
                        showRegionPickerSheet = false
                    }
                }
            )
            .navigationTitle("Elegir municipio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { showRegionPickerSheet = false }
                }
            }
        }
    }
}

// MARK: - Sub-vista: editor de aparatos

private struct AppliancesEditorContent: View {
    let catalog: [ApplianceCatalogEntry]
    let initialKeys: Set<String>
    let onSave: (Set<String>) -> Void

    @State private var selectedKeys: Set<String> = []

    var body: some View {
        VStack(spacing: 16) {
            ApplianceGridSelector(
                catalog: catalog,
                selectedKeys: $selectedKeys
            )
            .padding()

            Button {
                onSave(selectedKeys)
            } label: {
                Text("Guardar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignTokens.accentSage)
            .padding(.horizontal)
        }
        .onAppear {
            selectedKeys = initialKeys
        }
    }
}

// MARK: - Sub-vista: picker de municipio (fallback manual)

private struct RegionPickerContent: View {
    let regions: [Region]
    let onSelect: (Region) -> Void

    @State private var searchText: String = ""

    private var filtered: [Region] {
        guard !searchText.isEmpty else { return regions }
        let q = searchText.lowercased()
        return regions.filter {
            $0.municipality.lowercased().contains(q) ||
            $0.state.lowercased().contains(q)
        }
    }

    var body: some View {
        List(filtered) { region in
            Button {
                onSelect(region)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(region.municipality)
                            .foregroundStyle(Color.primary)
                        Text(region.state)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    Text("Tarifa \(region.assignedTariffCode)")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.accentSage)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Buscar estado")
        .overlay {
            if regions.isEmpty {
                ProgressView("Cargando municipios…")
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}
