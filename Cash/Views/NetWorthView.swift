//
//  NetWorthView.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import SwiftUI
import SwiftData

struct NetWorthView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    
    private var assetAccounts: [Account] {
        accounts.filter { $0.accountClass == .asset && $0.isActive && !$0.isSystem }
    }
    
    private var liabilityAccounts: [Account] {
        accounts.filter { $0.accountClass == .liability && $0.isActive && !$0.isSystem }
    }
    
    private var totalAssets: Decimal {
        assetAccounts.reduce(0) { $0 + $1.balance }
    }
    
    private var totalLiabilities: Decimal {
        liabilityAccounts.reduce(0) { $0 + $1.balance }
    }
    
    private var netWorth: Decimal {
        totalAssets - totalLiabilities
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Net Worth Card
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Text("Net Worth")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    PrivacyAmountView(
                        amount: CurrencyFormatter.format(netWorth),
                        isPrivate: settings.privacyMode,
                        font: .system(size: 48, weight: .bold),
                        color: netWorth >= 0 ? .primary : .red
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
                        amount: totalAssets,
                        color: .green,
                        icon: "arrow.up.circle.fill",
                        privacyMode: settings.privacyMode
                    )
                    
                    SummaryCard(
                        title: "Liabilities",
                        amount: totalLiabilities,
                        color: .red,
                        icon: "arrow.down.circle.fill",
                        privacyMode: settings.privacyMode
                    )
                }
                
                // Assets Section
                if !assetAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assets")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        ForEach(assetAccounts) { account in
                            AccountBalanceRow(account: account, privacyMode: settings.privacyMode)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Liabilities Section
                if !liabilityAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Liabilities")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        ForEach(liabilityAccounts) { account in
                            AccountBalanceRow(account: account, privacyMode: settings.privacyMode)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                amount: CurrencyFormatter.format(amount),
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

struct AccountBalanceRow: View {
    let account: Account
    var privacyMode: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: account.accountType.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
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
