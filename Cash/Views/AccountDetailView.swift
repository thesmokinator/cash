//
//  AccountDetailView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

struct AccountDetailView: View {
    @Bindable var account: Account
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @Binding var showingAddTransaction: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: account.accountType.iconName)
                        .font(.title)
                        .foregroundStyle(.tint)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        HStack(spacing: 8) {
                            Text(account.accountClass.localizedName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !account.accountNumber.isEmpty {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text("#\(account.accountNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        PrivacyAmountView(
                            amount: formatBalance(account.balance, currency: account.currency),
                            isPrivate: settings.privacyMode,
                            font: .title,
                            fontWeight: .semibold,
                            color: balanceColor
                        )
                        Text(account.accountClass.normalBalance == .debit ? "Normal: debit" : "Normal: credit")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 16) {
                    DetailPill(label: "Class", value: account.accountClass.localizedName)
                    DetailPill(label: "Type", value: account.accountType.localizedName)
                    DetailPill(label: "Currency", value: account.currency)
                }
            }
            .padding()
            .background(.regularMaterial)
            
            Divider()
            
            // Transactions List
            TransactionListView(account: account)
            
            Spacer(minLength: 0)
        }
        .navigationTitle(account.displayName)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingEditSheet = true }) {
                    Label("Edit account", systemImage: "pencil")
                }
                .disabled(account.isSystem)
                
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(account.isSystem)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAccountView(account: account)
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(preselectedAccount: account)
        }
        .confirmationDialog(
            "Delete account",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(account)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this account? This action cannot be undone.")
        }
        .id(settings.refreshID)
    }
    
    private var balanceColor: Color {
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

struct DetailPill: View {
    let label: LocalizedStringKey
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    @Previewable @State var account = Account(
        name: "Checking Account",
        accountNumber: "1010",
        currency: "EUR",
        accountClass: .asset,
        accountType: .bank
    )
    @Previewable @State var showingAddTransaction = false
    
    NavigationStack {
        AccountDetailView(account: account, showingAddTransaction: $showingAddTransaction)
    }
    .modelContainer(for: Account.self, inMemory: true)
    .environment(AppSettings.shared)
}
