//
//  ETFAPIHelper.swift
//  Cash
//
//  Created by Michele Broggi on 27/12/25.
//

import Foundation

// MARK: - ETF API Helper

class ETFAPIHelper {
    static let shared = ETFAPIHelper()

    private let baseURL = "https://www.justetf.com/api/etfs"

    func fetchQuote(isin: String, locale: String, currency: String) async throws -> ETFQuote {
        let urlString = "\(baseURL)/\(isin)/quote?locale=\(locale)&currency=\(currency)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        // The API returns JSON
        let decoder = JSONDecoder()
        let quote = try decoder.decode(ETFQuote.self, from: data)

        return quote
    }

    // Helper to get user locale
    static func getUserLocale() -> String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
}