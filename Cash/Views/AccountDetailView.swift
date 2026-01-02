//
//  AccountDetailView.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import SwiftData
import SwiftUI

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
                if DeviceType.current.isCompact {
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
                                if !account.accountNumber.isEmpty
                                    && account.accountType != .investment
                                {
                                    CompactPill(text: "#\(account.accountNumber)")
                                }
                            }
                            .font(.caption2)

                            Spacer()
                        }

                        HStack {
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(
                                    account.balance, currency: account.currency),
                                isPrivate: settings.privacyMode,
                                font: .title,
                                fontWeight: .semibold,
                                color: balanceColor
                            )

                            Spacer()

                            Text(
                                account.accountClass.normalBalance == .debit
                                    ? "Normal: debit" : "Normal: credit"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // Horizontal layout for iPad
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
                                if !account.accountNumber.isEmpty
                                    && account.accountType != .investment
                                {
                                    CompactPill(text: "#\(account.accountNumber)")
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            PrivacyAmountView(
                                amount: CurrencyFormatter.format(
                                    account.balance, currency: account.currency),
                                isPrivate: settings.privacyMode,
                                font: .title,
                                fontWeight: .semibold,
                                color: balanceColor
                            )
                            Text(
                                account.accountClass.normalBalance == .debit
                                    ? "Normal: debit" : "Normal: credit"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // Live ETF Quote Box (only if enabled in settings and has ISIN)
                if settings.showLiveQuotes,
                    account.accountType == .investment,
                    let isin = account.isin,
                    !isin.isEmpty
                {
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
        .navigationBarTitleDisplayModeInline()
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
                if (account.accountClass == .asset || account.accountClass == .liability)
                    && account.accountType != .investment
                {
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
        .cashBackground()
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
            Button("Cancel", role: .cancel) {}
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
            !isin.isEmpty
        else {
            return
        }

        isLoadingQuote = true
        quoteError = nil

        do {
            let locale = ETFAPIHelper.getUserLocale()
            let quote = try await ETFAPIHelper.shared.fetchQuote(
                isin: isin, locale: locale, currency: account.currency)
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
        HStack(spacing: 2) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isHighlighted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
        .foregroundStyle(isHighlighted ? Color.accentColor : Color.secondary)
        .clipShape(Capsule())
    }
}

// MARK: - Live Quote Box

struct LiveQuoteBox: View {
    let quote: ETFQuote?
    let isLoading: Bool
    let error: String?
    let currency: String

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading quote...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let quote = quote {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Market Price")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(quote.latestQuote.localized)
                            .font(.headline)
                    }

                    Spacer()

                    if let dtdAmt = quote.dtdAmt, let dtdPrc = quote.dtdPrc {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Change")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Image(
                                    systemName: dtdAmt.raw >= 0
                                        ? "arrow.up.right" : "arrow.down.right"
                                )
                                .font(.caption)
                                Text(dtdAmt.localized)
                                Text("(\(dtdPrc.localized))")
                            }
                            .font(.subheadline)
                            .foregroundStyle(dtdAmt.raw >= 0 ? .green : .red)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.platformSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Investment Position Badge

struct InvestmentPositionBadge: View {
    let position: InvestmentPosition
    let currency: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shares")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(InvestmentHelper.formatShares(position.shares))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Avg Cost")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(InvestmentHelper.formatPrice(position.averageCost, currency: currency))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Total Cost")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.format(position.totalCost, currency: currency))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if let gain = position.unrealizedGain {
                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("P/L")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    let formatted = InvestmentHelper.formatGainLoss(gain, currency: currency)
                    HStack(spacing: 4) {
                        Text(formatted.text)
                        if let percent = position.unrealizedGainPercent {
                            Text("(\(InvestmentHelper.formatPercentage(percent)))")
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(formatted.isPositive ? .green : .red)
                }
            }
        }
        .padding(12)
        .background(Color.platformSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(
            account: Account(
                name: "Checking Account",
                accountNumber: "001",
                currency: "EUR",
                accountClass: .asset,
                accountType: .cash
            ),
            showingAddTransaction: .constant(false)
        )
    }
    .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
    .environment(AppSettings.shared)
}
