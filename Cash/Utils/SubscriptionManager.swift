//
//  SubscriptionManager.swift
//  Cash
//
//  Created by Michele Broggi on 04/12/25.
//

import Foundation
import StoreKit
import AppKit

// Typealias to disambiguate from SwiftData Transaction
typealias StoreTransaction = StoreKit.Transaction

// MARK: - Premium Features

/// Defines all premium features available through subscription
enum PremiumFeature: String, CaseIterable, Identifiable {
    case iCloudSync = "icloud_sync"
    case budgeting = "budgeting"
    case reports = "reports"
    case loans = "loans"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .iCloudSync:
            return String(localized: "iCloud Sync")
        case .budgeting:
            return String(localized: "Budgeting")
        case .reports:
            return String(localized: "Advanced Reports")
        case .loans:
            return String(localized: "Loans & Mortgages")
        }
    }
    
    var description: String {
        switch self {
        case .iCloudSync:
            return String(localized: "Sync your data across all your Apple devices using iCloud.")
        case .budgeting:
            return String(localized: "Create and manage budgets to track your spending.")
        case .reports:
            return String(localized: "Advanced reports and analytics for your finances.")
        case .loans:
            return String(localized: "Loan calculators, amortization schedules, and mortgage tools.")
        }
    }
    
    var iconName: String {
        switch self {
        case .iCloudSync:
            return "icloud.fill"
        case .budgeting:
            return "chart.pie.fill"
        case .reports:
            return "chart.bar.doc.horizontal.fill"
        case .loans:
            return "house.fill"
        }
    }
}

// MARK: - Subscription Product

/// Available subscription products
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.thesmokinator.cash.premium.monthly"
    case yearly = "com.thesmokinator.cash.premium.yearly"
    
    var id: String { rawValue }
}

// MARK: - Subscription Status

enum SubscriptionStatus: Equatable {
    case unknown
    case notSubscribed
    case subscribed(expirationDate: Date?, willRenew: Bool)
    case expired
    case inGracePeriod(expirationDate: Date)
    case inBillingRetry
    case revoked
    
    var isActive: Bool {
        switch self {
        case .subscribed, .inGracePeriod, .inBillingRetry:
            return true
        default:
            return false
        }
    }
    
    var displayText: String {
        switch self {
        case .unknown:
            return String(localized: "Checking subscription status...")
        case .notSubscribed:
            return String(localized: "Not subscribed")
        case .subscribed(let expiration, let willRenew):
            if let date = expiration {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let dateStr = formatter.string(from: date)
                if willRenew {
                    return String(localized: "Subscribed - Renews \(dateStr)")
                } else {
                    return String(localized: "Subscribed - Expires \(dateStr)")
                }
            }
            return String(localized: "Subscribed")
        case .expired:
            return String(localized: "Subscription expired")
        case .inGracePeriod(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return String(localized: "Grace period until \(formatter.string(from: date))")
        case .inBillingRetry:
            return String(localized: "Billing issue - Please update payment method")
        case .revoked:
            return String(localized: "Subscription revoked")
        }
    }
}

// MARK: - Subscription Manager

@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()
    
    // MARK: - Properties
    
    /// Current subscription status
    private(set) var status: SubscriptionStatus = .unknown
    
    /// Available products for purchase
    private(set) var products: [Product] = []
    
    /// Whether products are being loaded
    private(set) var isLoadingProducts: Bool = false
    
    /// Whether a purchase is in progress
    private(set) var isPurchasing: Bool = false
    
    /// Last error message
    private(set) var errorMessage: String?
    
    /// Transaction update listener task
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Computed Properties
    
    /// Check if premium features are enabled (either via subscription or compile flag)
    var isPremiumEnabled: Bool {
        #if ENABLE_PREMIUM
        return true
        #else
        return status.isActive
        #endif
    }
    
    /// Check if a specific feature is available
    func isFeatureEnabled(_ feature: PremiumFeature) -> Bool {
        #if ENABLE_PREMIUM
        return true
        #else
        return status.isActive
        #endif
    }
    
    /// Get monthly product if available
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthly.id }
    }
    
    /// Get yearly product if available
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.yearly.id }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check status on init
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    /// Load available products from App Store
    @MainActor
    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        
        do {
            let productIds = SubscriptionProduct.allCases.map { $0.id }
            products = try await Product.products(for: productIds)
            
            // Sort products: monthly first, then yearly
            products.sort { p1, p2 in
                if p1.id == SubscriptionProduct.monthly.id { return true }
                if p2.id == SubscriptionProduct.monthly.id { return false }
                return p1.id < p2.id
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load products: \(error)")
        }
        
        isLoadingProducts = false
    }
    
    // MARK: - Purchase
    
    /// Purchase a subscription product
    @MainActor
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                let transaction = try checkVerified(verification)
                
                // Update subscription status
                await updateSubscriptionStatus()
                
                // Finish the transaction
                await transaction.finish()
                
                isPurchasing = false
                return true
                
            case .userCancelled:
                isPurchasing = false
                return false
                
            case .pending:
                // Transaction is pending (e.g., parental approval)
                isPurchasing = false
                return false
                
            @unknown default:
                isPurchasing = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Purchase failed: \(error)")
            isPurchasing = false
            return false
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases
    @MainActor
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = error.localizedDescription
            print("Restore failed: \(error)")
        }
    }
    
    // MARK: - Subscription Status
    
    /// Update the current subscription status
    @MainActor
    func updateSubscriptionStatus() async {
        // Check for active subscription
        for await result in StoreTransaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if this is one of our subscription products
                guard SubscriptionProduct.allCases.map({ $0.id }).contains(transaction.productID) else {
                    continue
                }
                
                // Check subscription status
                if let subscriptionStatus = await transaction.subscriptionStatus {
                    switch subscriptionStatus.state {
                    case .subscribed:
                        var willRenew = false
                        if case .verified(let renewalInfo) = subscriptionStatus.renewalInfo {
                            willRenew = renewalInfo.willAutoRenew
                        }
                        status = .subscribed(
                            expirationDate: transaction.expirationDate,
                            willRenew: willRenew
                        )
                        return
                        
                    case .inGracePeriod:
                        status = .inGracePeriod(expirationDate: transaction.expirationDate ?? Date())
                        return
                        
                    case .inBillingRetryPeriod:
                        status = .inBillingRetry
                        return
                        
                    case .expired:
                        status = .expired
                        return
                        
                    case .revoked:
                        status = .revoked
                        return
                        
                    default:
                        break
                    }
                } else {
                    // No subscription status but has entitlement - treat as active
                    status = .subscribed(expirationDate: transaction.expirationDate, willRenew: false)
                    return
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        // No active subscription found
        status = .notSubscribed
    }
    
    // MARK: - Transaction Listening
    
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in StoreTransaction.updates {
                guard let self else { continue }
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    /// Verify a transaction
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Manage Subscription
    
    /// Open the App Store subscription management page
    @MainActor
    func manageSubscription() async {
        // On macOS, open the App Store subscriptions page directly
        if let url = URL(string: "macappstores://apps.apple.com/account/subscriptions") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - StoreKit Extensions

extension StoreTransaction {
    /// Get subscription status for this transaction
    var subscriptionStatus: Product.SubscriptionInfo.Status? {
        get async {
            guard let statuses = try? await Product.SubscriptionInfo.status(for: productID) else {
                return nil
            }
            return statuses.first
        }
    }
}

extension Product.SubscriptionInfo.Status {
    /// Whether the subscription will auto-renew
    var willAutoRenew: Bool {
        guard case .verified(let renewalInfo) = renewalInfo else {
            return false
        }
        return renewalInfo.willAutoRenew
    }
}
