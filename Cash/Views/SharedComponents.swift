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
    
    var body: some View {
        HStack {
            Text(type.shortName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(type == .debit ? .blue : .green)
                .frame(width: 24)
            
            Text(accountName)
                .font(.caption)
            
            Spacer()
            
            Text(amount)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Journal Entry Preview

struct JournalEntryPreview: View {
    let debitAccountName: String?
    let creditAccountName: String?
    let amount: Decimal
    let currency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let formattedAmount = CurrencyFormatter.format(amount, currency: currency)
            
            if let debit = debitAccountName, let credit = creditAccountName {
                EntryPreviewRow(accountName: debit, type: .debit, amount: formattedAmount)
                EntryPreviewRow(accountName: credit, type: .credit, amount: formattedAmount)
            } else {
                Text("Select accounts to see preview")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Account Picker

struct AccountPicker: View {
    let title: LocalizedStringKey
    let accounts: [Account]
    @Binding var selection: Account?
    var showClass: Bool = false
    
    var body: some View {
        Picker(title, selection: $selection) {
            Text("Select Account").tag(nil as Account?)
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
