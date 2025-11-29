//
//  AccountListView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftUI
import SwiftData

enum SidebarSelection: Hashable {
    case patrimony
    case forecast
    case budget
    case reports
    case scheduled
    case account(Account)
}

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(NavigationState.self) private var navigationState
    @Query(sort: \Account.accountNumber) private var accounts: [Account]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring == true }) private var scheduledTransactions: [Transaction]
    @State private var showingAddAccount = false
    @State private var showingAddTransaction = false
    @State private var selection: SidebarSelection? = .patrimony
    
    private var hasAccounts: Bool {
        !accounts.filter { $0.isActive && !$0.isSystem }.isEmpty
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if accounts.isEmpty {
                    ContentUnavailableView {
                        Label("No accounts", systemImage: "building.columns")
                    } description: {
                        Text("Create your first account to get started.")
                    }
                } else {
                    if hasAccounts {
                        Section {
                            Label("Net Worth", systemImage: "chart.pie.fill")
                                .tag(SidebarSelection.patrimony)
                            
                            Label("Forecast", systemImage: "chart.line.uptrend.xyaxis")
                                .tag(SidebarSelection.forecast)
                            
                            Label("Budget", systemImage: "envelope.fill")
                                .tag(SidebarSelection.budget)
                            
                            Label("Reports", systemImage: "chart.bar.fill")
                                .tag(SidebarSelection.reports)
                        }
                    }
                    
                    ForEach(AccountClass.allCases.sorted(by: { $0.displayOrder < $1.displayOrder })) { accountClass in
                        let filteredAccounts = accounts
                            .filter { $0.accountClass == accountClass && $0.isActive && !$0.isSystem }
                            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                        if !filteredAccounts.isEmpty {
                            Section(accountClass.localizedPluralName) {
                                // Add Scheduled as first item in Expenses section
                                if accountClass == .expense {
                                    HStack {
                                        Label("Scheduled", systemImage: "calendar.badge.clock")
                                        Spacer()
                                        if !scheduledTransactions.isEmpty {
                                            Text("\(scheduledTransactions.count)")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(.quaternary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .tag(SidebarSelection.scheduled)
                                }
                                
                                ForEach(filteredAccounts) { account in
                                    AccountRowView(account: account)
                                        .tag(SidebarSelection.account(account))
                                }
                                .onDelete { indexSet in
                                    deleteAccounts(from: filteredAccounts, at: indexSet)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chart of accounts")
            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            settings.privacyMode.toggle()
                        }
                    } label: {
                        Label(
                            settings.privacyMode ? "Show amounts" : "Hide amounts",
                            systemImage: settings.privacyMode ? "eye.slash.fill" : "eye.fill"
                        )
                    }
                    .help(settings.privacyMode ? "Show amounts" : "Hide amounts")
                    
                    Button(action: { showingAddAccount = true }) {
                        Label("Add account", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
            .id(settings.refreshID)
        } detail: {
            Group {
                switch selection {
                case .patrimony:
                    NetWorthView()
                case .forecast:
                    ForecastView()
                case .budget:
                    BudgetView()
                case .reports:
                    ReportsView()
                case .scheduled:
                    ScheduledTransactionsView()
                case .account(let account):
                    AccountDetailView(account: account, showingAddTransaction: $showingAddTransaction)
                case nil:
                    ContentUnavailableView {
                        Label("Select an account", systemImage: "building.columns")
                    } description: {
                        Text("Choose an account from the sidebar to view details")
                    }
                }
            }
        }
        .onChange(of: selection) { _, newValue in
            switch newValue {
            case .account(let account):
                navigationState.isViewingAccount = true
                navigationState.isViewingScheduled = false
                navigationState.currentAccount = account
            case .scheduled:
                navigationState.isViewingAccount = false
                navigationState.isViewingScheduled = true
                navigationState.currentAccount = nil
            default:
                navigationState.isViewingAccount = false
                navigationState.isViewingScheduled = false
                navigationState.currentAccount = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewAccount)) { _ in
            showingAddAccount = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewTransaction)) { _ in
            if navigationState.isViewingAccount {
                showingAddTransaction = true
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
    @Environment(AppSettings.self) private var settings
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
            
            PrivacyAmountView(
                amount: formatBalance(account.balance, currency: account.currency),
                isPrivate: settings.privacyMode,
                font: .subheadline,
                fontWeight: .medium,
                color: balanceColor(for: account)
            )
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
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(NavigationState())
}
