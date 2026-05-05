//
//  ReceiptScanner.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import Vision
import UIKit

/// M1 — Vision OCR.
/// Modelo puro: recibe UIImage, devuelve líneas de texto reconocidas.
/// El parsing semántico vive en `ReceiptParser`.
struct ReceiptScanner {

    enum ScanError: Error, LocalizedError {
        case invalidImage
        case visionFailure(Error)
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .invalidImage:        return "No pudimos leer la imagen del recibo."
            case .visionFailure(let e): return "Error al procesar: \(e.localizedDescription)"
            case .noTextFound:         return "No encontramos texto en la imagen."
            }
        }
    }

    static func scan(image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw ScanError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ScanError.visionFailure(error))
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ScanError.noTextFound)
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                if lines.isEmpty {
                    continuation.resume(throwing: ScanError.noTextFound)
                } else {
                    continuation.resume(returning: lines)
                }
            }

            request.recognitionLanguages = ["es-MX", "es"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ScanError.visionFailure(error))
            }
        }
    }
}

// MARK: - ReceiptParser

/// Aplica regex sobre las líneas reconocidas para extraer datos del recibo CFE.
/// Si algún campo no se encuentra, devuelve nil para que la UI permita edición manual.
struct ReceiptParser {

    struct ParsedReceipt {
        var kwhConsumed: Int?
        var tariffCode: String?
        var totalAmountMXN: Double?
        var billingPeriodStart: Date?
        var billingPeriodEnd: Date?
        var twelveMonthAverage: Double?
    }

    static func parse(_ lines: [String]) -> ParsedReceipt {
        let joined = lines.joined(separator: "\n")
        var result = ParsedReceipt()

        result.kwhConsumed = extractKwh(from: joined)
        result.tariffCode = extractTariff(from: joined)
        result.totalAmountMXN = extractTotalAmount(from: joined)
        result.twelveMonthAverage = extractTwelveMonthAverage(from: joined)
        let (start, end) = extractBillingPeriod(from: joined)
        result.billingPeriodStart = start
        result.billingPeriodEnd = end

        return result
    }

    // MARK: - Extractores

    private static func extractKwh(from text: String) -> Int? {
        // Patrones típicos: "123 kWh", "Consumo: 123", "TOTAL kWh 123"
        let patterns = [
            #"(\d{1,4})\s*kWh"#,
            #"[Cc]onsumo[^\d]{0,20}(\d{1,4})"#,
            #"TOTAL\s+kWh\s+(\d{1,4})"#
        ]
        for pattern in patterns {
            if let value = firstMatch(in: text, pattern: pattern), let int = Int(value) {
                return int
            }
        }
        return nil
    }

    private static func extractTariff(from text: String) -> String? {
        let pattern = #"[Tt]arifa\s*:?\s*(1[A-F]?|DAC)"#
        return firstMatch(in: text, pattern: pattern)?.uppercased()
    }

    private static func extractTotalAmount(from text: String) -> Double? {
        // "$1,234.56" o "Total a pagar: 1234.56"
        let patterns = [
            #"[Tt]otal\s*[a-zA-Z\s]*[:\$]\s*([\d,]+\.\d{2})"#,
            #"\$\s*([\d,]+\.\d{2})"#
        ]
        for pattern in patterns {
            if let raw = firstMatch(in: text, pattern: pattern) {
                let cleaned = raw.replacingOccurrences(of: ",", with: "")
                if let value = Double(cleaned) { return value }
            }
        }
        return nil
    }

    private static func extractTwelveMonthAverage(from text: String) -> Double? {
        let pattern = #"[Pp]romedio[^\d]{0,30}(\d{2,4}(?:\.\d+)?)"#
        if let raw = firstMatch(in: text, pattern: pattern) {
            return Double(raw)
        }
        return nil
    }

    private static func extractBillingPeriod(from text: String) -> (Date?, Date?) {
        // Formato típico: "DEL 01/MAR/2026 AL 30/ABR/2026"
        let pattern = #"DEL\s+(\d{2}/[A-Z]{3}/\d{4})\s+AL\s+(\d{2}/[A-Z]{3}/\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let r1 = Range(match.range(at: 1), in: text),
              let r2 = Range(match.range(at: 2), in: text)
        else {
            return (nil, nil)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MMM/yyyy"
        formatter.locale = Locale(identifier: "es_MX")
        return (formatter.date(from: String(text[r1])), formatter.date(from: String(text[r2])))
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
