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
                                .font(.title3.weight(.medium))
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
        VStack(alignment: .leading, spacing: 36) {
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(DesignTokens.accentSage)
                        .font(.title2)
                    Text("Impacto Ambiental")
                        .font(.title2.weight(.heavy))
                }
                Text("Los watts que usas son los mismos, pero al ocuparlos en horarios distintos reduces tu huella de carbono. Elegir horas \"Limpias\" evita que se quemen combustibles fósiles, cuidando tu entorno y el planeta.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
            .padding(.horizontal)

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
        return VStack(alignment: .leading, spacing: 16) {
            Text("AHORA")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(gridColor(for: now?.level ?? .medium))
                            .frame(width: 24, height: 24)
                        Text(levelDisplayName(now?.level ?? .medium))
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Color.primary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "%.2f", now?.kgCO2PerKwh ?? 0))
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(gridColor(for: now?.level ?? .medium))
                    Text("kg CO₂ / kWh")
                        .font(.caption.weight(.bold))
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
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                spacing: 16
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
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text(String(format: "%.2f", intensity.kgCO2PerKwh))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.primary.opacity(0.6))
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(
                ZStack {
                    // Color sólido, sin degradado
                    RoundedRectangle(cornerRadius: 18)
                        .fill(gridColor(for: intensity.level).opacity(0.85))
                    // Borde interno blanco sutil (efecto burbuja sin degradado)
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                }
            )
            .shadow(
                color: gridColor(for: intensity.level).opacity(isCurrent ? 0.55 : 0.2),
                radius: isCurrent ? 16 : 8,
                y: isCurrent ? 8 : 4
            )
            .scaleEffect(isCurrent ? 1.07 : 1.0)
            .accessibilityLabel(
                "\(intensity.hour):00. \(levelDisplayName(intensity.level))."
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrent)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEYENDA")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)

            HStack(spacing: 24) {
                legendItem(color: DesignTokens.heroGreen, label: "Limpia")
                legendItem(color: DesignTokens.heroPeach, label: "Media")
                legendItem(color: DesignTokens.heroRed, label: "Sucia")
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 20, height: 20)
            Text(label)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.primary)
        }
    }

    private func hourDetailSheet(_ intensity: CarbonIntensity) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(gridColor(for: intensity.level))
                    .frame(width: 24, height: 24)
                Text("\(String(format: "%02d", intensity.hour)):00 — \(levelDisplayName(intensity.level))")
                    .font(.title.weight(.heavy))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Huella de Carbono")
                    .font(.headline)
                    .foregroundStyle(Color.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.2f", intensity.kgCO2PerKwh))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(gridColor(for: intensity.level))
                    Text("kg CO₂ por kWh")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.secondary)
                }
            }
            
            Text(explainerText(for: intensity.level))
                .font(.body.weight(.medium))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gridColor(for: intensity.level).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .padding(32)
        .presentationDetents([.height(340)])
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

    private func explainerText(for level: CarbonIntensity.Level) -> String {
        switch level {
        case .clean: return "¡Excelente momento! Gran parte de la energía viene del sol o el viento. Úsala sin culpa."
        case .medium: return "Momento aceptable. La red está balanceada entre energías limpias y fósiles."
        case .dirty: return "¡Evita este horario! Se queman muchos combustibles fósiles para cubrir los picos de demanda."
        }
    }

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
