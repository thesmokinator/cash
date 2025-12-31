//
//  AppConfiguration.swift
//  Cash
//
//  Created by Michele Broggi on 27/11/25.
//

import Foundation
import SwiftData

@Model
final class AppConfiguration {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    init() {
        self.id = UUID()
        self.createdAt = Date()
    }

    // MARK: - Static Helpers

    /// Get or create the singleton configuration
    static func getOrCreate(in context: ModelContext) -> AppConfiguration {
        let descriptor = FetchDescriptor<AppConfiguration>()

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let config = AppConfiguration()
        context.insert(config)
        return config
    }
}
