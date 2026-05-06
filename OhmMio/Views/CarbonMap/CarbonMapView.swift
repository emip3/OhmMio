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
                // Fondo durazno claro (mantenemos la diferenciación atmosférica
                // entre tabs).
                DesignTokens.bgPeach.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Subtítulo bajo el navigation title (que ahora es
                        // "Red" con large display, nativo de iOS).
                        Text("Cuándo conviene usar electrodomésticos pesados")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
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
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            // Title nativo de iOS, large display (más Apple que un H1
            // custom de 42pt en el body).
            .navigationTitle("Red")
            .navigationBarTitleDisplayMode(.large)
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

            // Card explicativa — material translúcido (más Apple) y
            // tipografía semántica.
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(DesignTokens.accentSage)
                        .symbolEffect(.pulse, options: .repeat(.continuous))
                    Text("Impacto ambiental")
                        .font(.headline)
                }
                Text("Los watts que usas son los mismos, pero al ocuparlos en horarios distintos reduces tu huella de carbono. Elegir horas \"limpias\" evita que se quemen combustibles fósiles.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            nowCard(matrix: matrix, nowHour: nowHour)
                .padding(.horizontal)

            hourGrid(matrix: matrix, nowHour: nowHour)
                .padding(.horizontal)

            legend
                .padding(.horizontal)
        }
    }

    // MARK: - Card "AHORA"

    private func nowCard(matrix: [CarbonIntensity], nowHour: Int) -> some View {
        let now = matrix.first { $0.hour == nowHour }
        let level = now?.level ?? .medium

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                Text("AHORA · \(String(format: "%02d", nowHour)):00")
            }
            .font(.ohmSectionLabel)
            .foregroundStyle(Color.secondary)
            .textCase(.uppercase)

            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(gridColor(for: level))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        )
                    Text(levelDisplayName(level))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "%.2f", now?.kgCO2PerKwh ?? 0))
                        .font(.ohmStatNumber)
                        .foregroundStyle(gridColor(for: level))
                        .contentTransition(.numericText())
                    Text("kg CO₂ / kWh")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(gridColor(for: level).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Grid de horas

    private func hourGrid(matrix: [CarbonIntensity], nowHour: Int) -> some View {
        let currentRoundedHour = roundedNowHour(nowHour)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Hoy por horas")
                    .font(.ohmSectionLabel)
                    .foregroundStyle(Color.secondary)
                    .textCase(.uppercase)

                Spacer()

                // Mini-leyenda: indica que la celda con halo es la hora
                // actual. Refuerza la intención visual.
                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignTokens.accentSage)
                        .frame(width: 6, height: 6)
                    Text("Estás aquí")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.secondary)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(displayHours, id: \.self) { hour in
                    if let intensity = matrix.first(where: { $0.hour == hour }) {
                        hourCell(
                            intensity: intensity,
                            isCurrent: hour == currentRoundedHour
                        )
                    }
                }
            }
        }
    }

    // MARK: - Celda individual del grid
    //
    // Antes la celda actual sólo crecía 1.07× con un shadow más fuerte —
    // demasiado sutil. Ahora:
    //   • Badge "AHORA" flotante en la esquina superior derecha
    //   • Anillo de color del nivel (3pt) con halo difuso
    //   • Las celdas no actuales bajan a 0.55 de opacidad → contraste claro
    //   • Spring + symbolEffect pulse en el reloj del badge
    //   • Tipografía semántica (.ohmGridHour) que respeta Dynamic Type

    private func hourCell(intensity: CarbonIntensity, isCurrent: Bool) -> some View {
        let color = gridColor(for: intensity.level)

        return Button {
            selectedHour = intensity
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Text(String(format: "%02d:00", intensity.hour))
                        .font(.ohmGridHour)
                        .foregroundStyle(isCurrent ? Color.white : Color.primary)
                    Text(String(format: "%.2f", intensity.kgCO2PerKwh))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(
                            isCurrent
                                ? Color.white.opacity(0.85)
                                : Color.primary.opacity(0.55)
                        )
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isCurrent
                                ? color
                                : color.opacity(0.18)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCurrent ? color : Color.clear,
                            lineWidth: 0
                        )
                )

                // Badge flotante "AHORA" — sólo en la celda actual.
                if isCurrent {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .symbolEffect(.pulse, options: .repeat(.continuous))
                        Text("AHORA")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: 6, y: -8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isCurrent ? 1.05 : 1.0)
        .opacity(isCurrent ? 1.0 : 0.92)
        .shadow(
            color: isCurrent ? color.opacity(0.45) : color.opacity(0.10),
            radius: isCurrent ? 14 : 4,
            y: isCurrent ? 6 : 2
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isCurrent)
        .accessibilityLabel(
            "\(intensity.hour):00. \(levelDisplayName(intensity.level))." +
            (isCurrent ? " Hora actual." : "")
        )
    }

    // MARK: - Leyenda

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Leyenda")
                .font(.ohmSectionLabel)
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)

            HStack(spacing: 16) {
                legendItem(color: DesignTokens.heroGreen, label: "Limpia")
                legendItem(color: DesignTokens.heroPeach, label: "Media")
                legendItem(color: DesignTokens.heroRed, label: "Sucia")
                Spacer()
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
        }
    }

    // MARK: - Sheet de detalle por hora

    private func hourDetailSheet(_ intensity: CarbonIntensity) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(gridColor(for: intensity.level))
                    .frame(width: 18, height: 18)
                Text("\(String(format: "%02d", intensity.hour)):00 — \(levelDisplayName(intensity.level))")
                    .font(.title3.weight(.heavy))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Huella de carbono")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.2f", intensity.kgCO2PerKwh))
                        .font(.ohmHero)
                        .foregroundStyle(gridColor(for: intensity.level))
                    Text("kg CO₂ por kWh")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
            }

            Text(explainerText(for: intensity.level))
                .font(.callout)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gridColor(for: intensity.level).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14))

            Spacer()
        }
        .padding(28)
        .presentationDetents([.height(320)])
        .presentationBackground(.regularMaterial)
        .presentationDragIndicator(.visible)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.heroRed)
                .font(.largeTitle)
            Text(msg)
                .font(.callout)
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

    /// Redondea la hora actual al múltiplo de 2 más cercano hacia abajo.
    private func roundedNowHour(_ hour: Int) -> Int {
        (hour / 2) * 2
    }
}
