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
