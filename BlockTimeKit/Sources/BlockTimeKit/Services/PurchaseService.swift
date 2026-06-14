//
//  PurchaseService.swift
//  Block-Time
//
//  Manages the 30-day free trial and one-time Pro unlock via StoreKit 2.
//

import Foundation
import StoreKit

@Observable
@MainActor
public final class PurchaseService {

    public static let shared = PurchaseService()

    // MARK: - Constants

    private let productID = "com.thezoolab.blocktime.pro"
    private let installDateKey = "installDate"
    private let isProKey = "isPro"
    private let trialDuration: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    // MARK: - Observable State

    public var isPro: Bool = false
    public var isTestFlight: Bool = false
    public var products: [Product] = []
    public var isLoading: Bool = false
    public var purchaseError: String?
    public var showRestoreNotFoundAlert: Bool = false

    // MARK: - Trial

    public var trialDaysRemaining: Int {
        guard let installDate = UserDefaults.standard.object(forKey: installDateKey) as? Date else {
            return 30
        }
        let elapsed = Date().timeIntervalSince(installDate)
        let remaining = trialDuration - elapsed
        return max(0, Int(remaining / (24 * 60 * 60)))
    }

    public var isTrialActive: Bool {
        trialDaysRemaining > 0
    }

    /// True if the user can access all features (Pro purchase, active trial, or TestFlight).
    public var hasAccess: Bool {
        isPro || isTrialActive || isTestFlight
    }

    /// True if the user can add new flights (same condition — gated separately from app access).
    public var canAddFlight: Bool {
        isPro || isTrialActive || isTestFlight
    }

    // MARK: - Init

    private init() {
        // Record install date on first launch — never overwrite
        if UserDefaults.standard.object(forKey: installDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: installDateKey)
        }
        isPro = UserDefaults.standard.bool(forKey: isProKey)

        // Detect TestFlight via AppTransaction environment (StoreKit 2)
        Task { @MainActor in
            if case .verified(let tx) = try? await AppTransaction.shared {
                isTestFlight = tx.environment == .xcode || tx.environment == .sandbox
            }
        }
    }

    /// Starts listening for incoming transactions (promo codes, deferred purchases).
    /// Call once at app launch and keep the Task alive for the app's lifetime.
    public func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                markAsPro()
                await transaction.finish()
            }
        }
    }

    // MARK: - StoreKit

    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [productID])
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    public func purchase() async {
        guard let product = products.first else { return }
        isLoading = true
        defer { isLoading = false }
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(_) = verification {
                    markAsPro()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    public func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        purchaseError = nil
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                markAsPro()
                found = true
            }
        }
        if !found {
            showRestoreNotFoundAlert = true
        }
    }

    // MARK: - Private

    private func markAsPro() {
        isPro = true
        UserDefaults.standard.set(true, forKey: isProKey)
    }

    // MARK: - Debug

    #if DEBUG
    /// Simulates a trial with the given days remaining (0 = expired, 1–30 = active).
    public func resetTrialForTesting(daysRemaining: Int = 0) {
        let elapsed = trialDuration - Double(daysRemaining) * 24 * 60 * 60
        // Subtract 30s buffer so Int() truncation doesn't floor to daysRemaining - 1
        let installDate = Date().addingTimeInterval(-elapsed + 30)
        UserDefaults.standard.set(installDate, forKey: installDateKey)
        isPro = false
        UserDefaults.standard.set(false, forKey: isProKey)
    }

    /// Resets to a fresh install state (full 30-day trial, not Pro).
    public func resetToFreshInstall() {
        UserDefaults.standard.removeObject(forKey: installDateKey)
        UserDefaults.standard.removeObject(forKey: isProKey)
        isPro = false
    }

    /// Grants Pro access without going through a purchase.
    public func grantProForTesting() {
        markAsPro()
    }
    #endif
}
