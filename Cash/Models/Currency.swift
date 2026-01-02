//
//  Currency.swift
//  Cash
//
//  Created by Michele Broggi on 25/11/25.
//

import Foundation

struct CurrencyInfo: Identifiable, Hashable {
    let code: String
    let name: String
    let symbol: String
    
    var id: String { code }
    
    var displayName: String {
        "\(name) (\(symbol))"
    }
}

struct CurrencyList {
    static let currencies: [CurrencyInfo] = [
        CurrencyInfo(code: "USD", name: "US Dollar", symbol: "$"),
        CurrencyInfo(code: "EUR", name: "Euro", symbol: "€"),
        CurrencyInfo(code: "GBP", name: "British Pound", symbol: "£"),
        CurrencyInfo(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        CurrencyInfo(code: "CHF", name: "Swiss Franc", symbol: "CHF"),
        CurrencyInfo(code: "CAD", name: "Canadian Dollar", symbol: "CA$"),
        CurrencyInfo(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        CurrencyInfo(code: "CNY", name: "Chinese Yuan", symbol: "¥"),
        CurrencyInfo(code: "INR", name: "Indian Rupee", symbol: "₹"),
        CurrencyInfo(code: "BRL", name: "Brazilian Real", symbol: "R$"),
        CurrencyInfo(code: "MXN", name: "Mexican Peso", symbol: "MX$"),
        CurrencyInfo(code: "KRW", name: "South Korean Won", symbol: "₩"),
        CurrencyInfo(code: "SEK", name: "Swedish Krona", symbol: "kr"),
        CurrencyInfo(code: "NOK", name: "Norwegian Krone", symbol: "kr"),
        CurrencyInfo(code: "DKK", name: "Danish Krone", symbol: "kr"),
        CurrencyInfo(code: "PLN", name: "Polish Zloty", symbol: "zł"),
        CurrencyInfo(code: "RUB", name: "Russian Ruble", symbol: "₽"),
        CurrencyInfo(code: "ZAR", name: "South African Rand", symbol: "R"),
        CurrencyInfo(code: "SGD", name: "Singapore Dollar", symbol: "S$"),
        CurrencyInfo(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$"),
        CurrencyInfo(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$"),
    ]
    
    static func currency(forCode code: String) -> CurrencyInfo? {
        currencies.first { $0.code == code }
    }
    
    static func symbol(forCode code: String) -> String {
        currency(forCode: code)?.symbol ?? code
    }
}
