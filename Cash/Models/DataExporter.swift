//
//  DataExporter.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case cashBackup = "cashdata"
    case ofx = "ofx"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .cashBackup:
            return "Cash Backup"
        case .ofx:
            return "OFX"
        }
    }
    
    var fileExtension: String {
        rawValue
    }
    
    var utType: UTType {
        switch self {
        case .cashBackup:
            return .data
        case .ofx:
            return .xml
        }
    }
    
    var iconName: String {
        switch self {
        case .cashBackup:
            return "doc.zipper"
        case .ofx:
            return "doc.text"
        }
    }
}

// MARK: - Exportable Data Structures

struct ExportableAccount: Codable {
    let id: UUID
    let name: String
    let accountNumber: String
    let currency: String
    let accountClass: String
    let accountType: String
    let isActive: Bool
    let isSystem: Bool
    let createdAt: Date
    
    init(from account: Account) {
        self.id = account.id
        self.name = account.name
        self.accountNumber = account.accountNumber
        self.currency = account.currency
        self.accountClass = account.accountClassRawValue
        self.accountType = account.accountTypeRawValue
        self.isActive = account.isActive
        self.isSystem = account.isSystem
        self.createdAt = account.createdAt
    }
}

struct ExportableEntry: Codable {
    let id: UUID
    let entryType: String
    let amount: String // Decimal as string for precision
    let accountId: UUID
    
    init(from entry: Entry) {
        self.id = entry.id
        self.entryType = entry.entryTypeRawValue
        self.amount = "\(entry.amount)"
        self.accountId = entry.account?.id ?? UUID()
    }
}

struct ExportableAttachment: Codable {
    let id: UUID
    let filename: String
    let mimeType: String
    let data: String // Base64 encoded
    let createdAt: Date
    
    init(from attachment: Attachment) {
        self.id = attachment.id
        self.filename = attachment.filename
        self.mimeType = attachment.mimeType
        self.data = attachment.data.base64EncodedString()
        self.createdAt = attachment.createdAt
    }
}

struct ExportableRecurrenceRule: Codable {
    let id: UUID
    let frequency: String
    let interval: Int
    let dayOfMonth: Int?
    let dayOfWeek: Int?
    let monthOfYear: Int?
    let weekendAdjustment: String
    let startDate: Date
    let endDate: Date?
    let nextOccurrence: Date?
    let isActive: Bool
    
    init(from rule: RecurrenceRule) {
        self.id = rule.id
        self.frequency = rule.frequencyRawValue
        self.interval = rule.interval
        self.dayOfMonth = rule.dayOfMonth
        self.dayOfWeek = rule.dayOfWeek
        self.monthOfYear = rule.monthOfYear
        self.weekendAdjustment = rule.weekendAdjustmentRawValue
        self.startDate = rule.startDate
        self.endDate = rule.endDate
        self.nextOccurrence = rule.nextOccurrence
        self.isActive = rule.isActive
    }
}

struct ExportableTransaction: Codable {
    let id: UUID
    let date: Date
    let descriptionText: String
    let reference: String
    let createdAt: Date
    let isRecurring: Bool
    let entries: [ExportableEntry]
    let attachments: [ExportableAttachment]
    let recurrenceRule: ExportableRecurrenceRule?
    
    init(from transaction: Transaction) {
        self.id = transaction.id
        self.date = transaction.date
        self.descriptionText = transaction.descriptionText
        self.reference = transaction.reference
        self.createdAt = transaction.createdAt
        self.isRecurring = transaction.isRecurring
        self.entries = (transaction.entries ?? []).map { ExportableEntry(from: $0) }
        self.attachments = (transaction.attachments ?? []).map { ExportableAttachment(from: $0) }
        self.recurrenceRule = transaction.recurrenceRule.map { ExportableRecurrenceRule(from: $0) }
    }
}

struct ExportableData: Codable {
    let version: String
    let exportDate: Date
    let accounts: [ExportableAccount]
    let transactions: [ExportableTransaction]
    
    init(accounts: [Account], transactions: [Transaction]) {
        self.version = "1.0"
        self.exportDate = Date()
        self.accounts = accounts.map { ExportableAccount(from: $0) }
        self.transactions = transactions.map { ExportableTransaction(from: $0) }
    }
}

// MARK: - Data Exporter

enum DataExporterError: LocalizedError {
    case noData
    case encodingFailed
    case decodingFailed
    case compressionFailed
    case decompressionFailed
    case invalidFormat
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return String(localized: "No data to export")
        case .encodingFailed:
            return String(localized: "Failed to encode data")
        case .decodingFailed:
            return String(localized: "Failed to decode data")
        case .compressionFailed:
            return String(localized: "Failed to compress data")
        case .decompressionFailed:
            return String(localized: "Failed to decompress data")
        case .invalidFormat:
            return String(localized: "Invalid file format")
        case .importFailed(let reason):
            return String(localized: "Import failed: \(reason)")
        }
    }
}

struct DataExporter {
    
    // MARK: - Export Cash Backup (JSON + LZFSE)
    
    static func exportCashBackup(accounts: [Account], transactions: [Transaction]) throws -> Data {
        let exportData = ExportableData(accounts: accounts, transactions: transactions)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(exportData) else {
            throw DataExporterError.encodingFailed
        }
        
        guard let compressedData = try? (jsonData as NSData).compressed(using: .lzfse) as Data else {
            throw DataExporterError.compressionFailed
        }
        
        return compressedData
    }
    
    // MARK: - Export OFX
    
    /// Export data in OFX (Open Financial Exchange) format
    /// Each account is exported as a separate statement within the OFX document
    static func exportOFX(accounts: [Account], transactions: [Transaction]) throws -> Data {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let now = Date()
        let dtServer = dateFormatter.string(from: now)
        
        var ofxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <?OFX OFXHEADER="200" VERSION="220" SECURITY="NONE" OLDFILEUID="NONE" NEWFILEUID="NONE"?>
        <OFX>
        <SIGNONMSGSRSV1>
        <SONRS>
        <STATUS>
        <CODE>0</CODE>
        <SEVERITY>INFO</SEVERITY>
        </STATUS>
        <DTSERVER>\(dtServer)</DTSERVER>
        <LANGUAGE>ENG</LANGUAGE>
        </SONRS>
        </SIGNONMSGSRSV1>
        <BANKMSGSRSV1>
        
        """
        
        // Group transactions by account
        var transactionsByAccount: [UUID: [(transaction: Transaction, entry: Entry)]] = [:]
        
        for transaction in transactions {
            for entry in transaction.entries ?? [] {
                guard let account = entry.account else { continue }
                if transactionsByAccount[account.id] == nil {
                    transactionsByAccount[account.id] = []
                }
                transactionsByAccount[account.id]?.append((transaction, entry))
            }
        }
        
        // Export only asset and liability accounts (bank accounts, credit cards, etc.)
        let exportableAccounts = accounts.filter { account in
            account.accountClass == .asset || account.accountClass == .liability
        }
        
        for account in exportableAccounts {
            let accountTransactions = transactionsByAccount[account.id] ?? []
            
            // Skip accounts with no transactions
            guard !accountTransactions.isEmpty else { continue }
            
            // Sort transactions by date
            let sortedTransactions = accountTransactions.sorted { $0.transaction.date < $1.transaction.date }
            
            // Determine date range
            let startDate = sortedTransactions.first?.transaction.date ?? now
            let endDate = sortedTransactions.last?.transaction.date ?? now
            
            let dtStart = dateFormatter.string(from: startDate)
            let dtEnd = dateFormatter.string(from: endDate)
            
            // Determine account type for OFX
            let ofxAccountType = ofxAccountType(for: account)
            
            ofxContent += """
            <STMTTRNRS>
            <TRNUID>\(UUID().uuidString)</TRNUID>
            <STATUS>
            <CODE>0</CODE>
            <SEVERITY>INFO</SEVERITY>
            </STATUS>
            <STMTRS>
            <CURDEF>\(account.currency)</CURDEF>
            <BANKACCTFROM>
            <BANKID>CASH</BANKID>
            <ACCTID>\(account.id.uuidString)</ACCTID>
            <ACCTTYPE>\(ofxAccountType)</ACCTTYPE>
            </BANKACCTFROM>
            <BANKTRANLIST>
            <DTSTART>\(dtStart)</DTSTART>
            <DTEND>\(dtEnd)</DTEND>
            
            """
            
            // Add transactions for this account
            for (transaction, entry) in sortedTransactions {
                let transactionDate = dateFormatter.string(from: transaction.date)
                
                // Calculate the signed amount based on entry type and account class
                let signedAmount = calculateSignedAmount(entry: entry, account: account)
                let amountString = formatDecimalForOFX(signedAmount)
                
                // Determine OFX transaction type
                let trnType = ofxTransactionType(signedAmount: signedAmount, entry: entry)
                
                // Escape special characters in description
                let escapedDescription = escapeXML(transaction.descriptionText)
                let escapedMemo = escapeXML(transaction.reference)
                
                ofxContent += """
                <STMTTRN>
                <TRNTYPE>\(trnType)</TRNTYPE>
                <DTPOSTED>\(transactionDate)</DTPOSTED>
                <TRNAMT>\(amountString)</TRNAMT>
                <FITID>\(entry.id.uuidString)</FITID>
                <NAME>\(escapedDescription)</NAME>
                <MEMO>\(escapedMemo)</MEMO>
                </STMTTRN>
                
                """
            }
            
            // Calculate ledger balance
            let ledgerBalance = account.balance
            let ledgerBalanceString = formatDecimalForOFX(ledgerBalance)
            
            ofxContent += """
            </BANKTRANLIST>
            <LEDGERBAL>
            <BALAMT>\(ledgerBalanceString)</BALAMT>
            <DTASOF>\(dtServer)</DTASOF>
            </LEDGERBAL>
            </STMTRS>
            </STMTTRNRS>
            
            """
        }
        
        ofxContent += """
        </BANKMSGSRSV1>
        </OFX>
        """
        
        guard let data = ofxContent.data(using: .utf8) else {
            throw DataExporterError.encodingFailed
        }
        
        return data
    }
    
    // MARK: - OFX Helper Methods
    
    private static func ofxAccountType(for account: Account) -> String {
        switch account.accountType {
        case .creditCard:
            return "CREDITLINE"
        case .investment:
            return "MONEYMRKT"
        case .cash:
            return "CHECKING"
        default:
            if account.accountClass == .liability {
                return "CREDITLINE"
            }
            return "CHECKING"
        }
    }
    
    private static func calculateSignedAmount(entry: Entry, account: Account) -> Decimal {
        // For OFX, positive amounts are money coming IN, negative are money going OUT
        // Assets (debit normal): debit increases (money in), credit decreases (money out)
        // Liabilities (credit normal): credit increases (debt up), debit decreases (debt down)
        
        if account.accountClass.normalBalance == .debit {
            // Asset accounts: debit = positive (money in), credit = negative (money out)
            return entry.entryType == .debit ? entry.amount : -entry.amount
        } else {
            // Liability accounts: credit = positive (debt increase), debit = negative (debt decrease)
            return entry.entryType == .credit ? entry.amount : -entry.amount
        }
    }
    
    private static func ofxTransactionType(signedAmount: Decimal, entry: Entry) -> String {
        if signedAmount >= 0 {
            return "CREDIT"
        } else {
            return "DEBIT"
        }
    }
    
    private static func formatDecimalForOFX(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        return formatter.string(from: decimal as NSDecimalNumber) ?? "0.00"
    }
    
    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    // MARK: - Import Cash Backup (JSON + LZFSE)
    
    static func importCashBackup(from data: Data, into context: ModelContext) throws -> (accountsCount: Int, transactionsCount: Int) {
        guard let decompressedData = try? (data as NSData).decompressed(using: .lzfse) as Data else {
            throw DataExporterError.decompressionFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let exportData = try? decoder.decode(ExportableData.self, from: decompressedData) else {
            throw DataExporterError.decodingFailed
        }
        
        return try importExportableData(exportData, into: context)
    }
    
    // MARK: - Import Helper
    
    private static func importExportableData(_ exportData: ExportableData, into context: ModelContext) throws -> (accountsCount: Int, transactionsCount: Int) {
        // Create a mapping from old UUIDs to new accounts
        var accountMapping: [UUID: Account] = [:]
        
        // Import accounts
        for exportedAccount in exportData.accounts {
            let account = Account(
                name: exportedAccount.name,
                accountNumber: exportedAccount.accountNumber,
                currency: exportedAccount.currency,
                accountClass: AccountClass(rawValue: exportedAccount.accountClass) ?? .asset,
                accountType: AccountType(rawValue: exportedAccount.accountType) ?? .bank,
                isActive: exportedAccount.isActive,
                isSystem: exportedAccount.isSystem
            )
            // Preserve original ID and dates
            account.id = exportedAccount.id
            account.createdAt = exportedAccount.createdAt
            
            context.insert(account)
            accountMapping[exportedAccount.id] = account
        }
        
        // Import transactions
        for exportedTransaction in exportData.transactions {
            let transaction = Transaction(
                date: exportedTransaction.date,
                descriptionText: exportedTransaction.descriptionText,
                reference: exportedTransaction.reference,
                isRecurring: exportedTransaction.isRecurring
            )
            transaction.id = exportedTransaction.id
            transaction.createdAt = exportedTransaction.createdAt
            
            context.insert(transaction)
            
            // Import entries
            for exportedEntry in exportedTransaction.entries {
                guard let account = accountMapping[exportedEntry.accountId] else {
                    throw DataExporterError.importFailed("Account not found for entry")
                }
                
                let entry = Entry(
                    entryType: EntryType(rawValue: exportedEntry.entryType) ?? .debit,
                    amount: Decimal(string: exportedEntry.amount) ?? 0,
                    account: account
                )
                entry.id = exportedEntry.id
                entry.transaction = transaction
                
                context.insert(entry)
            }
            
            // Import attachments
            for exportedAttachment in exportedTransaction.attachments {
                guard let attachmentData = Data(base64Encoded: exportedAttachment.data) else {
                    continue
                }
                
                let attachment = Attachment(
                    filename: exportedAttachment.filename,
                    mimeType: exportedAttachment.mimeType,
                    data: attachmentData
                )
                attachment.id = exportedAttachment.id
                attachment.createdAt = exportedAttachment.createdAt
                attachment.transaction = transaction
                
                context.insert(attachment)
            }
            
            // Import recurrence rule
            if let exportedRule = exportedTransaction.recurrenceRule {
                let rule = RecurrenceRule(
                    frequency: RecurrenceFrequency(rawValue: exportedRule.frequency) ?? .monthly,
                    interval: exportedRule.interval,
                    dayOfMonth: exportedRule.dayOfMonth,
                    dayOfWeek: exportedRule.dayOfWeek,
                    monthOfYear: exportedRule.monthOfYear,
                    weekendAdjustment: WeekendAdjustment(rawValue: exportedRule.weekendAdjustment) ?? .none,
                    startDate: exportedRule.startDate,
                    endDate: exportedRule.endDate
                )
                rule.id = exportedRule.id
                rule.nextOccurrence = exportedRule.nextOccurrence
                rule.isActive = exportedRule.isActive
                rule.transaction = transaction
                
                context.insert(rule)
            }
        }
        
        try context.save()
        
        return (exportData.accounts.count, exportData.transactions.count)
    }
    
    // MARK: - Generate Filename
    
    static func generateFilename(for format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        return "Cash_Export_\(dateString).\(format.fileExtension)"
    }
}
