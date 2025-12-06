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
    var needsSetup: Bool = true
    var createdAt: Date = Date()
    
    init(needsSetup: Bool = true) {
        self.id = UUID()
        self.needsSetup = needsSetup
        self.createdAt = Date()
    }
    
    // MARK: - Static Helpers
    
    /// Get or create the singleton configuration
    static func getOrCreate(in context: ModelContext) -> AppConfiguration {
        let descriptor = FetchDescriptor<AppConfiguration>()
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // First launch - create with needsSetup = true
        let config = AppConfiguration(needsSetup: true)
        context.insert(config)
        return config
    }
    
    /// Check if setup is needed (no config exists or needsSetup is true)
    static func isSetupNeeded(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<AppConfiguration>()
        
        guard let config = try? context.fetch(descriptor).first else {
            // No configuration exists = first launch
            return true
        }
        
        return config.needsSetup
    }
    
    /// Mark setup as completed
    static func markSetupCompleted(in context: ModelContext) {
        let config = getOrCreate(in: context)
        config.needsSetup = false
    }
    
    /// Mark that setup is needed (after erase)
    static func markSetupNeeded(in context: ModelContext) {
        let config = getOrCreate(in: context)
        config.needsSetup = true
    }
}
