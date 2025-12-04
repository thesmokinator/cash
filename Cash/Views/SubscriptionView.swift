//
//  SubscriptionView.swift
//  Cash
//
//  Created by Michele Broggi on 04/12/25.
//

import SwiftUI
import StoreKit

// MARK: - Premium Features List (Reusable Component)

/// A reusable view that displays all premium features with their status
struct PremiumFeaturesList: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    var showStatus: Bool = true
    
    var body: some View {
        ForEach(PremiumFeature.allCases) { feature in
            HStack(spacing: 12) {
                Image(systemName: feature.iconName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.displayName)
                        .font(.subheadline)
                    Text(feature.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if showStatus {
                    if subscriptionManager.isFeatureEnabled(feature) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Premium Promo Badge

/// A badge/button that promotes premium features - opens Settings on Subscription tab
struct PremiumPromoBadge: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        // Don't show if already premium
        if !subscriptionManager.isPremiumEnabled {
            Button {
                // Post notification to open Settings and switch to subscription tab
                NotificationCenter.default.post(name: .showSubscriptionTab, object: nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown")
                    Text("Go Premium")
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.quaternary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Premium Features Sheet

/// A sheet that displays all premium features and allows subscription
struct PremiumFeaturesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                        Text("Cash Premium")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Unlock all features")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Features list
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Premium Features")
                            .font(.headline)
                        
                        PremiumFeaturesList(showStatus: false)
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Subscription options
                    if !subscriptionManager.products.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose a plan")
                                .font(.headline)
                            
                            ForEach(subscriptionManager.products, id: \.id) { product in
                                PremiumPlanButton(
                                    product: product,
                                    isSelected: selectedProduct == product
                                ) {
                                    selectedProduct = product
                                }
                            }
                        }
                    } else if subscriptionManager.isLoadingProducts {
                        ProgressView("Loading plans...")
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    guard let product = selectedProduct else { return }
                    Task {
                        let success = await subscriptionManager.purchase(product)
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if subscriptionManager.isPurchasing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Subscribe Now")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedProduct == nil || subscriptionManager.isPurchasing)
                
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.restorePurchases()
                        if subscriptionManager.status.isActive {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
            .padding()
        }
        .frame(width: 450, height: 600)
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
                selectedProduct = subscriptionManager.yearlyProduct ?? subscriptionManager.products.first
            }
        }
    }
}

// MARK: - Premium Plan Button

struct PremiumPlanButton: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .fontWeight(.semibold)
                    if let subscription = product.subscription {
                        Text(billingDescription(for: subscription))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .fontWeight(.bold)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func billingDescription(for subscription: Product.SubscriptionInfo) -> String {
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return String(localized: "Billed monthly")
        case .year:
            return String(localized: "Billed annually - Save 30%!")
        default:
            return ""
        }
    }
}

// MARK: - Subscription Settings Tab Content

struct SubscriptionSettingsTabContent: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        // Premium Features Section - ONLY if not subscribed
        if !subscriptionManager.status.isActive {
            Section {
                PremiumFeaturesList(showStatus: false)
            } header: {
                Text("Premium features")
            }
            
            // Products Section
            Section {
                productsView
            } header: {
                Text("Available plans")
            } footer: {
                Text("Subscribe to unlock all premium features.")
            }
        }
        
        // Status Section
        Section {
            statusView
        } header: {
            Text("Subscription status")
        }
        
        // Actions Section
        Section {
            actionsView
        }
    }
    
    // MARK: - Status View
    
    @ViewBuilder
    private var statusView: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: statusIconName)
                    .font(.system(size: 18))
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(subscriptionManager.status.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            #if ENABLE_PREMIUM
            Text("DEV")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange)
                .clipShape(Capsule())
            #endif
        }
        .padding(.vertical, 4)
    }
    
    private var statusTitle: String {
        #if ENABLE_PREMIUM
        return String(localized: "Premium (Development)")
        #else
        if subscriptionManager.status.isActive {
            return String(localized: "Premium")
        } else {
            return String(localized: "Free")
        }
        #endif
    }
    
    private var statusColor: Color {
        #if ENABLE_PREMIUM
        return .orange
        #else
        return subscriptionManager.status.isActive ? .green : .secondary
        #endif
    }
    
    private var statusIconName: String {
        #if ENABLE_PREMIUM
        return "hammer.fill"
        #else
        return subscriptionManager.status.isActive ? "checkmark.seal.fill" : "seal"
        #endif
    }
    
    // MARK: - Products View
    
    @ViewBuilder
    private var productsView: some View {
        if subscriptionManager.isLoadingProducts {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading plans...")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        } else if subscriptionManager.products.isEmpty {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Unable to load subscription plans. Please try again later.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(subscriptionManager.products, id: \.id) { product in
                ProductRow(product: product)
            }
        }
    }
    
    // MARK: - Actions View
    
    @ViewBuilder
    private var actionsView: some View {
        if subscriptionManager.status.isActive {
            Button {
                Task {
                    await subscriptionManager.manageSubscription()
                }
            } label: {
                Label("Manage subscription", systemImage: "gear")
            }
        }
        
        Button {
            Task {
                await subscriptionManager.restorePurchases()
            }
        } label: {
            Label("Restore purchases", systemImage: "arrow.clockwise")
        }
    }
}

// MARK: - Subscription Settings Tab (Legacy)

struct SubscriptionSettingsTab: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // Premium Features Section - ONLY if not subscribed
                if !subscriptionManager.status.isActive {
                    Section {
                        PremiumFeaturesList(showStatus: false)
                    } header: {
                        Text("Premium features")
                    }
                    
                    // Products Section
                    Section {
                        productsView
                    } header: {
                        Text("Available plans")
                    } footer: {
                        Text("Subscribe to unlock all premium features.")
                    }
                }
                
                // Status Section
                Section {
                    statusView
                } header: {
                    Text("Subscription status")
                }
                
                // Actions Section
                Section {
                    actionsView
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Subscription")
        }
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
                await subscriptionManager.updateSubscriptionStatus()
            }
        }
        .alert("Error", isPresented: .constant(subscriptionManager.errorMessage != nil)) {
            Button("OK") {
                // Clear error handled by manager
            }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
    }
    
    // MARK: - Status View
    
    @ViewBuilder
    private var statusView: some View {
        HStack {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(subscriptionManager.status.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            #if ENABLE_PREMIUM
            Text("DEV")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange)
                .clipShape(Capsule())
            #endif
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 40, height: 40)
            
            Image(systemName: statusIconName)
                .font(.system(size: 18))
                .foregroundStyle(statusColor)
        }
    }
    
    private var statusTitle: String {
        #if ENABLE_PREMIUM
        return String(localized: "Premium (Development)")
        #else
        if subscriptionManager.status.isActive {
            return String(localized: "Premium")
        } else {
            return String(localized: "Free")
        }
        #endif
    }
    
    private var statusColor: Color {
        #if ENABLE_PREMIUM
        return .orange
        #else
        return subscriptionManager.status.isActive ? .green : .secondary
        #endif
    }
    
    private var statusIconName: String {
        #if ENABLE_PREMIUM
        return "hammer.fill"
        #else
        return subscriptionManager.status.isActive ? "checkmark.seal.fill" : "seal"
        #endif
    }
    
    // MARK: - Products View
    
    @ViewBuilder
    private var productsView: some View {
        if subscriptionManager.isLoadingProducts {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading plans...")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        } else if subscriptionManager.products.isEmpty {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Unable to load subscription plans. Please try again later.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(subscriptionManager.products, id: \.id) { product in
                ProductRow(product: product)
            }
        }
    }
    
    // MARK: - Features View
    
    // MARK: - Actions View
    
    @ViewBuilder
    private var actionsView: some View {
        if subscriptionManager.status.isActive {
            Button {
                Task {
                    await subscriptionManager.manageSubscription()
                }
            } label: {
                Label("Manage subscription", systemImage: "gear")
            }
        }
        
        Button {
            Task {
                await subscriptionManager.restorePurchases()
            }
        } label: {
            Label("Restore purchases", systemImage: "arrow.clockwise")
        }
    }
}

// MARK: - Product Row

struct ProductRow: View {
    let product: Product
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let subscription = product.subscription {
                    Text(priceDescription(for: product, subscription: subscription))
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            Button {
                Task {
                    isPurchasing = true
                    _ = await subscriptionManager.purchase(product)
                    isPurchasing = false
                }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 80)
                } else {
                    Text("Subscribe")
                        .frame(width: 80)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing || subscriptionManager.isPurchasing)
        }
        .padding(.vertical, 8)
    }
    
    private func priceDescription(for product: Product, subscription: Product.SubscriptionInfo) -> String {
        let price = product.displayPrice
        
        switch subscription.subscriptionPeriod.unit {
        case .month:
            if subscription.subscriptionPeriod.value == 1 {
                return String(localized: "\(price)/month")
            } else {
                return String(localized: "\(price) every \(subscription.subscriptionPeriod.value) months")
            }
        case .year:
            if subscription.subscriptionPeriod.value == 1 {
                return String(localized: "\(price)/year")
            } else {
                return String(localized: "\(price) every \(subscription.subscriptionPeriod.value) years")
            }
        case .week:
            return String(localized: "\(price)/week")
        case .day:
            return String(localized: "\(price)/day")
        @unknown default:
            return price
        }
    }
}

// MARK: - Subscription Paywall View

/// A paywall view that can be shown when user tries to access premium features
struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    
    let feature: PremiumFeature
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                
                Text("Unlock Premium")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Subscribe to Cash Premium to unlock \(feature.displayName) and other premium features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(PremiumFeature.allCases) { f in
                    HStack(spacing: 12) {
                        Image(systemName: f.iconName)
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(f.displayName)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Products
            if subscriptionManager.isLoadingProducts {
                ProgressView()
            } else {
                VStack(spacing: 8) {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        PaywallProductButton(product: product, isSelected: selectedProduct == product) {
                            selectedProduct = product
                        }
                    }
                }
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    guard let product = selectedProduct else { return }
                    Task {
                        let success = await subscriptionManager.purchase(product)
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if subscriptionManager.isPurchasing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Subscribe Now")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedProduct == nil || subscriptionManager.isPurchasing)
                
                HStack(spacing: 16) {
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.status.isActive {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(30)
        .frame(width: 400, height: 550)
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
                // Auto-select yearly as default
                selectedProduct = subscriptionManager.yearlyProduct ?? subscriptionManager.products.first
            }
        }
    }
}

// MARK: - Paywall Product Button

struct PaywallProductButton: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .fontWeight(.semibold)
                    if let subscription = product.subscription {
                        Text(priceDescription(for: product, subscription: subscription))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .fontWeight(.bold)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func priceDescription(for product: Product, subscription: Product.SubscriptionInfo) -> String {
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return String(localized: "Billed monthly")
        case .year:
            return String(localized: "Billed annually")
        default:
            return ""
        }
    }
}

// MARK: - Premium Feature Guard

/// A view modifier that shows a paywall when accessing premium features
struct PremiumFeatureGuard: ViewModifier {
    let feature: PremiumFeature
    @State private var showingPaywall = false
    @State private var subscriptionManager = SubscriptionManager.shared
    
    func body(content: Content) -> some View {
        Group {
            if subscriptionManager.isFeatureEnabled(feature) {
                content
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    content
                }
                .sheet(isPresented: $showingPaywall) {
                    SubscriptionPaywallView(feature: feature)
                }
            }
        }
    }
}

extension View {
    /// Guards content behind a premium feature paywall
    func requiresPremium(_ feature: PremiumFeature) -> some View {
        modifier(PremiumFeatureGuard(feature: feature))
    }
}

// MARK: - Premium Locked View

/// A view that shows a lock screen for premium features
struct PremiumLockedView: View {
    let feature: PremiumFeature
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Premium Feature")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(feature.displayName)
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingPaywall = true
            } label: {
                Label("Unlock with Premium", systemImage: "crown.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView(feature: feature)
        }
    }
}

// MARK: - Premium Content Wrapper

/// Wraps content and shows a lock screen if the feature is not available
struct PremiumContentWrapper<Content: View>: View {
    let feature: PremiumFeature
    @ViewBuilder let content: () -> Content
    @State private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        if subscriptionManager.isFeatureEnabled(feature) {
            content()
        } else {
            PremiumLockedView(feature: feature)
        }
    }
}

#Preview("Subscription Settings") {
    SubscriptionSettingsTab()
        .frame(width: 500, height: 400)
}

#Preview("Paywall") {
    SubscriptionPaywallView(feature: .iCloudSync)
}

#Preview("Locked View") {
    PremiumLockedView(feature: .budgeting)
        .frame(width: 500, height: 400)
}
