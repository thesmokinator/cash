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
            VStack(spacing: 24) {
                // Net Worth Cards - One per currency
                if netWorthByCurrency.isEmpty {
                    ContentUnavailableView {
                        Label("No accounts", systemImage: "building.columns")
                    } description: {
                        Text("Create accounts to see your net worth.")
                    }
                } else if netWorthByCurrency.count == 1 {
                    // Single currency - show traditional layout
                    let data = netWorthByCurrency[0]
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Net Worth")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        PrivacyAmountView(
                            amount: CurrencyFormatter.format(data.netWorth, currency: data.currency),
                            isPrivate: settings.privacyMode,
                            font: .system(size: 48, weight: .bold),
                            color: data.netWorth >= 0 ? .primary : .red
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Summary Cards
                    HStack(spacing: 16) {
                        SummaryCard(
                            title: "Assets",
                            amount: data.assets,
                            color: .green,
                            icon: "arrow.up.circle.fill",
                            privacyMode: settings.privacyMode,
                            currency: data.currency
                        )
                        
                        SummaryCard(
                            title: "Liabilities",
                            amount: data.liabilities,
                            color: .red,
                            icon: "arrow.down.circle.fill",
                            privacyMode: settings.privacyMode,
                            currency: data.currency
                        )
                    }
                } else {
                    // Multiple currencies - show grouped by currency
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Net Worth")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            ForEach(netWorthByCurrency, id: \.currency) { data in
                                CurrencyNetWorthCard(
                                    data: data,
                                    privacyMode: settings.privacyMode
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Assets Section - grouped by currency and type
                if !assetAccounts.isEmpty {
                    ForEach(currencies, id: \.self) { currency in
                        let currencyAssets = assetAccounts(for: currency)
                        if !currencyAssets.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Assets")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    if netWorthByCurrency.count > 1 {
                                        Text("(\(CurrencyList.symbol(forCode: currency)))")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                // Group by account type
                                let groupedAssets = Dictionary(grouping: currencyAssets) { $0.accountType }
                                let sortedTypes = groupedAssets.keys.sorted { $0.localizedName < $1.localizedName }
                                
                                ForEach(sortedTypes, id: \.self) { accountType in
                                    if let accountsOfType = groupedAssets[accountType] {
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Type header
                                            HStack {
                                                Image(systemName: accountType.iconName)
                                                    .foregroundStyle(.secondary)
                                                    .font(.subheadline)
                                                Text(accountType.localizedName)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.top, sortedTypes.first == accountType ? 0 : 8)
                                            
                                            // Accounts of this type
                                            ForEach(accountsOfType) { account in
                                                AccountBalanceRow(account: account, privacyMode: settings.privacyMode, showIcon: false)
                                            }
                                            
                                            // Subtotal for this type
                                            HStack {
                                                Text("Subtotal")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                                Spacer()
                                                PrivacyAmountView(
                                                    amount: CurrencyFormatter.format(
                                                        accountsOfType.reduce(0) { $0 + $1.balance },
                                                        currency: currency
                                                    ),
                                                    isPrivate: settings.privacyMode,
                                                    font: .caption,
                                                    fontWeight: .semibold,
                                                    color: .green
                                                )
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                }
                                
                                // Total for this currency
                                if netWorthByCurrency.count > 1 {
                                    Divider()
                                    HStack {
                                        Text("Total")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        PrivacyAmountView(
                                            amount: CurrencyFormatter.format(
                                                currencyAssets.reduce(0) { $0 + $1.balance },
                                                currency: currency
                                            ),
                                            isPrivate: settings.privacyMode,
                                            fontWeight: .semibold,
                                            color: .green
                                        )
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                
                // Liabilities Section - grouped by currency and type
                if !liabilityAccounts.isEmpty {
                    ForEach(currencies, id: \.self) { currency in
                        let currencyLiabilities = liabilityAccounts(for: currency)
                        if !currencyLiabilities.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Liabilities")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    if netWorthByCurrency.count > 1 {
                                        Text("(\(CurrencyList.symbol(forCode: currency)))")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                // Group by account type
                                let groupedLiabilities = Dictionary(grouping: currencyLiabilities) { $0.accountType }
                                let sortedTypes = groupedLiabilities.keys.sorted { $0.localizedName < $1.localizedName }
                                
                                ForEach(sortedTypes, id: \.self) { accountType in
                                    if let accountsOfType = groupedLiabilities[accountType] {
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Type header
                                            HStack {
                                                Image(systemName: accountType.iconName)
                                                    .foregroundStyle(.secondary)
                                                    .font(.subheadline)
                                                Text(accountType.localizedName)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.top, sortedTypes.first == accountType ? 0 : 8)
                                            
                                            // Accounts of this type
                                            ForEach(accountsOfType) { account in
                                                AccountBalanceRow(account: account, privacyMode: settings.privacyMode, showIcon: false)
                                            }
                                            
                                            // Subtotal for this type
                                            HStack {
                                                Text("Subtotal")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                                Spacer()
                                                PrivacyAmountView(
                                                    amount: CurrencyFormatter.format(
                                                        accountsOfType.reduce(0) { $0 + $1.balance },
                                                        currency: currency
                                                    ),
                                                    isPrivate: settings.privacyMode,
                                                    font: .caption,
                                                    fontWeight: .semibold,
                                                    color: .red
                                                )
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                }
                                
                                // Total for this currency
                                if netWorthByCurrency.count > 1 {
                                    Divider()
                                    HStack {
                                        Text("Total")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        PrivacyAmountView(
                                            amount: CurrencyFormatter.format(
                                                currencyLiabilities.reduce(0) { $0 + $1.balance },
                                                currency: currency
                                            ),
                                            isPrivate: settings.privacyMode,
                                            fontWeight: .semibold,
                                            color: .red
                                        )
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Net Worth")
        .id(settings.refreshID)
    }
}

struct SummaryCard: View {
    let title: LocalizedStringKey
    let amount: Decimal
    let color: Color
    let icon: String
    var privacyMode: Bool = false
    var currency: String = "EUR"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            
            PrivacyAmountView(
                amount: CurrencyFormatter.format(amount, currency: currency),
                isPrivate: privacyMode,
                font: .title2,
                fontWeight: .semibold
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CurrencyNetWorthCard: View {
    let data: NetWorthByCurrency
    var privacyMode: Bool = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Currency symbol/code
            VStack(alignment: .leading, spacing: 2) {
                Text(CurrencyList.symbol(forCode: data.currency))
                    .font(.title)
                    .fontWeight(.bold)
                Text(data.currency)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)
            
            Divider()
            
            // Net Worth
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Worth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(data.netWorth, currency: data.currency),
                    isPrivate: privacyMode,
                    font: .title2,
                    fontWeight: .bold,
                    color: data.netWorth >= 0 ? .primary : .red
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Assets
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Assets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(data.assets, currency: data.currency),
                    isPrivate: privacyMode,
                    font: .subheadline,
                    fontWeight: .medium,
                    color: .green
                )
            }
            
            // Liabilities
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("Liabilities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                PrivacyAmountView(
                    amount: CurrencyFormatter.format(data.liabilities, currency: data.currency),
                    isPrivate: privacyMode,
                    font: .subheadline,
                    fontWeight: .medium,
                    color: .red
                )
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
