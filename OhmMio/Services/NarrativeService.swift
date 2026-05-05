//
//  NarrativeService.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// M2 — Foundation Models (LLM on-device).
/// Genera narrativa contextual en español mexicano a partir de una decisión ya tomada.
///
/// **Reglas críticas (§5.3, §5.5):**
/// - NUNCA recibe números crudos para calcular. Solo narra.
/// - Timeout de 2s. Si excede, devuelve `decision.fallbackText`.
/// - No bloquea el hilo principal.
struct NarrativeService {

    private static let timeoutSeconds: TimeInterval = 2.0

    /// Genera una frase contextual para mostrar en el Dashboard.
    /// Si Foundation Models no está disponible o tarda, devuelve el fallback determinista.
    static func narrate(decision: ActionDecision) async -> String {
        await withTimeoutOrFallback(
            timeout: timeoutSeconds,
            fallback: decision.fallbackText
        ) {
            try await generateNarrative(for: decision)
        }
    }

    // MARK: - Generación

    private static func generateNarrative(for decision: ActionDecision) async throws -> String {
        #if canImport(FoundationModels)
        // Apple Intelligence on-device (iOS 18+).
        if #available(iOS 18.0, *) {
            let session = LanguageModelSession(instructions: systemInstructions())
            let prompt = buildPrompt(for: decision)
            let response = try await session.respond(to: prompt)
            return sanitize(response.content)
        } else {
            return decision.fallbackText
        }
        #else
        return decision.fallbackText
        #endif
    }

    private static func systemInstructions() -> String {
        """
        Eres un asistente conciso para la app OhMio (eficiencia energética en México).
        Habla en español mexicano, cálido y directo. Máximo 2 oraciones, ~30 palabras.
        Sin tecnicismos innecesarios. Sin emojis. No inventes números: usa solo los que recibes.
        """
    }

    private static func buildPrompt(for decision: ActionDecision) -> String {
        let kwh = String(format: "%.1f", decision.estimatedKwhSaved)
        let co2 = String(format: "%.2f", decision.estimatedCO2Saved)
        let mxn = String(format: "%.0f", decision.estimatedMXNSaved)

        let strategyDescription: String = {
            switch decision.strategy {
            case .reduceUrgent:
                return "El usuario está cerca del límite DAC. Recomienda reducir el uso de \(decision.applianceDisplayName) hoy."
            case .postponeForCarbon:
                return "La red eléctrica está sucia ahora. Recomienda posponer el uso de \(decision.applianceDisplayName) a horas de red limpia (10 AM–3 PM)."
            case .takeAdvantage:
                return "La red eléctrica está limpia. Anima al usuario a usar \(decision.applianceDisplayName) ahora si lo necesita."
            case .reduceModerate:
                return "Sugiere un ajuste suave en el uso de \(decision.applianceDisplayName)."
            }
        }()

        return """
        Contexto: \(strategyDescription)
        Ahorro estimado: \(kwh) kWh/día, \(co2) kg CO₂ evitados, ~$\(mxn) MXN al mes.
        Genera la frase para el usuario.
        """
    }

    private static func sanitize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Timeout helper

    private static func withTimeoutOrFallback(
        timeout: TimeInterval,
        fallback: String,
        operation: @escaping () async throws -> String
    ) async -> String {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                do { return try await operation() }
                catch { return nil }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result ?? fallback
        }
    }
}
