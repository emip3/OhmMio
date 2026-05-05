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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mapa de huella")
                            .font(.title2.weight(.bold))
                        Text("Cuándo conviene usar electrodomésticos pesados")
                            .font(.callout)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.horizontal)

                    switch viewModel.state {
                    case .loading:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    case .error(let msg):
                        errorState(msg)
                    case .loaded(let matrix, let nowHour):
                        loadedContent(matrix: matrix, nowHour: nowHour)
                    }
                }
                .padding(.vertical)
            }
            .background(DesignTokens.bgGreen.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: 24) {
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
        return VStack(alignment: .leading, spacing: 8) {
            Text("AHORA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)

            HStack(spacing: 12) {
                Circle()
                    .fill(DesignTokens.carbonColor(for: now?.level ?? .medium))
                    .frame(width: 16, height: 16)
                Text(levelDisplayName(now?.level ?? .medium))
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f kg CO₂/kWh", now?.kgCO2PerKwh ?? 0))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Color.secondary)
            }

            if let sources = now?.dominantSources {
                Text(sources)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func hourGrid(matrix: [CarbonIntensity], nowHour: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOY POR HORAS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                spacing: 6
            ) {
                ForEach(displayHours, id: \.self) { hour in
                    if let intensity = matrix.first(where: { $0.hour == hour }) {
                        hourCell(intensity: intensity, isCurrent: hour == roundedNowHour(nowHour))
                    }
                }
            }
        }
    }

    private func hourCell(intensity: CarbonIntensity, isCurrent: Bool) -> some View {
        Button {
            selectedHour = intensity
        } label: {
            VStack(spacing: 4) {
                Text(String(format: "%02d:00", intensity.hour))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(DesignTokens.carbonColor(for: intensity.level).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isCurrent ? Color.primary : Color.clear, lineWidth: 3)
            )
            .accessibilityLabel(
                "\(intensity.hour):00. \(levelDisplayName(intensity.level))."
            )
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LEYENDA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)

            HStack(spacing: 12) {
                legendItem(color: .green, label: "Limpia")
                legendItem(color: .orange, label: "Media")
                legendItem(color: .red, label: "Sucia")
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption)
        }
    }

    private func hourDetailSheet(_ intensity: CarbonIntensity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(DesignTokens.carbonColor(for: intensity.level))
                    .frame(width: 16, height: 16)
                Text("\(intensity.hour):00 — \(levelDisplayName(intensity.level))")
                    .font(.title3.weight(.bold))
            }

            Text(String(format: "%.2f kg CO₂ por kWh", intensity.kgCO2PerKwh))
                .font(.headline)
                .foregroundStyle(Color.secondary)

            if let sources = intensity.dominantSources {
                Text("Fuentes dominantes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                Text(sources).font(.body)
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.heroRed)
            Text(msg).foregroundStyle(Color.secondary)
            Button("Reintentar") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.accentSage)
        }
        .padding()
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

    /// Redondea la hora actual al múltiplo de 2 más cercano hacia abajo.
    private func roundedNowHour(_ hour: Int) -> Int {
        (hour / 2) * 2
    }
}
