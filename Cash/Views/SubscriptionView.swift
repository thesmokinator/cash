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

/// A badge/button that promotes premium features - opens the paywall sheet
struct PremiumPromoBadge: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    
    var body: some View {
        // Don't show if already premium
        if !subscriptionManager.isPremiumEnabled {
            Button {
                showingPaywall = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    Text("Go Premium")
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingPaywall) {
                SubscriptionPaywallView(feature: .iCloudSync)
            }
        }
    }
}

// MARK: - Subscription Settings Tab Content

struct SubscriptionSettingsTabContent: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        // Premium Features Section - ONLY if not subscribed (hide when subscription active or ENABLE_PREMIUM flag is set)
        if !subscriptionManager.isPremiumEnabled {
            Section {
                PremiumFeaturesList(showStatus: false)
            } header: {
                Text("Premium features")
            }
        }
        
        // Status Section
        Section {
            statusView
        } header: {
            Text("Subscription status")
        }
        
        // Products Section - Always show to allow plan changes (Apple handles prorating automatically)
        Section {
            productsView
        } header: {
            Text("Available plans")
        } footer: {
            if subscriptionManager.status.isActive {
                Text("You can switch plans anytime. Apple will automatically prorate your subscription.")
            } else {
                Text("Subscribe to unlock all premium features.")
            }
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
    @State private var animateGradient = false
    
    let feature: PremiumFeature
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.1)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
            
            ScrollView {
                VStack(spacing: 28) {
                    // Header with crown animation
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: .yellow.opacity(0.5), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Unlock Cash Premium")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Get the most out of Cash with powerful premium features")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Features grid
                    VStack(spacing: 0) {
                        ForEach(Array(PremiumFeature.allCases.enumerated()), id: \.element.id) { index, f in
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(featureColor(for: index).opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: f.iconName)
                                        .font(.system(size: 20))
                                        .foregroundStyle(featureColor(for: index))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(f.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            
                            if index < PremiumFeature.allCases.count - 1 {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    // Products
                    if subscriptionManager.isLoadingProducts {
                        ProgressView()
                            .padding()
                    } else {
                        VStack(spacing: 10) {
                            ForEach(subscriptionManager.products, id: \.id) { product in
                                PaywallProductButton(
                                    product: product,
                                    isSelected: selectedProduct == product,
                                    isBestValue: product.id == subscriptionManager.yearlyProduct?.id
                                ) {
                                    selectedProduct = product
                                }
                            }
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 16) {
                        Button {
                            guard let product = selectedProduct else { return }
                            Task {
                                let success = await subscriptionManager.purchase(product)
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            Group {
                                if subscriptionManager.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Continue")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ).opacity(1)
                        )
                        .controlSize(.large)
                        .disabled(selectedProduct == nil || subscriptionManager.isPurchasing)
                        
                        HStack(spacing: 20) {
                            Button("Restore Purchases") {
                                Task {
                                    await subscriptionManager.restorePurchases()
                                    if subscriptionManager.status.isActive {
                                        dismiss()
                                    }
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            
                            Button("Not Now") {
                                dismiss()
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(width: 420, height: 620)
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
                // Auto-select yearly as default (best value)
                selectedProduct = subscriptionManager.yearlyProduct ?? subscriptionManager.products.first
            }
        }
    }
    
    private func featureColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan]
        return colors[index % colors.count]
    }
}

// MARK: - Paywall Product Button

struct PaywallProductButton: View {
    let product: Product
    let isSelected: Bool
    var isBestValue: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 14, height: 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                        
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let subscription = product.subscription {
                        Text(priceDescription(for: product, subscription: subscription))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? .blue : .primary)
                    
                    if let subscription = product.subscription, subscription.subscriptionPeriod.unit == .year {
                        if let monthlyPrice = calculateMonthlyPrice(for: product, subscription: subscription) {
                            Text("\(monthlyPrice)/mo")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.blue : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func priceDescription(for product: Product, subscription: Product.SubscriptionInfo) -> String {
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return String(localized: "Billed monthly")
        case .year:
            return String(localized: "Billed annually • Save 33%")
        default:
            return ""
        }
    }
    
    private func calculateMonthlyPrice(for product: Product, subscription: Product.SubscriptionInfo) -> String? {
        guard subscription.subscriptionPeriod.unit == .year else { return nil }
        let yearlyPrice = product.price
        let monthlyPrice = yearlyPrice / 12
        return monthlyPrice.formatted(.currency(code: product.priceFormatStyle.currencyCode))
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

#Preview("Paywall") {
    SubscriptionPaywallView(feature: .iCloudSync)
}

#Preview("Locked View") {
    PremiumLockedView(feature: .budgeting)
        .frame(width: 500, height: 400)
}
