//
//  TipJarStore.swift
//  StartLine
//
//  任意のチップ購入だけを扱うStoreKit 2モデル。
//  チップは機能や利用権を解放しない消費型商品とする。
//

import Combine
import StoreKit

enum TipJarPurchaseState: Equatable {
    case idle
    case purchasing
    case pending
    case succeeded
    case failed
}

@MainActor
final class TipJarStore: ObservableObject {
    static let smallCoffeeProductID = "io.github.inadaman.StartLine.tip.smallCoffee"

    @Published private(set) var displayPrice: String?
    @Published private(set) var isLoading = true
    @Published private(set) var purchaseState: TipJarPurchaseState = .idle

    private var product: Product?
    private var transactionUpdatesTask: Task<Void, Never>?
#if STARTLINE_AUTOMATION
    private var automationProductLoadCount = 0
#endif

    init(observeTransactions: Bool = true) {
        guard observeTransactions else {
            return
        }

        transactionUpdatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var purchaseButtonTitle: String? {
        displayPrice.map { "Small Coffee  \($0)" }
    }

    var statusMessage: String? {
        switch purchaseState {
        case .idle, .purchasing:
            nil
        case .pending:
            "Purchase pending approval."
        case .succeeded:
            "Thank you for supporting StartLine."
        case .failed:
            "The purchase couldn’t be completed. Please try again."
        }
    }

    func loadProduct(forceReload: Bool = false) async {
        guard forceReload || displayPrice == nil else {
            return
        }

#if STARTLINE_AUTOMATION
        let automationConfiguration = TipJarAutomationConfiguration.current
        let shouldSimulateUnavailable = automationConfiguration.isProductUnavailable
            || (automationConfiguration.isProductUnavailableOnce && automationProductLoadCount == 0)
        automationProductLoadCount += 1

        if shouldSimulateUnavailable {
            displayPrice = nil
            isLoading = false
            return
        }

        if let testPrice = automationConfiguration.displayPrice {
            displayPrice = testPrice
            isLoading = false
            return
        }
#endif

        isLoading = true
        defer { isLoading = false }

        do {
            product = try await Product.products(for: [Self.smallCoffeeProductID]).first
            displayPrice = product?.displayPrice
        } catch {
            product = nil
            displayPrice = nil
        }
    }

    func purchase() async {
        guard purchaseState != .purchasing else {
            return
        }

        purchaseState = .purchasing

#if STARTLINE_AUTOMATION
        if let testResult = TipJarAutomationConfiguration.current.purchaseResult {
            purchaseState = testResult.purchaseState
            return
        }
#endif

        guard let product else {
            purchaseState = .failed
            return
        }

        do {
            switch try await product.purchase() {
            case .success(let verificationResult):
                guard case .verified(let transaction) = verificationResult else {
                    purchaseState = .failed
                    return
                }

                await transaction.finish()
                purchaseState = .succeeded
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .failed
            }
        } catch {
            purchaseState = .failed
        }
    }

    private func observeTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            guard
                case .verified(let transaction) = verificationResult,
                transaction.productID == Self.smallCoffeeProductID
            else {
                continue
            }

            await transaction.finish()
            purchaseState = .succeeded
        }
    }
}

#if STARTLINE_AUTOMATION
private struct TipJarAutomationConfiguration {
    enum PurchaseResult: String {
        case success
        case pending
        case failure
        case cancelled

        var purchaseState: TipJarPurchaseState {
            switch self {
            case .success:
                .succeeded
            case .pending:
                .pending
            case .failure:
                .failed
            case .cancelled:
                .idle
            }
        }
    }

    let displayPrice: String?
    let purchaseResult: PurchaseResult?
    let isProductUnavailable: Bool
    let isProductUnavailableOnce: Bool

    static var current: TipJarAutomationConfiguration {
        let arguments = ProcessInfo.processInfo.arguments

        return TipJarAutomationConfiguration(
            displayPrice: value(after: "-startline-tip-test-price", in: arguments),
            purchaseResult: value(after: "-startline-tip-test-result", in: arguments)
                .flatMap(PurchaseResult.init(rawValue:)),
            isProductUnavailable: arguments.contains("-startline-tip-test-unavailable"),
            isProductUnavailableOnce: arguments.contains("-startline-tip-test-unavailable-once")
        )
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard
            let keyIndex = arguments.firstIndex(of: key),
            arguments.indices.contains(keyIndex + 1)
        else {
            return nil
        }

        return arguments[keyIndex + 1]
    }
}
#endif
