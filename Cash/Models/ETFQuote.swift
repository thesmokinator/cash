//
//  ETFQuote.swift
//  Cash
//
//  Created by Michele Broggi on 27/12/25.
//

import Foundation

// MARK: - ETF Quote Model

struct ETFQuote: Codable {
    let latestQuote: QuoteValue
    let latestQuoteDate: String
    let previousQuote: QuoteValue?
    let previousQuoteDate: String?
    let dtdPrc: QuoteValue?
    let dtdAmt: QuoteValue?
    let quoteTradingVenue: String?
    let quoteLowHigh: LowHigh?

    struct QuoteValue: Codable {
        let raw: Decimal
        let localized: String
    }

    struct LowHigh: Codable {
        let low: QuoteValue
        let high: QuoteValue
    }

    // Computed property to get DateComponents from date string
    var latestQuoteDateComponents: DateComponents? {
        parseDate(latestQuoteDate)
    }

    var previousQuoteDateComponents: DateComponents? {
        previousQuoteDate.flatMap { parseDate($0) }
    }

    private func parseDate(_ dateString: String) -> DateComponents? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            return calendar.dateComponents([.year, .month, .day], from: date)
        }
        return nil
    }
}