//
//  OFXParser.swift
//  Cash
//
//  Created by Michele Broggi on 27/11/25.
//

import Foundation

/// Represents a parsed OFX transaction
struct OFXTransaction: Identifiable {
    let id = UUID()
    let fitId: String          // Financial Institution Transaction ID
    let type: OFXTransactionType
    let datePosted: Date
    let amount: Decimal
    let name: String           // Payee/description
    let memo: String?
    
    var isExpense: Bool {
        amount < 0
    }
    
    var absoluteAmount: Decimal {
        abs(amount)
    }
}

enum OFXTransactionType: String {
    case credit = "CREDIT"
    case debit = "DEBIT"
    case interest = "INT"
    case dividend = "DIV"
    case fee = "FEE"
    case serviceCharge = "SRVCHG"
    case deposit = "DEP"
    case atm = "ATM"
    case pos = "POS"
    case transfer = "XFER"
    case check = "CHECK"
    case payment = "PAYMENT"
    case cash = "CASH"
    case directDeposit = "DIRECTDEP"
    case directDebit = "DIRECTDEBIT"
    case repeatPayment = "REPEATPMT"
    case other = "OTHER"
    
    init(rawValue: String) {
        switch rawValue.uppercased() {
        case "CREDIT": self = .credit
        case "DEBIT": self = .debit
        case "INT": self = .interest
        case "DIV": self = .dividend
        case "FEE": self = .fee
        case "SRVCHG": self = .serviceCharge
        case "DEP": self = .deposit
        case "ATM": self = .atm
        case "POS": self = .pos
        case "XFER": self = .transfer
        case "CHECK": self = .check
        case "PAYMENT": self = .payment
        case "CASH": self = .cash
        case "DIRECTDEP": self = .directDeposit
        case "DIRECTDEBIT": self = .directDebit
        case "REPEATPMT": self = .repeatPayment
        default: self = .other
        }
    }
}

/// Parser for OFX (Open Financial Exchange) files
class OFXParser {
    
    enum OFXError: LocalizedError {
        case invalidFormat
        case noTransactions
        case parseError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return String(localized: "Invalid OFX file format")
            case .noTransactions:
                return String(localized: "No transactions found in the file")
            case .parseError(let message):
                return String(localized: "Parse error: \(message)")
            }
        }
    }
    
    /// Parse OFX file data and extract transactions
    static func parse(data: Data) throws -> [OFXTransaction] {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw OFXError.invalidFormat
        }
        
        return try parse(content: content)
    }
    
    /// Parse OFX content string
    static func parse(content: String) throws -> [OFXTransaction] {
        var transactions: [OFXTransaction] = []
        
        // Find all STMTTRN blocks (Statement Transactions)
        let stmttrnPattern = "<STMTTRN>([\\s\\S]*?)</STMTTRN>"
        let stmttrnRegex = try? NSRegularExpression(pattern: stmttrnPattern, options: .caseInsensitive)
        
        // Also try SGML style (no closing tags)
        let sgmlPattern = "<STMTTRN>([\\s\\S]*?)(?=<STMTTRN>|</BANKTRANLIST>|</STMTRS>|$)"
        let sgmlRegex = try? NSRegularExpression(pattern: sgmlPattern, options: .caseInsensitive)
        
        let range = NSRange(content.startIndex..., in: content)
        
        // Try XML style first
        var matches = stmttrnRegex?.matches(in: content, options: [], range: range) ?? []
        
        // If no matches, try SGML style
        if matches.isEmpty {
            matches = sgmlRegex?.matches(in: content, options: [], range: range) ?? []
        }
        
        for match in matches {
            if let transactionRange = Range(match.range(at: 1), in: content) {
                let transactionBlock = String(content[transactionRange])
                if let transaction = parseTransaction(block: transactionBlock) {
                    transactions.append(transaction)
                }
            }
        }
        
        if transactions.isEmpty {
            throw OFXError.noTransactions
        }
        
        return transactions.sorted { $0.datePosted > $1.datePosted }
    }
    
    /// Parse a single transaction block
    private static func parseTransaction(block: String) -> OFXTransaction? {
        let type = extractValue(tag: "TRNTYPE", from: block) ?? "OTHER"
        let dateString = extractValue(tag: "DTPOSTED", from: block) ?? ""
        let amountString = extractValue(tag: "TRNAMT", from: block) ?? "0"
        let fitId = extractValue(tag: "FITID", from: block) ?? UUID().uuidString
        let name = extractValue(tag: "NAME", from: block) ?? extractValue(tag: "PAYEE", from: block) ?? "Unknown"
        let memo = extractValue(tag: "MEMO", from: block)
        
        guard let date = parseOFXDate(dateString) else { return nil }
        
        // Parse amount (handle both . and , as decimal separator)
        var cleanedAmount = amountString
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        
        // Handle negative sign and comma
        let isNegative = cleanedAmount.hasPrefix("-")
        if isNegative {
            cleanedAmount = String(cleanedAmount.dropFirst())
        }
        cleanedAmount = cleanedAmount.replacingOccurrences(of: ",", with: ".")
        
        guard var amount = Decimal(string: cleanedAmount) else { return nil }
        if isNegative {
            amount = -amount
        }
        
        return OFXTransaction(
            fitId: fitId,
            type: OFXTransactionType(rawValue: type),
            datePosted: date,
            amount: amount,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            memo: memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    /// Extract value for a tag from OFX content
    private static func extractValue(tag: String, from content: String) -> String? {
        // Try XML style: <TAG>value</TAG>
        let xmlPattern = "<\(tag)>([^<]*)</\(tag)>"
        if let regex = try? NSRegularExpression(pattern: xmlPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            return String(content[range])
        }
        
        // Try SGML style: <TAG>value (no closing tag)
        let sgmlPattern = "<\(tag)>([^<\\n\\r]*)"
        if let regex = try? NSRegularExpression(pattern: sgmlPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            return String(content[range])
        }
        
        return nil
    }
    
    /// Parse OFX date format (YYYYMMDD or YYYYMMDDHHMMSS)
    private static func parseOFXDate(_ dateString: String) -> Date? {
        let cleanDate = dateString.prefix(8) // Take first 8 characters (YYYYMMDD)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone.current
        
        return formatter.date(from: String(cleanDate))
    }
}
