//
//  CarbonMapView.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

struct CarbonMapView: View {

    @State var viewModel: CarbonMapViewModel
    @State private var selectedHour: CarbonIntensity?

    private let displayHours = stride(from: 0, through: 22, by: 2).map { $0 }

    var body: some View {
        NavigationStack {
            ZStack {
                // Nuevo fondo durazno claro para variar
                DesignTokens.bgPeach.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mapa de huella")
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(DesignTokens.accentSage)
                            Text("Cuándo conviene usar electrodomésticos pesados")
                                .font(.body)
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)

                        switch viewModel.state {
                        case .loading:
                            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                        case .error(let msg):
                            errorState(msg)
                        case .loaded(let matrix, let nowHour):
                            loadedContent(matrix: matrix, nowHour: nowHour)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Red")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.load() }
        .sheet(
            isPresented: Binding(
                get: { selectedHour != nil },
                set: { if !$0 { selectedHour = nil } }
            ),
            onDismiss: { selectedHour = nil }
        ) {
            if let intensity = selectedHour {
                hourDetailSheet(intensity)
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func loadedContent(matrix: [CarbonIntensity], nowHour: Int) -> some View {
        VStack(alignment: .leading, spacing: 32) {
            nowCard(matrix: matrix, nowHour: nowHour)
                .padding(.horizontal)

            hourGrid(matrix: matrix, nowHour: nowHour)
                .padding(.horizontal)

            legend
                .padding(.horizontal)
        }
    }

    private func nowCard(matrix: [CarbonIntensity], nowHour: Int) -> some View {
        let now = matrix.first { $0.hour == nowHour }
        return VStack(alignment: .leading, spacing: 12) {
            Text("AHORA")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(gridColor(for: now?.level ?? .medium))
                        .frame(width: 16, height: 16)
                    
                    Text(levelDisplayName(now?.level ?? .medium))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.primary)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f kg CO₂/kWh", now?.kgCO2PerKwh ?? 0))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }

    private func hourGrid(matrix: [CarbonIntensity], nowHour: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HOY POR HORAS")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)

            // Grid unido como matriz visual continua
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 6),
                spacing: 2
            ) {
                ForEach(displayHours, id: \.self) { hour in
                    if let intensity = matrix.first(where: { $0.hour == hour }) {
                        hourCell(intensity: intensity, isCurrent: hour == roundedNowHour(nowHour))
                    }
                }
            }
            .background(Color.white) // Hace de líneas divisorias finas
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
        }
    }

    private func hourCell(intensity: CarbonIntensity, isCurrent: Bool) -> some View {
        Button {
            selectedHour = intensity
        } label: {
            VStack(spacing: 0) {
                Text(String(format: "%02d:00", intensity.hour))
                    .font(.body.weight(.heavy))
                    .foregroundStyle(Color.primary) // Excelente contraste WCAG
            }
            .frame(maxWidth: .infinity, minHeight: 64) // Celdas mucho más altas
            .background(gridGradient(for: intensity.level))
            .overlay(
                // Contorno interior grueso para la hora actual
                Rectangle()
                    .stroke(isCurrent ? Color.primary : Color.clear, lineWidth: isCurrent ? 4 : 0)
            )
            .accessibilityLabel(
                "\(intensity.hour):00. \(levelDisplayName(intensity.level))."
            )
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEYENDA")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)

            HStack(spacing: 20) {
                legendItem(color: DesignTokens.heroGreen, label: "Limpia")
                legendItem(color: DesignTokens.heroPeach, label: "Media")
                legendItem(color: DesignTokens.heroRed, label: "Sucia")
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 14, height: 14)
            Text(label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.primary)
        }
    }

    private func hourDetailSheet(_ intensity: CarbonIntensity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(gridColor(for: intensity.level))
                    .frame(width: 16, height: 16)
                Text("\(intensity.hour):00 — \(levelDisplayName(intensity.level))")
                    .font(.title3.weight(.bold))
            }

            Text(String(format: "%.2f kg CO₂ por kWh", intensity.kgCO2PerKwh))
                .font(.headline)
                .foregroundStyle(Color.secondary)

            Spacer()
        }
        .padding(24)
        .presentationDetents([.height(140)])
        .presentationBackground(.regularMaterial)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.heroRed)
                .font(.system(size: 60))
            Text(msg)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.accentSage)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func levelDisplayName(_ level: CarbonIntensity.Level) -> String {
        switch level {
        case .clean:  return "Red limpia"
        case .medium: return "Red en mezcla típica"
        case .dirty:  return "Pico de demanda"
        }
    }
    
    private func gridColor(for level: CarbonIntensity.Level) -> Color {
        switch level {
        case .clean:  return DesignTokens.heroGreen
        case .medium: return DesignTokens.heroPeach
        case .dirty:  return DesignTokens.heroRed
        }
    }

    /// Genera un degradado sutil para la matriz
    private func gridGradient(for level: CarbonIntensity.Level) -> LinearGradient {
        let baseColor = gridColor(for: level)
        return LinearGradient(
            colors: [baseColor.opacity(0.7), baseColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Redondea la hora actual al múltiplo de 2 más cercano hacia abajo.
    private func roundedNowHour(_ hour: Int) -> Int {
        (hour / 2) * 2
    }
}
