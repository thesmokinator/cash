//
//  CustomTabBar.swift
//  Cash
//
//  Custom Tab Bar with Glassmorphism style and central Add button
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    let onAddTapped: () -> Void

    @State private var addButtonScale: CGFloat = 1.0

    private let tabBarHeight: CGFloat = 80
    private let addButtonSize: CGFloat = 60

    var body: some View {
        ZStack {
            // Background blur
            tabBarBackground

            // Tab items
            HStack(spacing: 0) {
                ForEach(MainTab.allCases) { tab in
                    if tab == .add {
                        // Center add button
                        addButton
                    } else {
                        tabButton(for: tab)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 20) // Account for safe area
        }
        .frame(height: tabBarHeight + 20)
    }

    // MARK: - Tab Bar Background

    private var tabBarBackground: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(CashColors.tabBarBackground)
                .frame(height: tabBarHeight)
                .clipShape(
                    .rect(
                        topLeadingRadius: 24,
                        topTrailingRadius: 24
                    )
                )
                .shadow(
                    color: CashColors.primaryDark.opacity(0.3),
                    radius: 12,
                    x: 0,
                    y: -4
                )
        }
    }

    // MARK: - Tab Button

    private func tabButton(for tab: MainTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            // Haptic feedback
            HapticFeedback.light()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))
                    .symbolEffect(.bounce, value: selectedTab == tab)

                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
            }
            .foregroundColor(selectedTab == tab ? CashColors.tabBarSelected : CashColors.tabBarUnselected)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                addButtonScale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    addButtonScale = 1.0
                }
            }
            // Haptic feedback
            HapticFeedback.medium()
            onAddTapped()
        } label: {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0)
                            ],
                            center: .center,
                            startRadius: addButtonSize / 2 - 5,
                            endRadius: addButtonSize / 2 + 10
                        )
                    )
                    .frame(width: addButtonSize + 20, height: addButtonSize + 20)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: addButtonSize, height: addButtonSize)
                    .shadow(
                        color: CashColors.primaryDark.opacity(0.4),
                        radius: 8,
                        x: 0,
                        y: 4
                    )

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(CashColors.primary)
            }
            .scaleEffect(addButtonScale)
        }
        .buttonStyle(.plain)
        .offset(y: -20) // Float above the tab bar
    }
}

// MARK: - Compact Tab Bar (Alternative simpler version)

struct CompactTabBar: View {
    @Binding var selectedTab: MainTab
    let onAddTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                if tab == .add {
                    compactAddButton
                } else {
                    compactTabItem(for: tab)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(CashColors.primary.opacity(0.9))
        .clipShape(Capsule())
        .shadow(
            color: CashColors.primary.opacity(0.3),
            radius: 12,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private func compactTabItem(for tab: MainTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var compactAddButton: some View {
        Button {
            onAddTapped()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(CashColors.primary)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        CashColors.backgroundGradient
            .ignoresSafeArea()

        VStack {
            Spacer()

            Text("Tab Bar Preview")
                .font(.title)

            Spacer()

            CustomTabBar(
                selectedTab: .constant(.home),
                onAddTapped: {}
            )
        }
    }
}
