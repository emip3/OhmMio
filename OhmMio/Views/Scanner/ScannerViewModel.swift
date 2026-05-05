import SwiftUI

@MainActor
@Observable
final class ScannerViewModel {
    enum State {
        case idle
        case processing
        case confirm(ReceiptParser.ParsedReceipt)
        case success
        case error(String)
    }

    var state: State = .idle
    private let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
    }

    func processImage(_ image: UIImage) async {
        state = .processing
        do {
            let lines = try await ReceiptScanner.scan(image: image)
            let parsed = ReceiptParser.parse(lines)
            state = .confirm(parsed)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func saveReceipt(parsed: ReceiptParser.ParsedReceipt) {
        do {
            let user = try storage.loadOrCreateUser()
            let receipt = Receipt(
                kwhConsumed: parsed.kwhConsumed ?? 0,
                tariffCode: parsed.tariffCode ?? "",
                billingPeriodStart: parsed.billingPeriodStart ?? Date().addingTimeInterval(-60*24*60*60),
                billingPeriodEnd: parsed.billingPeriodEnd ?? Date(),
                totalAmountMXN: parsed.totalAmountMXN ?? 0,
                twelveMonthAverage: parsed.twelveMonthAverage,
                source: .scanned,
                owner: user
            )
            user.receiptHistory.append(receipt)
            storage.insert(receipt)
            try storage.save()
            state = .success
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
