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
    @State private var showingReconciliation = false
    @Binding var showingAddTransaction: Bool
    @State private var showingAddInvestmentTransaction = false
    @State private var etfQuote: ETFQuote?
    @State private var isLoadingQuote = false
    @State private var quoteError: String?
    @State private var investmentPosition: InvestmentPosition = .empty
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Card
            VStack(spacing: 12) {
                // Main header row
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    // Compact vertical layout for iPhone
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: account.effectiveIconName)
                                .font(.title)
                                .foregroundStyle(.tint)
                            
                            Text(account.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        
                        HStack {
                            // Compact info pills
                            HStack(spacing: 6) {
                                CompactPill(text: account.accountClass.localizedName)
                                CompactPill(text: account.accountType.localizedName)
                                CompactPill(text: account.currency)
                                
                                // Investment-specific info
                                if account.accountType == .investment {
                                    if let ticker = account.ticker, !ticker.isEmpty {
                                        CompactPill(text: ticker, isHighlighted: true)
                                    }
                                }
                                
                                // Account number if present
                                if !account.accountNumber.isEmpty && account.accountType != .investment {
                                    CompactPill(text: "#\(account.accountNumber)")
                                }
                            }
                            .font(.caption2)
                            
                            Spacer()
                        }
                        
                        HStack {
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(account.balance, currency: account.currency),
                                isPrivate: settings.privacyMode,
                                font: .title,
                                fontWeight: .semibold,
                                color: balanceColor
                            )
                            
                            Spacer()
                            
                            Text(account.accountClass.normalBalance == .debit ? "Normal: debit" : "Normal: credit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // Original horizontal layout for iPad
                    HStack(alignment: .top) {
                        Image(systemName: account.effectiveIconName)
                            .font(.title)
                            .foregroundStyle(.tint)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            // Compact info row with all details
                            HStack(spacing: 6) {
                                CompactPill(text: account.accountClass.localizedName)
                                CompactPill(text: account.accountType.localizedName)
                                CompactPill(text: account.currency)
                                
                                // Investment-specific info
                                if account.accountType == .investment {
                                    if let isin = account.isin, !isin.isEmpty {
                                        CompactPill(text: isin, icon: "number")
                                    }
                                    if let ticker = account.ticker, !ticker.isEmpty {
                                        CompactPill(text: ticker, isHighlighted: true)
                                    }
                                }
                                
                                // Account number if present
                                if !account.accountNumber.isEmpty && account.accountType != .investment {
                                    CompactPill(text: "#\(account.accountNumber)")
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(account.balance, currency: account.currency),
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
                }
                #else
                // macOS layout - same as iPad
                HStack(alignment: .top) {
                    Image(systemName: account.effectiveIconName)
                        .font(.title)
                        .foregroundStyle(.tint)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Compact info row with all details
                        HStack(spacing: 6) {
                            CompactPill(text: account.accountClass.localizedName)
                            CompactPill(text: account.accountType.localizedName)
                            CompactPill(text: account.currency)
                            
                            // Investment-specific info
                            if account.accountType == .investment {
                                if let isin = account.isin, !isin.isEmpty {
                                    CompactPill(text: isin, icon: "number")
                                }
                                if let ticker = account.ticker, !ticker.isEmpty {
                                    CompactPill(text: ticker, isHighlighted: true)
                                }
                            }
                            
                            // Account number if present
                            if !account.accountNumber.isEmpty && account.accountType != .investment {
                                CompactPill(text: "#\(account.accountNumber)")
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        PrivacyAmountView(
                            amount: CurrencyFormatter.format(account.balance, currency: account.currency),
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
                #endif
                
                // Live ETF Quote Box (only if enabled in settings and has ISIN)
                if settings.showLiveQuotes,
                   account.accountType == .investment,
                   let isin = account.isin,
                   !isin.isEmpty {
                    LiveQuoteBox(
                        quote: etfQuote,
                        isLoading: isLoadingQuote,
                        error: quoteError,
                        currency: account.currency
                    )
                }
                
                // Investment Position Summary
                if account.accountType == .investment, investmentPosition.hasShares {
                    InvestmentPositionBadge(
                        position: investmentPosition,
                        currency: account.currency
                    )
                }
            }
            .padding()
            .background(.regularMaterial)
            
            Divider()
            
            // Transactions List
            TransactionListView(account: account, showToolbar: false)
            
            Spacer(minLength: 0)
        }
        .navigationTitle(account.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 1. Add transaction
                Button {
                    if account.accountType == .investment {
                        showingAddInvestmentTransaction = true
                    } else {
                        showingAddTransaction = true
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                
                // 2. Reconcile
                if (account.accountClass == .asset || account.accountClass == .liability) && account.accountType != .investment {
                    Button(action: { showingReconciliation = true }) {
                        Label("Reconcile", systemImage: "checkmark.shield")
                    }
                }
                
                // 3. Edit account
                Button(action: { showingEditSheet = true }) {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(account.isSystem)
                
                // 4. Delete
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
            if account.accountType == .investment {
                AddInvestmentTransactionView(preselectedInvestmentAccount: account)
            } else {
                AddTransactionView(preselectedAccount: account)
            }
        }
        .sheet(isPresented: $showingAddInvestmentTransaction) {
            AddInvestmentTransactionView(preselectedInvestmentAccount: account)
        }
        .sheet(isPresented: $showingReconciliation) {
            ReconciliationView(account: account)
        }
        .alert(
            "Delete account",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(account)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this account? This action cannot be undone.")
        }
        .task(id: account.isin) {
            await loadETFQuoteIfNeeded()
        }
        .task {
            calculateInvestmentPosition()
        }
        .onChange(of: (account.entries ?? []).count) {
            calculateInvestmentPosition()
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
    
    private func loadETFQuoteIfNeeded() async {
        guard settings.showLiveQuotes,
              account.accountType == .investment,
              let isin = account.isin,
              !isin.isEmpty else {
            return
        }
        
        isLoadingQuote = true
        quoteError = nil
        
        do {
            let locale = ETFAPIHelper.getUserLocale()
            let quote = try await ETFAPIHelper.shared.fetchQuote(isin: isin, locale: locale, currency: account.currency)
            etfQuote = quote
            
            // Update position with market price
            investmentPosition = InvestmentHelper.calculatePosition(
                for: account,
                currentPrice: quote.latestQuote.raw
            )
        } catch {
            quoteError = error.localizedDescription
        }
        
        isLoadingQuote = false
    }
    
    private func calculateInvestmentPosition() {
        guard account.accountType == .investment else { return }
        
        // Calculate position (without market price if quote not loaded)
        let currentPrice = etfQuote?.latestQuote.raw
        
        investmentPosition = InvestmentHelper.calculatePosition(
            for: account,
            currentPrice: currentPrice
        )
    }
}

// MARK: - Compact Pill Component

struct CompactPill: View {
    let text: String
    var icon: String? = nil
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8))
            }
            Text(text)
        }
        .font(.caption2)
        .fontWeight(.medium)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isHighlighted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
        .foregroundStyle(isHighlighted ? Color.accentColor : Color.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Live Quote Box Component

struct LiveQuoteBox: View {
    let quote: ETFQuote?
    let isLoading: Bool
    let error: String?
    let currency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("Live Quote")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                
                Spacer()
                
                if let quote = quote, let venue = quote.quoteTradingVenue {
                    Text(venue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Content
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else if let error = error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else if let quote = quote {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    // Current price
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Price")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(quote.latestQuote.localized) \(currency)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                    
                    // Day change
                    if let change = quote.dtdAmt {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Change")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: change.raw >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption2)
                                Text(change.localized)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(change.raw >= 0 ? .green : .red)
                        }
                    }
                    
                    // Day change percentage
                    if let pct = quote.dtdPrc {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("% Change")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(pct.localized)%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(pct.raw >= 0 ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    // 52-week range
                    if let lowHigh = quote.quoteLowHigh {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("52W Range")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(lowHigh.low.localized) - \(lowHigh.high.localized)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Quote data unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
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
