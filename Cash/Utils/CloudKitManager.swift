//
//  CloudKitManager.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import Foundation

#if ENABLE_ICLOUD
import CloudKit
#endif

@Observable
final class CloudKitManager {
    static let shared = CloudKitManager()
    
    private let iCloudEnabledKey = "iCloudSyncEnabled"
    let containerIdentifier = "iCloud.com.thesmokinator.Cash"
    
    /// Whether iCloud feature is available in this build
    var isFeatureEnabled: Bool {
        #if ENABLE_ICLOUD
        return true
        #else
        return false
        #endif
    }
    
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: iCloudEnabledKey)
            if isEnabled != oldValue {
                needsRestart = true
            }
        }
    }
    
    var needsRestart: Bool = false
    
    var isAvailable: Bool {
        #if ENABLE_ICLOUD
        return FileManager.default.ubiquityIdentityToken != nil
        #else
        return false
        #endif
    }
    
    #if ENABLE_ICLOUD
    var accountStatus: CKAccountStatus = .couldNotDetermine
    #else
    var accountStatus: Int = 0
    #endif
    
    var storageUsed: Int64 = 0
    var isLoadingStorage: Bool = false
    
    private init() {
        #if ENABLE_ICLOUD
        self.isEnabled = UserDefaults.standard.bool(forKey: iCloudEnabledKey)
        #else
        self.isEnabled = false
        #endif
    }
    
    func checkAccountStatus() async {
        #if ENABLE_ICLOUD
        guard isAvailable else {
            await MainActor.run {
                self.accountStatus = .noAccount
            }
            return
        }
        
        do {
            let container = CKContainer(identifier: containerIdentifier)
            let status = try await container.accountStatus()
            await MainActor.run {
                self.accountStatus = status
            }
        } catch {
            await MainActor.run {
                self.accountStatus = .couldNotDetermine
            }
        }
        #endif
    }
    
    func fetchStorageUsed() async {
        guard isEnabled else {
            await MainActor.run {
                self.storageUsed = 0
            }
            return
        }
        
        await MainActor.run {
            self.isLoadingStorage = true
        }
        
        let fileManager = FileManager.default
        
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let storeURL = appSupport.appendingPathComponent("default.store")
            var totalSize: Int64 = 0
            
            let storeFiles = [
                storeURL,
                storeURL.appendingPathExtension("shm"),
                storeURL.appendingPathExtension("wal")
            ]
            
            for url in storeFiles {
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            }
            
            await MainActor.run {
                self.storageUsed = totalSize
                self.isLoadingStorage = false
            }
        } else {
            await MainActor.run {
                self.storageUsed = 0
                self.isLoadingStorage = false
            }
        }
    }
    
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file)
    }
    
    var accountStatusDescription: String {
        #if ENABLE_ICLOUD
        switch accountStatus {
        case .available:
            return String(localized: "iCloud account available")
        case .noAccount:
            return String(localized: "No iCloud account")
        case .restricted:
            return String(localized: "iCloud access restricted")
        case .couldNotDetermine:
            return String(localized: "Unable to determine iCloud status")
        case .temporarilyUnavailable:
            return String(localized: "iCloud temporarily unavailable")
        @unknown default:
            return String(localized: "Unknown iCloud status")
        }
        #else
        return String(localized: "iCloud not available in this build")
        #endif
    }
}
