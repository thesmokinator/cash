//
//  IOSCardComponents.swift
//  Cash
//
//  Created on 28/12/25.
//

import SwiftUI

// MARK: - Header Row Component

struct HeaderRow: View {
    let label: LocalizedStringKey
    let value: String
    var valueColor: Color = .primary
    var valueWeight: Font.Weight = .semibold
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.title3)
                .fontWeight(valueWeight)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let label: LocalizedStringKey
    let value: String
    var valueColor: Color = .primary
    var labelFont: Font = .caption
    var valueFont: Font = .body
    
    var body: some View {
        HStack {
            Text(label)
                .font(labelFont)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(valueFont)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - List Card Component

struct ListCard<Header: View, Content: View>: View {
    let header: Header
    let content: Content
    
    init(@ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.header = header()
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            content
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.caption)
            Text(value)
                .font(.caption)
                .foregroundStyle(iconColor)
        }
    }
}

// MARK: - Summary Header Component

struct SummaryHeader: View {
    let title: LocalizedStringKey
    let items: [(label: LocalizedStringKey, value: String)]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HeaderRow(label: item.label, value: item.value)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}
