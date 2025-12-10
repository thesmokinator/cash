//
//  SyncStatusView.swift
//  Cash
//
//  Created by Michele Broggi on 05/12/25.
//

import SwiftUI

// MARK: - Sync Status Indicator

/// A compact sync status indicator for the toolbar
struct SyncStatusIndicator: View {
    @State private var cloudManager = CloudKitManager.shared
    @State private var showingPopover = false
    
    var body: some View {
        if cloudManager.shouldShowSyncIndicator {
            Button {
                showingPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    syncIcon
                    
                    if case .syncing = cloudManager.syncState {
                        Text("Syncing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.5))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
                SyncStatusPopover()
                    .frame(width: 280)
            }
            .onAppear {
                cloudManager.startListeningForRemoteChanges()
            }
        }
    }
    
    @ViewBuilder
    private var syncIcon: some View {
        switch cloudManager.syncState {
        case .idle:
            Image(systemName: "icloud")
                .foregroundStyle(.secondary)
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .foregroundStyle(.blue)
                .symbolEffect(.rotate, isActive: true)
        case .synced:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Sync Status Popover

struct SyncStatusPopover: View {
    @State private var cloudManager = CloudKitManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "icloud.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                statusBadge
            }
            
            Divider()
            
            // Last sync info
            if let lastSync = cloudManager.lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("Last synced: \(lastSync.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Error message if any
            if case .error(let message) = cloudManager.syncState {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Retry button if error
            if case .error = cloudManager.syncState {
                Button {
                    cloudManager.checkSyncStatus()
                } label: {
                    Label("Retry Sync", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    private var statusText: String {
        switch cloudManager.syncState {
        case .idle:
            return String(localized: "Ready")
        case .syncing:
            return String(localized: "Syncing with iCloud...")
        case .synced:
            return String(localized: "Up to date")
        case .error:
            return String(localized: "Sync issue")
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch cloudManager.syncState {
        case .idle:
            Circle()
                .fill(.secondary)
                .frame(width: 8, height: 8)
        case .syncing:
            ProgressView()
                .scaleEffect(0.6)
        case .synced:
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        case .error:
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Sidebar Sync Status Box

/// A compact sync status box for the sidebar bottom
struct SidebarSyncStatusBox: View {
    @State private var cloudManager = CloudKitManager.shared
    
    var body: some View {
        if cloudManager.shouldShowSyncIndicator {
            HStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    syncIcon
                }
                
                // Status info
                VStack(alignment: .leading, spacing: 3) {
                    Text("iCloud Sync")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Last sync or error
                    if case .error(let message) = cloudManager.syncState {
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    } else if let lastSync = cloudManager.lastSyncDate {
                        Text(lastSync.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer(minLength: 0)
                
                statusPill
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .onAppear {
                cloudManager.startListeningForRemoteChanges()
            }
        }
    }
    
    private var iconBackgroundColor: Color {
        switch cloudManager.syncState {
        case .idle: return .secondary
        case .syncing: return .blue
        case .synced: return .green
        case .error: return .orange
        }
    }
    
    @ViewBuilder
    private var syncIcon: some View {
        Group {
            switch cloudManager.syncState {
            case .idle:
                Image(systemName: "icloud")
                    .foregroundStyle(.secondary)
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                    .foregroundStyle(.blue)
                    .symbolEffect(.rotate, isActive: true)
            case .synced:
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 16, weight: .medium))
    }
    
    @ViewBuilder
    private var statusPill: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(pillTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pillBackgroundColor.opacity(0.15))
            .clipShape(Capsule())
    }
    
    private var statusText: String {
        switch cloudManager.syncState {
        case .idle: return String(localized: "Ready")
        case .syncing: return String(localized: "Syncing")
        case .synced: return String(localized: "Synced")
        case .error: return String(localized: "Error")
        }
    }
    
    private var pillTextColor: Color {
        switch cloudManager.syncState {
        case .idle: return .secondary
        case .syncing: return .blue
        case .synced: return .green
        case .error: return .orange
        }
    }
    
    private var pillBackgroundColor: Color {
        switch cloudManager.syncState {
        case .idle: return .secondary
        case .syncing: return .blue
        case .synced: return .green
        case .error: return .orange
        }
    }
}

#Preview("Sidebar Sync Box") {
    SidebarSyncStatusBox()
        .frame(width: 280)
}
