import SwiftUI

struct ScannerView: View {
    @State var viewModel: ScannerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if case .idle = viewModel.state {
                ReceiptScannerSheet(
                    onCapture: { image in
                        Task { await viewModel.processImage(image) }
                    },
                    onManualEntry: {
                        dismiss()
                    }
                )
            } else {
                NavigationStack {
                    ZStack {
                        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                        
                        if case .processing = viewModel.state {
                            VStack(spacing: 24) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Leyendo recibo...")
                                    .font(.headline)
                                    .foregroundStyle(Color.secondary)
                            }
                        } else if case .confirm(var parsed) = viewModel.state {
                            VStack(spacing: 24) {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundStyle(DesignTokens.accentSage)
                                    Text("Recibo escaneado")
                                        .font(.title.weight(.bold))
                                    Text("Verifica que los datos sean correctos.")
                                        .font(.body)
                                        .foregroundStyle(Color.secondary)
                                }
                                .padding(.top, 20)

                                Form {
                                    Section("Datos detectados") {
                                        HStack {
                                            Text("Consumo (kWh)")
                                            Spacer()
                                            TextField("kWh", value: Binding(
                                                get: { parsed.kwhConsumed ?? 0 },
                                                set: { parsed.kwhConsumed = $0; viewModel.state = .confirm(parsed) }
                                            ), format: .number)
                                            .multilineTextAlignment(.trailing)
                                            .keyboardType(.numberPad)
                                        }
                                        HStack {
                                            Text("Tarifa")
                                            Spacer()
                                            TextField("Ej. 1C", text: Binding(
                                                get: { parsed.tariffCode ?? "" },
                                                set: { parsed.tariffCode = $0.uppercased(); viewModel.state = .confirm(parsed) }
                                            ))
                                            .multilineTextAlignment(.trailing)
                                        }
                                        HStack {
                                            Text("Total ($MXN)")
                                            Spacer()
                                            TextField("Total", value: Binding(
                                                get: { parsed.totalAmountMXN ?? 0 },
                                                set: { parsed.totalAmountMXN = $0; viewModel.state = .confirm(parsed) }
                                            ), format: .number)
                                            .multilineTextAlignment(.trailing)
                                            .keyboardType(.decimalPad)
                                        }
                                    }
                                }

                                Button {
                                    viewModel.saveReceipt(parsed: parsed)
                                } label: {
                                    Text("Guardar recibo")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(DesignTokens.accentSage)
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                        } else if case .success = viewModel.state {
                            Color.clear.onAppear { dismiss() }
                        } else if case .error(let msg) = viewModel.state {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.red)
                                Text("Error al escanear")
                                    .font(.headline)
                                Text(msg)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Button("Reintentar") { viewModel.state = .idle }
                                    .buttonStyle(.borderedProminent)
                                Button("Cancelar") { dismiss() }
                            }
                            .padding()
                        }
                    }
                    .navigationTitle(navigationTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if case .confirm = viewModel.state {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancelar") { dismiss() }
                            }
                        } else if case .error = viewModel.state {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cerrar") { dismiss() }
                            }
                        }
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.state {
        case .idle: return ""
        case .processing: return ""
        case .confirm: return "Verificar"
        case .error: return "Error"
        case .success: return ""
        }
    }
}
