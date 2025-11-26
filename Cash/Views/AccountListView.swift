//
//  AccountListView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @State private var showingAddAccount = false
    @State private var selectedAccount: Account?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedAccount) {
                if accounts.isEmpty {
                    ContentUnavailableView {
                        Label("No Accounts", systemImage: "building.columns")
                    } description: {
                        Text("Create your first account to get started.")
                    }
                } else {
                    ForEach(AccountClass.allCases.sorted(by: { $0.displayOrder < $1.displayOrder })) { accountClass in
                        let filteredAccounts = accounts.filter { $0.accountClass == accountClass && $0.isActive && !$0.isSystem }
                        if !filteredAccounts.isEmpty {
                            Section(accountClass.localizedPluralName) {
                                ForEach(filteredAccounts) { account in
                                    AccountRowView(account: account)
                                        .tag(account)
                                }
                                .onDelete { indexSet in
                                    deleteAccounts(from: filteredAccounts, at: indexSet)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chart of Accounts")
            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddAccount = true }) {
                        Label("Add Account", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
            .id(settings.refreshID)
        } detail: {
            if let account = selectedAccount {
                AccountDetailView(account: account)
            } else {
                ContentUnavailableView {
                    Label("Select an Account", systemImage: "building.columns")
                } description: {
                    Text("Choose an account from the sidebar to view details.")
                }
            }
        }
    }
    
    private func deleteAccounts(from filteredAccounts: [Account], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let account = filteredAccounts[index]
                if !account.isSystem {
                    modelContext.delete(account)
                }
            }
        }
    }
}

struct AccountRowView: View {
    let account: Account
    
    var body: some View {
        HStack {
            Image(systemName: account.accountType.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(account.displayName)
                        .font(.headline)
                    if account.isSystem {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(formatBalance(account.balance, currency: account.currency))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(balanceColor(for: account))
        }
        .padding(.vertical, 4)
    }
    
    private func balanceColor(for account: Account) -> Color {
        if account.balance == 0 {
            return .secondary
        }
        switch account.accountClass {
        case .asset:
            return account.balance >= 0 ? .primary : .red
        case .liability:
            return .primary
        case .income:
            return .green
        case .expense:
            return .red
        case .equity:
            return .primary
        }
    }
    
    private func formatBalance(_ balance: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: balance as NSDecimalNumber) ?? "\(CurrencyList.symbol(forCode: currency))\(balance)"
    }
}

#Preview {
    AccountListView()
        .modelContainer(for: Account.self, inMemory: true)
        .environment(AppSettings.shared)
}
