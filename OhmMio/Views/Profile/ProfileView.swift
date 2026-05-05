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
    @State private var showScannerSheet = false
    @State private var showReceiptOptions = false
    @State private var editableReceipt = ReceiptParser.ParsedReceipt()

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
        .fullScreenCover(isPresented: $showScannerSheet) {
            ScannerView(viewModel: ScannerViewModel(storage: viewModel.storage))
        }
    }

    // MARK: - Secciones

    private func zoneSection(user: User, tariff: Tariff?) -> some View {
        Section("Tu zona") {
            HStack {
                Text("Municipio")
                Spacer()
                Text(user.region?.municipality ?? "No detectado")
                    .foregroundStyle(Color.secondary)
            }
            HStack {
                Text("Tarifa")
                Spacer()
                Text(tariff?.code ?? "—")
                    .foregroundStyle(Color.secondary)
            }
            if let tariff {
                HStack {
                    Text("Límite mensual")
                    Spacer()
                    Text("\(tariff.monthlyLimitKwh) kWh")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

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
                    }
                    HStack {
                        Text("Tarifa")
                        Spacer()
                        TextField("Ej. 1C", text: Binding(
                            get: { editableReceipt.tariffCode ?? "" },
                            set: { editableReceipt.tariffCode = $0.uppercased() }
                        ))
                        .multilineTextAlignment(.trailing)
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
