//
//  SharedComponents.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import SwiftUI

// MARK: - Currency Formatting

struct CurrencyFormatter {
    static nonisolated func format(_ amount: Decimal, currency: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static nonisolated func formatCompact(_ amount: Decimal, currency: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static nonisolated func parse(_ text: String) -> Decimal {
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
                    EntryPreviewRow(
                        accountName: debit, type: .debit, amount: formattedAmount, isOutgoing: false
                    )
                    Divider()
                    EntryPreviewRow(
                        accountName: credit, type: .credit, amount: formattedAmount,
                        isOutgoing: true)
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

// MARK: - Account Balance Preview

struct AccountBalancePreview: View {
    let accounts: [(account: Account, newBalance: Decimal)]
    let emptyMessage: String?

    init(accounts: [(account: Account, newBalance: Decimal)], emptyMessage: String? = nil) {
        self.accounts = accounts
        self.emptyMessage = emptyMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if accounts.isEmpty {
                Text(emptyMessage ?? "Select accounts to see preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(accounts, id: \.account.id) { item in
                    let balanceChange = item.newBalance - item.account.balance
                    let isGaining = balanceChange > 0
                    HStack {
                        Text(item.account.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text(
                            CurrencyFormatter.format(
                                item.newBalance, currency: item.account.currency)
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(isGaining ? .green : .red)
                    }
                    .padding(.vertical, 4)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
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
                        Label(account.displayName, systemImage: account.effectiveIconName)
                        Text("(\(account.accountClass.localizedName))")
                            .foregroundStyle(.secondary)
                    }
                    .tag(account as Account?)
                } else {
                    Label(account.displayName, systemImage: account.effectiveIconName)
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
        // On iOS/iPadOS, apps cannot programmatically quit
        // iOS manages app lifecycle
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
            let iconName =
                entries.first { $0.account?.accountClass == .expense }?.account?.accountType
                .iconName ?? "arrow.up.circle.fill"
            return (iconName, .red)
        } else if hasIncome {
            let iconName =
                entries.first { $0.account?.accountClass == .income }?.account?.accountType.iconName
                ?? "arrow.down.circle.fill"
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

// MARK: - Icon Picker View

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String?

    @State private var searchText = ""
    @State private var selectedCategory: IconCategory = .all

    enum IconCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case finance = "Finance"
        case shopping = "Shopping"
        case food = "Food & Dining"
        case transportation = "Transportation"
        case home = "Home & Living"
        case health = "Health & Fitness"
        case entertainment = "Entertainment"
        case work = "Work & Education"
        case travel = "Travel"
        case other = "Other"

        var id: String { rawValue }

        var icons: [String] {
            switch self {
            case .all:
                return IconCategory.allCases.filter { $0 != .all }.flatMap { $0.icons }
            case .finance:
                return [
                    "dollarsign.circle.fill", "creditcard.fill", "banknote.fill",
                    "chart.line.uptrend.xyaxis", "chart.pie.fill", "percent", "chart.bar.fill",
                    "bitcoinsign.circle.fill",
                ]
            case .shopping:
                return [
                    "bag.fill", "cart.fill", "basket.fill", "giftcard.fill", "tag.fill",
                    "storefront.fill", "shippingbox.fill",
                ]
            case .food:
                return [
                    "fork.knife", "cup.and.saucer.fill", "mug.fill", "wineglass.fill",
                    "birthday.cake.fill", "takeoutbag.and.cup.and.straw.fill", "popcorn.fill",
                ]
            case .transportation:
                return [
                    "car.fill", "bus.fill", "tram.fill", "bicycle", "scooter", "fuelpump.fill",
                    "parkingsign", "bolt.car.fill",
                ]
            case .home:
                return [
                    "house.fill", "lightbulb.fill", "fan.fill", "washer.fill", "toilet.fill",
                    "bed.double.fill", "sofa.fill", "lamp.table.fill",
                ]
            case .health:
                return [
                    "heart.fill", "figure.walk", "figure.run", "dumbbell.fill", "cross.case.fill",
                    "pills.fill", "syringe.fill", "stethoscope",
                ]
            case .entertainment:
                return [
                    "tv.fill", "film.fill", "music.note", "gamecontroller.fill", "sportscourt.fill",
                    "theatermasks.fill", "ticket.fill", "party.popper.fill",
                ]
            case .work:
                return [
                    "briefcase.fill", "laptopcomputer", "book.fill", "graduationcap.fill", "pencil",
                    "folder.fill", "doc.text.fill", "calendar",
                ]
            case .travel:
                return [
                    "airplane", "suitcase.rolling.fill", "globe", "map.fill", "location.fill",
                    "camera.fill", "building.2.fill", "tent.fill",
                ]
            case .other:
                return [
                    "questionmark.circle.fill", "ellipsis.circle.fill", "circle.fill",
                    "square.fill", "triangle.fill", "star.fill", "heart.fill", "flag.fill",
                ]
            }
        }
    }

    private var filteredIcons: [String] {
        let categoryIcons = selectedCategory.icons
        if searchText.isEmpty {
            return categoryIcons
        }
        return categoryIcons.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and category in compact header
                VStack(spacing: 8) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.body)
                        TextField("Search icons", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Category picker as menu
                    HStack {
                        Text("Category:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("", selection: $selectedCategory) {
                            ForEach(IconCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)

                Divider()

                // Icons grid with tighter spacing
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(70), spacing: 0), count: 8),
                        spacing: 0
                    ) {
                        ForEach(filteredIcons, id: \.self) { iconName in
                            Button {
                                selectedIcon = iconName
                                dismiss()
                            } label: {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .frame(width: 70, height: 60)
                                    .background(
                                        selectedIcon == iconName
                                            ? Color.accentColor.opacity(0.2) : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(iconName)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Choose Icon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}
