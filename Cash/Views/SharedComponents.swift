//
//  SharedComponents.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import SwiftUI

// MARK: - Currency Formatting

struct CurrencyFormatter {
    static func format(_ amount: Decimal, currency: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
    
    static func formatCompact(_ amount: Decimal, currency: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
    
    static func parse(_ text: String) -> Decimal {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned) ?? 0
    }
}

// MARK: - Entry Preview Row

struct EntryPreviewRow: View {
    let accountName: String
    let type: EntryType
    let amount: String
    let isOutgoing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isOutgoing ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(isOutgoing ? .red : .green)
                .font(.body)
            
            Text(accountName)
                .font(.subheadline)
            
            Spacer()
            
            Text(type.shortName.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Text(isOutgoing ? "-\(amount)" : "+\(amount)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isOutgoing ? .red : .green)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Journal Entry Preview

struct JournalEntryPreview: View {
    let debitAccountName: String?
    let creditAccountName: String?
    let amount: Decimal
    let currency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let formattedAmount = CurrencyFormatter.format(amount, currency: currency)
            
            if let debit = debitAccountName, let credit = creditAccountName {
                VStack(spacing: 0) {
                    EntryPreviewRow(accountName: debit, type: .debit, amount: formattedAmount, isOutgoing: false)
                    Divider()
                    EntryPreviewRow(accountName: credit, type: .credit, amount: formattedAmount, isOutgoing: true)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
            } else {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text("Select accounts to see preview")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Account Picker

struct AccountPicker: View {
    let title: String
    let accounts: [Account]
    @Binding var selection: Account?
    var showClass: Bool = false
    
    var body: some View {
        Picker(title, selection: $selection) {
            Text("Select account").tag(nil as Account?)
            ForEach(accounts) { account in
                if showClass {
                    HStack {
                        Label(account.displayName, systemImage: account.accountType.iconName)
                        Text("(\(account.accountClass.localizedName))")
                            .foregroundStyle(.secondary)
                    }
                    .tag(account as Account?)
                } else {
                    Label(account.displayName, systemImage: account.accountType.iconName)
                        .tag(account as Account?)
                }
            }
        }
    }
}

// MARK: - Close Button

struct CloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .focusable(false)
    }
}

// MARK: - App Utilities

struct AppUtilities {
    static func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Privacy Amount View

struct PrivacyAmountView: View {
    let amount: String
    let isPrivate: Bool
    var font: Font = .body
    var fontWeight: Font.Weight = .regular
    var color: Color = .primary
    
    var body: some View {
        Text(amount)
            .font(font)
            .fontWeight(fontWeight)
            .foregroundColor(isPrivate ? .clear : color)
            .background(
                Group {
                    if isPrivate {
                        Text(amount)
                            .font(font)
                            .fontWeight(fontWeight)
                            .foregroundColor(.secondary)
                            .blur(radius: 8)
                    }
                }
            )
    }
}

// MARK: - Privacy View Modifier

struct PrivacyBlurModifier: ViewModifier {
    let isPrivate: Bool
    
    func body(content: Content) -> some View {
        content
            .blur(radius: isPrivate ? 8 : 0)
            .opacity(isPrivate ? 0.6 : 1)
    }
}

extension View {
    func privacyBlur(_ isPrivate: Bool) -> some View {
        modifier(PrivacyBlurModifier(isPrivate: isPrivate))
    }
}

// MARK: - Transaction Helpers

struct TransactionHelper {
    
    /// Returns the icon and color for a transaction based on its entries
    static func iconInfo(for transaction: Transaction) -> (iconName: String, color: Color) {
        let entries = transaction.entries ?? []
        let hasExpense = entries.contains { $0.account?.accountClass == .expense }
        let hasIncome = entries.contains { $0.account?.accountClass == .income }
        
        if hasExpense {
            let iconName = entries.first { $0.account?.accountClass == .expense }?.account?.accountType.iconName ?? "arrow.up.circle.fill"
            return (iconName, .red)
        } else if hasIncome {
            let iconName = entries.first { $0.account?.accountClass == .income }?.account?.accountType.iconName ?? "arrow.down.circle.fill"
            return (iconName, .green)
        } else {
            return ("arrow.left.arrow.right.circle.fill", .blue)
        }
    }
    
    /// Returns a summary string for a transaction (expense/income account name or "Transfer")
    static func summary(for transaction: Transaction) -> String {
        let entries = transaction.entries ?? []
        let expenseAccount = entries.first { $0.account?.accountClass == .expense }?.account
        let incomeAccount = entries.first { $0.account?.accountClass == .income }?.account
        
        if let expense = expenseAccount {
            return expense.name
        } else if let income = incomeAccount {
            return income.name
        } else {
            return String(localized: "Transfer")
        }
    }
    
    /// Returns a string showing the accounts involved in a transaction (credit → debit)
    static func accountsSummary(for transaction: Transaction) -> String {
        let entries = transaction.entries ?? []
        let debitAccount = entries.first { $0.entryType == .debit }?.account
        let creditAccount = entries.first { $0.entryType == .credit }?.account
        
        if let debit = debitAccount, let credit = creditAccount {
            return "\(credit.name) → \(debit.name)"
        }
        return ""
    }
}

// MARK: - Transaction Icon View

struct TransactionIconView: View {
    let transaction: Transaction
    
    var body: some View {
        let info = TransactionHelper.iconInfo(for: transaction)
        Image(systemName: info.iconName)
            .foregroundColor(info.color)
    }
}

// MARK: - Labeled Amount Row

/// A reusable row component for displaying a label with an amount value
/// Used in loan calculators, reports, and financial summaries
struct LabeledAmountRow: View {
    @Environment(AppSettings.self) private var settings
    let label: LocalizedStringKey
    let value: Decimal
    let currency: String
    var valueColor: Color = .primary
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(isHighlighted ? .primary : .secondary)
            Spacer()
            PrivacyAmountView(
                amount: CurrencyFormatter.format(value, currency: currency),
                isPrivate: settings.privacyMode,
                font: isHighlighted ? .headline : .body,
                fontWeight: isHighlighted ? .semibold : .regular,
                color: valueColor
            )
        }
    }
}
