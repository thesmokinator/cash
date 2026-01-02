//
//  CloudKitManager.swift
//  Cash
//
//  Created by Michele Broggi on 28/11/25.
//

import Combine
import CoreData
import Foundation
import SwiftData

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

    /// Model container for creating background contexts
    var modelContainer: ModelContainer?

    /// Model context for database operations (main thread only)
    var modelContext: ModelContext? {
        modelContainer?.mainContext
    }

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
        }
    }

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
    private var deduplicationTask: Task<Void, Never>?
    private var isDeduplicating = false

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

            // Schedule deduplication with debounce (2 seconds)
            scheduleDeduplication()

            // Start a new timeout for any subsequent changes
            startSyncTimeout()
        #endif
    }

    /// Schedule deduplication with debounce to avoid multiple concurrent runs
    private func scheduleDeduplication() {
        // Cancel any pending deduplication task
        deduplicationTask?.cancel()

        // Schedule new deduplication after 2 seconds debounce
        deduplicationTask = Task { @MainActor in
            // Wait 2 seconds to batch multiple sync events
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            guard !Task.isCancelled else { return }

            // Check if already deduplicating
            guard !self.isDeduplicating else {
                print("⏳ Deduplication already in progress, skipping")
                return
            }

            // Check if container is available
            guard let container = self.modelContainer else {
                print("❌ No ModelContainer available for deduplication")
                return
            }

            self.isDeduplicating = true

            // Run deduplication in background with its own context
            Task.detached(priority: .background) {
                let backgroundContext = ModelContext(container)
                await self.deduplicateAccounts(in: backgroundContext)

                await MainActor.run {
                    self.isDeduplicating = false
                }
            }
        }
    }

    /// Start a timeout that marks sync as complete if no changes received
    private func startSyncTimeout() {
        syncTimeoutTask?.cancel()
        syncTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds

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

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        {
            let storeURL = appSupport.appendingPathComponent("default.store")
            var totalSize: Int64 = 0

            let storeFiles = [
                storeURL,
                storeURL.appendingPathExtension("shm"),
                storeURL.appendingPathExtension("wal"),
            ]

            for url in storeFiles {
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                    let size = attrs[.size] as? Int64
                {
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

    // MARK: - Account Deduplication

    /// Deduplicate accounts with the same name, type, class, and currency
    /// Merges transactions from duplicate accounts into the primary account
    func deduplicateAccounts(in context: ModelContext) {

        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let allAccounts = try? context.fetch(descriptor) else {
            print("❌ Failed to fetch accounts for deduplication")
            return
        }


        // Group accounts by deduplication key
        var accountGroups: [String: [Account]] = [:]

        for account in allAccounts {
            let key =
                "\(account.name)|\(account.accountTypeRawValue)|\(account.accountClassRawValue)|\(account.currency)"
            accountGroups[key, default: []].append(account)
        }

        var totalDuplicatesRemoved = 0

        // Process each group with duplicates
        for (key, accounts) in accountGroups where accounts.count > 1 {
            print("🔍 Found \(accounts.count) duplicate accounts for key: \(key)")

            // Sort by creation date, keep the oldest as primary
            let sortedAccounts = accounts.sorted { $0.createdAt < $1.createdAt }
            let primaryAccount = sortedAccounts[0]
            let duplicateAccounts = Array(sortedAccounts[1...])

            print(
                "✅ Keeping primary account: \(primaryAccount.name) (created: \(primaryAccount.createdAt))"
            )
            print("🗑️ Removing \(duplicateAccounts.count) duplicates")

            // Merge entries from duplicates to primary
            for duplicate in duplicateAccounts {
                if let duplicateEntries = duplicate.entries {
                    for entry in duplicateEntries {
                        entry.account = primaryAccount
                    }
                    print("📝 Moved \(duplicateEntries.count) entries from duplicate to primary")
                }
            }

            // Delete duplicate accounts
            for duplicate in duplicateAccounts {
                context.delete(duplicate)
                totalDuplicatesRemoved += 1
            }
        }

        if totalDuplicatesRemoved > 0 {
            print("✅ Deduplication complete: removed \(totalDuplicatesRemoved) duplicate accounts")
        }

        // Save changes
        do {
            try context.save()
        } catch {
            print("❌ Failed to save deduplication changes: \(error)")
        }

        // Post notification to recalculate account balances
        NotificationCenter.default.post(
            name: .accountBalancesNeedUpdate, object: nil, userInfo: nil)
    }
}
