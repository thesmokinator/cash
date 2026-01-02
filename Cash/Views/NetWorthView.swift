//
//  NetWorthView.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import SwiftUI
import SwiftData

struct NetWorthByCurrency {
    let currency: String
    let assets: Decimal
    let liabilities: Decimal
    
    var netWorth: Decimal {
        assets - liabilities
    }
}

struct NetWorthView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    private var assetAccounts: [Account] {
        accounts.filter { $0.accountClass == .asset && $0.isActive && !$0.isSystem }
    }
    
    private var liabilityAccounts: [Account] {
        accounts.filter { $0.accountClass == .liability && $0.isActive && !$0.isSystem }
    }
    
    // Group accounts by currency
    private var currencies: [String] {
        let allCurrencies = Set(assetAccounts.map { $0.currency } + liabilityAccounts.map { $0.currency })
        return allCurrencies.sorted()
    }
    
    private var netWorthByCurrency: [NetWorthByCurrency] {
        currencies.map { currency in
            let assets = assetAccounts
                .filter { $0.currency == currency }
                .reduce(0) { $0 + $1.balance }
            let liabilities = liabilityAccounts
                .filter { $0.currency == currency }
                .reduce(0) { $0 + $1.balance }
            return NetWorthByCurrency(currency: currency, assets: assets, liabilities: liabilities)
        }
    }
    
    private func assetAccounts(for currency: String) -> [Account] {
        assetAccounts.filter { $0.currency == currency }
    }
    
    private func liabilityAccounts(for currency: String) -> [Account] {
        liabilityAccounts.filter { $0.currency == currency }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: CashSpacing.xl) {
                // Net Worth Cards - One per currency
                if netWorthByCurrency.isEmpty {
                    GlassEmptyState(
                        icon: "building.columns",
                        title: "No Accounts",
                        description: "Create accounts to see your net worth."
                    )
                } else if netWorthByCurrency.count == 1 {
                    // Single currency - show traditional layout
                    let data = netWorthByCurrency[0]

                    VStack(spacing: CashSpacing.md) {
                        HStack {
                            Text("Net Worth")
                                .font(CashTypography.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)

                        PrivacyAmountView(
                            amount: CurrencyFormatter.format(data.netWorth, currency: data.currency),
                            isPrivate: settings.privacyMode,
                            font: CashTypography.amountLarge,
                            color: data.netWorth >= 0 ? CashColors.primary : CashColors.error
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CashSpacing.xl)
                    .glassBackground()
                    
                    // Summary Cards
                    HStack(spacing: CashSpacing.md) {
                        GlassMetricCard(
                            title: "Assets",
                            value: CurrencyFormatter.format(data.assets, currency: data.currency),
                            icon: "arrow.up.circle.fill",
                            valueColor: CashColors.success,
                            iconColor: CashColors.success,
                            isPrivate: settings.privacyMode
                        )

                        GlassMetricCard(
                            title: "Liabilities",
                            value: CurrencyFormatter.format(data.liabilities, currency: data.currency),
                            icon: "arrow.down.circle.fill",
                            valueColor: CashColors.error,
                            iconColor: CashColors.error,
                            isPrivate: settings.privacyMode
                        )
                    }
                } else {
                    // Multiple currencies - show grouped by currency
                    GlassCard(padding: CashSpacing.lg) {
                        VStack(alignment: .leading, spacing: CashSpacing.lg) {
                            Text("Net Worth")
                                .font(CashTypography.title2)

                            VStack(spacing: CashSpacing.md) {
                                ForEach(netWorthByCurrency, id: \.currency) { data in
                                    CurrencyNetWorthCard(
                                        data: data,
                                        privacyMode: settings.privacyMode
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Assets Section - grouped by currency and type
                if !assetAccounts.isEmpty {
                    ForEach(currencies, id: \.self) { currency in
                        let currencyAssets = assetAccounts(for: currency)
                        if !currencyAssets.isEmpty {
                            GlassCard(padding: CashSpacing.lg) {
                                VStack(alignment: .leading, spacing: CashSpacing.md) {
                                    HStack {
                                        Text("Assets")
                                            .font(CashTypography.title2)

                                        if netWorthByCurrency.count > 1 {
                                            Text("(\(CurrencyList.symbol(forCode: currency)))")
                                                .font(CashTypography.headline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    // Group by account type
                                    let groupedAssets = Dictionary(grouping: currencyAssets) { $0.accountType }
                                    let sortedTypes = groupedAssets.keys.sorted { $0.localizedName < $1.localizedName }

                                    ForEach(sortedTypes, id: \.self) { accountType in
                                        if let accountsOfType = groupedAssets[accountType] {
                                            VStack(alignment: .leading, spacing: CashSpacing.sm) {
                                                // Type header
                                                HStack {
                                                    Image(systemName: accountType.iconName)
                                                        .foregroundStyle(CashColors.success)
                                                        .font(.subheadline)
                                                    Text(accountType.localizedName)
                                                        .font(CashTypography.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(.top, sortedTypes.first == accountType ? 0 : CashSpacing.sm)

                                                // Accounts of this type
                                                ForEach(accountsOfType) { account in
                                                    AccountBalanceRow(account: account, privacyMode: settings.privacyMode, showIcon: false)
                                                }

                                                // Subtotal for this type
                                                HStack {
                                                    Text("Subtotal")
                                                        .font(CashTypography.caption)
                                                        .foregroundStyle(.tertiary)
                                                    Spacer()
                                                    PrivacyAmountView(
                                                        amount: CurrencyFormatter.format(
                                                            accountsOfType.reduce(0) { $0 + $1.balance },
                                                            currency: currency
                                                        ),
                                                        isPrivate: settings.privacyMode,
                                                        font: CashTypography.caption,
                                                        fontWeight: .semibold,
                                                        color: CashColors.success
                                                    )
                                                }
                                                .padding(.vertical, 2)
                                            }
                                        }
                                    }

                                    // Total for this currency
                                    if netWorthByCurrency.count > 1 {
                                        GlassDivider()
                                        HStack {
                                            Text("Total")
                                                .font(CashTypography.headline)
                                            Spacer()
                                            PrivacyAmountView(
                                                amount: CurrencyFormatter.format(
                                                    currencyAssets.reduce(0) { $0 + $1.balance },
                                                    currency: currency
                                                ),
                                                isPrivate: settings.privacyMode,
                                                fontWeight: .semibold,
                                                color: CashColors.success
                                            )
                                        }
                                        .padding(.vertical, CashSpacing.xs)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                
                // Liabilities Section - grouped by currency and type
                if !liabilityAccounts.isEmpty {
                    ForEach(currencies, id: \.self) { currency in
                        let currencyLiabilities = liabilityAccounts(for: currency)
                        if !currencyLiabilities.isEmpty {
                            GlassCard(padding: CashSpacing.lg) {
                                VStack(alignment: .leading, spacing: CashSpacing.md) {
                                    HStack {
                                        Text("Liabilities")
                                            .font(CashTypography.title2)

                                        if netWorthByCurrency.count > 1 {
                                            Text("(\(CurrencyList.symbol(forCode: currency)))")
                                                .font(CashTypography.headline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    // Group by account type
                                    let groupedLiabilities = Dictionary(grouping: currencyLiabilities) { $0.accountType }
                                    let sortedTypes = groupedLiabilities.keys.sorted { $0.localizedName < $1.localizedName }

                                    ForEach(sortedTypes, id: \.self) { accountType in
                                        if let accountsOfType = groupedLiabilities[accountType] {
                                            VStack(alignment: .leading, spacing: CashSpacing.sm) {
                                                // Type header
                                                HStack {
                                                    Image(systemName: accountType.iconName)
                                                        .foregroundStyle(CashColors.error)
                                                        .font(.subheadline)
                                                    Text(accountType.localizedName)
                                                        .font(CashTypography.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(.top, sortedTypes.first == accountType ? 0 : CashSpacing.sm)

                                                // Accounts of this type
                                                ForEach(accountsOfType) { account in
                                                    AccountBalanceRow(account: account, privacyMode: settings.privacyMode, showIcon: false)
                                                }

                                                // Subtotal for this type
                                                HStack {
                                                    Text("Subtotal")
                                                        .font(CashTypography.caption)
                                                        .foregroundStyle(.tertiary)
                                                    Spacer()
                                                    PrivacyAmountView(
                                                        amount: CurrencyFormatter.format(
                                                            accountsOfType.reduce(0) { $0 + $1.balance },
                                                            currency: currency
                                                        ),
                                                        isPrivate: settings.privacyMode,
                                                        font: CashTypography.caption,
                                                        fontWeight: .semibold,
                                                        color: CashColors.error
                                                    )
                                                }
                                                .padding(.vertical, 2)
                                            }
                                        }
                                    }

                                    // Total for this currency
                                    if netWorthByCurrency.count > 1 {
                                        GlassDivider()
                                        HStack {
                                            Text("Total")
                                                .font(CashTypography.headline)
                                            Spacer()
                                            PrivacyAmountView(
                                                amount: CurrencyFormatter.format(
                                                    currencyLiabilities.reduce(0) { $0 + $1.balance },
                                                    currency: currency
                                                ),
                                                isPrivate: settings.privacyMode,
                                                fontWeight: .semibold,
                                                color: CashColors.error
                                            )
                                        }
                                        .padding(.vertical, CashSpacing.xs)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .padding(CashSpacing.lg)
        }
        .cashBackground()
        .navigationTitle("Net Worth")
        .id(settings.refreshID)
    }
}

struct CurrencyNetWorthCard: View {
    let data: NetWorthByCurrency
    var privacyMode: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: CashSpacing.lg) {
            // Currency symbol/code
            VStack(alignment: .leading, spacing: 2) {
                Text(CurrencyList.symbol(forCode: data.currency))
                    .font(CashTypography.title)
                Text(data.currency)
                    .font(CashTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)

            Divider()

            // Net Worth
            VStack(alignment: .leading, spacing: CashSpacing.xs) {
                Text("Net Worth")
                    .font(CashTypography.caption)
                    .foregroundStyle(.secondary)
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(data.netWorth, currency: data.currency),
                    isPrivate: privacyMode,
                    font: CashTypography.title2,
                    color: data.netWorth >= 0 ? CashColors.primary : CashColors.error
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Assets
            VStack(alignment: .trailing, spacing: CashSpacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(CashColors.success)
                        .font(.caption)
                    Text("Assets")
                        .font(CashTypography.caption)
                        .foregroundStyle(.secondary)
                }
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(data.assets, currency: data.currency),
                    isPrivate: privacyMode,
                    font: CashTypography.subheadline,
                    fontWeight: .medium,
                    color: CashColors.success
                )
            }

            // Liabilities
            VStack(alignment: .trailing, spacing: CashSpacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(CashColors.error)
                        .font(.caption)
                    Text("Liabilities")
                        .font(CashTypography.caption)
                        .foregroundStyle(.secondary)
                }
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(data.liabilities, currency: data.currency),
                    isPrivate: privacyMode,
                    font: CashTypography.subheadline,
                    fontWeight: .medium,
                    color: CashColors.error
                )
            }
        }
        .padding(CashSpacing.lg)
        .background(CashColors.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CashRadius.medium))
    }
}

struct AccountBalanceRow: View {
    let account: Account
    var privacyMode: Bool = false
    var showIcon: Bool = true
    
    var body: some View {
        HStack {
            if showIcon {
                Image(systemName: account.effectiveIconName)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            
            Text(account.displayName)
            
            Spacer()
            
            PrivacyAmountView(
                amount: CurrencyFormatter.format(account.balance, currency: account.currency),
                isPrivate: privacyMode,
                fontWeight: .medium
            )
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        NetWorthView()
    }
    .modelContainer(for: Account.self, inMemory: true)
    .environment(AppSettings.shared)
}
