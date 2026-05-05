//
//  OnboardingView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

struct OnboardingView: View {

    @State var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    @State private var showScannerSheet = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .welcome:           welcomeStep
                case .scanReceipt:       scanStep
                case .selectAppliances:  appliancesStep
                }
            }
            .padding()
            .background(DesignTokens.bgGreen.ignoresSafeArea())
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.step)
        }
    }

    // MARK: - Paso 1

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 80))
                .foregroundStyle(DesignTokens.accentSage)

            VStack(spacing: 8) {
                Text("Bienvenido a OhMio")
                    .font(.largeTitle.weight(.bold))
                Text("Tu presupuesto energético, en una sola pantalla.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                benefitRow(icon: "gauge.medium",
                           title: "Conoce tu margen",
                           subtitle: "Cuánto puedes consumir antes del DAC.")
                benefitRow(icon: "leaf.fill",
                           title: "Reduce tu huella",
                           subtitle: "Aprende cuándo conviene usar electricidad.")
                benefitRow(icon: "lightbulb.fill",
                           title: "Recibe consejos diarios",
                           subtitle: "Una sola acción a la vez.")
            }
            .padding(.horizontal)

            Spacer()

            Button {
                viewModel.advanceFromWelcome()
            } label: {
                Text("Comenzar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignTokens.accentSage)
        }
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignTokens.accentSage)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(Color.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Paso 2

    private var scanStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Escanea tu recibo CFE")
                    .font(.title.weight(.bold))
                Text("Te ayudamos a leer tu tarifa y consumo automáticamente.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 100))
                .foregroundStyle(DesignTokens.accentSage)
                .padding(.vertical)

            if let parsed = viewModel.parsedReceipt {
                ConfirmReceiptView(parsed: Binding(
                    get: { parsed },
                    set: { viewModel.parsedReceipt = $0 }
                ))
                .transition(.opacity)
            }

            if viewModel.isProcessing {
                ProgressView("Leyendo recibo…")
                    .padding(.vertical)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.heroRed)
                    .font(.callout)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showScannerSheet = true
                } label: {
                    Label("Escanear", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(DesignTokens.accentSage)

                Button("Ingresar manualmente") {
                    viewModel.skipToManualEntry()
                }
                .font(.callout)

                if viewModel.parsedReceipt != nil {
                    Button {
                        viewModel.advanceToAppliances()
                    } label: {
                        Text("Continuar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .sheet(isPresented: $showScannerSheet) {
            ReceiptScannerSheet(
                onCapture: { image in
                    Task { await viewModel.handleCapturedImage(image) }
                },
                onManualEntry: {
                    viewModel.skipToManualEntry()
                }
            )
        }
    }

    // MARK: - Paso 3

    private var appliancesStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("¿Qué tienes en casa?")
                    .font(.title.weight(.bold))
                Text("Selecciona los aparatos que más usas.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
            }

            Text("Seleccionados: \(viewModel.selectedKeys.count)")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.secondary)

            ScrollView {
                ApplianceGridSelector(
                    catalog: viewModel.catalog,
                    selectedKeys: $viewModel.selectedKeys
                )
                .padding(.horizontal, 4)
            }

            Button {
                Task {
                    let ok = await viewModel.completeOnboarding()
                    if ok { onComplete() }
                }
            } label: {
                Text("Listo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignTokens.accentSage)
            .disabled(viewModel.selectedKeys.isEmpty)
        }
    }
}

// MARK: - Confirmación de recibo (sub-vista del paso 2)

private struct ConfirmReceiptView: View {
    @Binding var parsed: ReceiptParser.ParsedReceipt

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verifica los datos")
                .font(.headline)

            HStack {
                Text("Consumo (kWh)")
                Spacer()
                TextField(
                    "kWh",
                    value: Binding(
                        get: { parsed.kwhConsumed ?? 0 },
                        set: { parsed.kwhConsumed = $0 }
                    ),
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 100)
            }

            HStack {
                Text("Tarifa")
                Spacer()
                TextField(
                    "Ej. 1C",
                    text: Binding(
                        get: { parsed.tariffCode ?? "" },
                        set: { parsed.tariffCode = $0.uppercased() }
                    )
                )
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .frame(width: 100)
            }

            HStack {
                Text("Total ($MXN)")
                Spacer()
                TextField(
                    "Total",
                    value: Binding(
                        get: { parsed.totalAmountMXN ?? 0 },
                        set: { parsed.totalAmountMXN = $0 }
                    ),
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 100)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
