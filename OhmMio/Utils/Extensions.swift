//
//  Extensions.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import SwiftUI

// MARK: - Double

extension Double {

    /// Versión formateada como kWh.
    /// Ej: 3.7.formattedKwh → "3.7 kWh"
    var formattedKwh: String {
        Formatters.formatKwh(self)
    }

    /// Versión formateada como kg CO₂.
    /// Ej: 0.42.formattedCO2 → "0.42 kg CO₂"
    var formattedCO2: String {
        Formatters.formatCO2(self)
    }

    /// Versión formateada como pesos mexicanos.
    /// Ej: 890.50.formattedMXN → "$890.50"
    var formattedMXN: String {
        Formatters.mxn.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    /// Versión formateada como pesos sin decimales.
    /// Ej: 890.50.formattedMXNRounded → "$891"
    var formattedMXNRounded: String {
        Formatters.mxnRounded.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }

    /// Restringe el valor a un rango.
    /// Útil para progresos de anillos, barras, etc.
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Int

extension Int {

    /// Versión formateada como kWh con separadores de miles.
    /// Ej: 1247.formattedKwh → "1,247 kWh"
    var formattedKwh: String {
        Double(self).formattedKwh
    }
}

// MARK: - Date

extension Date {

    /// Ej: "5 may 2026"
    var formattedShort: String {
        Formatters.shortDate.string(from: self)
    }

    /// Ej: "Martes"
    var weekdayName: String {
        Formatters.weekday.string(from: self).capitalized
    }

    /// Ej: "14:00"
    var formattedHour: String {
        Formatters.hour.string(from: self)
    }

    /// Hora del día (0-23) según calendario actual.
    var hourOfDay: Int {
        Calendar.current.component(.hour, from: self)
    }

    /// True si la fecha cae en sábado o domingo.
    var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: self)
        return weekday == 1 || weekday == 7
    }

    /// True si la fecha está en temporada cálida en México (mayo–octubre).
    /// Coincide con la lógica de `CarbonIntensityService`.
    var isSummerInMexico: Bool {
        let month = Calendar.current.component(.month, from: self)
        return (5...10).contains(month)
    }
}

// MARK: - String

extension String {

    /// Recorta espacios y saltos de línea.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True si la cadena (después de recortar) está vacía.
    var isBlank: Bool {
        trimmed.isEmpty
    }
}

// MARK: - Color

extension Color {

    /// Devuelve el color con opacidad ajustada (alias semántico).
    /// Útil para fondos suaves de chips.
    func soft(_ alpha: Double = 0.15) -> Color {
        opacity(alpha)
    }
}

// MARK: - View

extension View {

    /// Aplica un modificador de forma condicional.
    /// Útil para evitar bloques `if` anidados en cadenas de modificadores.
    ///
    /// ```swift
    /// Text("Hola")
    ///     .if(isHighlighted) { $0.bold() }
    /// ```
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Estilo estándar de tarjeta usado en toda la app:
    /// fondo `secondarySystemBackground` con esquinas redondeadas a 16pt.
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Aplica el fondo atmosférico de la app según riesgo (§6 del PRD).
    func atmosphericBackground(for risk: DACMargin.RiskLevel) -> some View {
        background(DesignTokens.atmosphericBackground(for: risk).ignoresSafeArea())
    }

    /// Ancho lleno común para botones primarios.
    func fillWidth() -> some View {
        frame(maxWidth: .infinity)
    }
}

// MARK: - Binding

extension Binding {

    /// Permite usar un `Binding` opcional con un valor por defecto.
    ///
    /// ```swift
    /// TextField("Nombre", text: $user.name ?? "")
    /// ```
    static func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> where Value == T {
        Binding<T>(
            get: { lhs.wrappedValue ?? rhs },
            set: { lhs.wrappedValue = $0 }
        )
    }
}

// MARK: - Array

extension Array {

    /// Elimina duplicados según un keyPath hashable.
    /// Útil para combinar historiales de recibos sin repetir.
    ///
    /// ```swift
    /// receipts.uniqued(by: \.id)
    /// ```
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

// MARK: - Collection

extension Collection {

    /// Acceso seguro por índice. Devuelve nil si el índice está fuera de rango.
    /// Evita crashes al acceder a arrays opcionales.
    ///
    /// ```swift
    /// let first = matrix[safe: 0]
    /// ```
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Keyboard dismissal

extension View {

    /// Cierra el teclado activo en toda la app.
    /// Útil para botones "Listo" o gestos de tap.
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// Agrega un tap gesture en el fondo que cierra el teclado.
    /// Útil cuando el usuario toca fuera de un TextField.
    ///
    /// ```swift
    /// Form { ... }
    ///     .dismissKeyboardOnTap()
    /// ```
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}
