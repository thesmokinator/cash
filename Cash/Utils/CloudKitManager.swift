//
//  CloudKitManager.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import Foundation
import SwiftData
import Combine
import CoreData

#if ENABLE_ICLOUD
import CloudKit
#endif

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing
    case synced(Date)
    case error(String)
    
    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}

// MARK: - CloudKit Manager

@Observable
final class CloudKitManager {
    static let shared = CloudKitManager()
    
    private let iCloudEnabledKey = "iCloudSyncEnabled"
    private let lastSyncKey = "lastCloudKitSync"
    let containerIdentifier = "iCloud.com.thesmokinator.Cash"
    
    /// Current sync state
    var syncState: SyncState = .idle
    
    /// Last successful sync date
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncKey) }
    }
    
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
        let available = FileManager.default.ubiquityIdentityToken != nil
        if !available {
            print("⚠️ CloudKit unavailable: ubiquityIdentityToken is nil")
        }
        return available
        #else
        return false
        #endif
    }
    
    /// Whether sync indicator should be shown
    var shouldShowSyncIndicator: Bool {
        // Show indicator if: iCloud is enabled in build AND user has enabled it in settings
        isFeatureEnabled && isEnabled
    }
    
    #if ENABLE_ICLOUD
    var accountStatus: CKAccountStatus = .couldNotDetermine
    #else
    var accountStatus: Int = 0
    #endif
    
    var storageUsed: Int64 = 0
    var isLoadingStorage: Bool = false
    
    private var remoteChangeObserver: NSObjectProtocol?
    private var syncTimeoutTask: Task<Void, Never>?
    
    private init() {
        #if ENABLE_ICLOUD
        self.isEnabled = UserDefaults.standard.bool(forKey: iCloudEnabledKey)
        
        // Restore last sync date if available
        if let lastSync = lastSyncDate {
            syncState = .synced(lastSync)
        }
        #else
        self.isEnabled = false
        #endif
    }
    
    deinit {
        stopListeningForRemoteChanges()
    }
    
    // MARK: - Sync Monitoring
    
    /// Start listening for remote CloudKit changes
    func startListeningForRemoteChanges() {
        #if ENABLE_ICLOUD
        guard isEnabled && isAvailable else { return }
        
        // Remove existing observer if any
        stopListeningForRemoteChanges()
        
        // Set initial syncing state
        syncState = .syncing
        
        // Listen for remote store changes
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }
        
        // Set a timeout - if no sync happens within 10 seconds, assume we're synced
        startSyncTimeout()
        #endif
    }
    
    /// Stop listening for remote changes
    func stopListeningForRemoteChanges() {
        if let observer = remoteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            remoteChangeObserver = nil
        }
        syncTimeoutTask?.cancel()
        syncTimeoutTask = nil
    }
    
    /// Handle a remote change notification
    private func handleRemoteChange() {
        #if ENABLE_ICLOUD
        // Cancel any pending timeout
        syncTimeoutTask?.cancel()
        
        // Mark as synced
        let now = Date()
        lastSyncDate = now
        syncState = .synced(now)
        
        // Start a new timeout for any subsequent changes
        startSyncTimeout()
        #endif
    }
    
    /// Start a timeout that marks sync as complete if no changes received
    private func startSyncTimeout() {
        syncTimeoutTask?.cancel()
        syncTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            guard !Task.isCancelled else { return }
            
            // If still syncing after timeout, assume we're done
            if case .syncing = self.syncState {
                let now = Date()
                self.lastSyncDate = now
                self.syncState = .synced(now)
            }
        }
    }
    
    /// Manually trigger a sync check (useful after app becomes active)
    func checkSyncStatus() {
        #if ENABLE_ICLOUD
        guard isEnabled && isAvailable else {
            syncState = .idle
            return
        }
        
        // Briefly show syncing state
        syncState = .syncing
        startSyncTimeout()
        #endif
    }
    
    /// Report a sync error
    func reportSyncError(_ message: String) {
        syncState = .error(message)
        
        // Auto-clear error after 10 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if case .error = self.syncState {
                if let lastSync = self.lastSyncDate {
                    self.syncState = .synced(lastSync)
                } else {
                    self.syncState = .idle
                }
            }
        }
    }
    
    func checkAccountStatus() async {
        #if ENABLE_ICLOUD
        guard FileManager.default.ubiquityIdentityToken != nil else {
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
