//
//  GlassComponents.swift
//  Cash
//
//  Reusable Glassmorphism UI Components
//

import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = CashRadius.large
    var padding: CGFloat = CashSpacing.lg

    init(
        cornerRadius: CGFloat = CashRadius.large,
        padding: CGFloat = CashSpacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: CashShadow.light.color,
                radius: CashShadow.light.radius,
                x: CashShadow.light.x,
                y: CashShadow.light.y
            )
    }
}

// MARK: - Glass Metric Card

struct GlassMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    var subtitle: String? = nil
    var valueColor: Color = .primary
    var iconColor: Color = CashColors.primary
    var isPrivate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: CashSpacing.sm) {
            HStack(spacing: CashSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.15))
                    .clipShape(Circle())

                Text(title)
                    .font(CashTypography.subheadline)
                    .foregroundColor(.secondary)
            }

            PrivacyAmountView(
                amount: value,
                isPrivate: isPrivate,
                font: CashTypography.amount,
                fontWeight: .semibold,
                color: valueColor
            )

            if let subtitle = subtitle, !isPrivate {
                Text(subtitle)
                    .font(CashTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CashSpacing.lg)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: CashRadius.large))
        .shadow(
            color: CashShadow.light.color,
            radius: CashShadow.light.radius,
            x: CashShadow.light.x,
            y: CashShadow.light.y
        )
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    let title: LocalizedStringKey
    var action: (() -> Void)? = nil
    var actionLabel: LocalizedStringKey? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(CashTypography.headline)
                .foregroundColor(.primary)

            Spacer()

            if let action = action, let actionLabel = actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(CashTypography.subheadline)
                        .foregroundColor(CashColors.primary)
                }
            }
        }
        .padding(.horizontal, CashSpacing.lg)
        .padding(.vertical, CashSpacing.sm)
    }
}

// MARK: - Glass List Row

struct GlassListRow<Leading: View, Trailing: View>: View {
    let leading: Leading
    let title: String
    var subtitle: String? = nil
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: CashSpacing.md) {
            leading

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CashTypography.body)
                    .foregroundColor(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(CashTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            trailing
        }
        .padding(.vertical, CashSpacing.sm)
    }
}

// MARK: - Glass Icon Circle

struct GlassIconCircle: View {
    let icon: String
    var color: Color = CashColors.primary
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(.ultraThinMaterial)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }
}

// MARK: - Glass Amount Badge

struct GlassAmountBadge: View {
    let amount: String
    var isPositive: Bool = true
    var isPrivate: Bool = false

    private var badgeColor: Color {
        isPositive ? CashColors.income : CashColors.expense
    }

    var body: some View {
        HStack(spacing: CashSpacing.xs) {
            Image(systemName: isPositive ? "arrow.down.left" : "arrow.up.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(badgeColor)

            PrivacyAmountView(
                amount: amount,
                isPrivate: isPrivate,
                font: CashTypography.amountSmall,
                fontWeight: .semibold,
                color: badgeColor
            )
        }
        .padding(.horizontal, CashSpacing.md)
        .padding(.vertical, CashSpacing.xs)
        .background(badgeColor.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Glass Progress Bar

struct GlassProgressBar: View {
    let progress: Double // 0.0 to 1.0
    var height: CGFloat = 8
    var backgroundColor: Color = Color.gray.opacity(0.2)
    var foregroundColor: Color = CashColors.primary

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(backgroundColor)
                    .frame(height: height)

                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [foregroundColor, foregroundColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * min(max(progress, 0), 1), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Glass Divider

struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 1)
    }
}

// MARK: - Glass Floating Action Button

struct GlassFloatingButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 56

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    LinearGradient(
                        colors: [CashColors.primary, CashColors.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(
                    color: CashColors.primary.opacity(0.4),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        }
    }
}

// MARK: - Glass Empty State

struct GlassEmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    var action: (() -> Void)? = nil
    var actionLabel: LocalizedStringKey? = nil

    var body: some View {
        VStack(spacing: CashSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(CashColors.primary.opacity(0.6))

            VStack(spacing: CashSpacing.sm) {
                Text(title)
                    .font(CashTypography.title3)
                    .foregroundColor(.primary)

                Text(description)
                    .font(CashTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let actionLabel = actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                }
                .buttonStyle(.glassPrimary)
                .padding(.top, CashSpacing.sm)
            }
        }
        .padding(CashSpacing.xxl)
    }
}

// MARK: - Glass Chip

struct GlassChip: View {
    let label: String
    var icon: String? = nil
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: CashSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(label)
                    .font(CashTypography.caption)
            }
            .padding(.horizontal, CashSpacing.md)
            .padding(.vertical, CashSpacing.sm)
            .foregroundColor(isSelected ? .white : CashColors.primary)
            .background(
                isSelected
                    ? AnyShapeStyle(CashColors.primary)
                    : AnyShapeStyle(.ultraThinMaterial)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(CashColors.primary.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Quick Stat

struct GlassQuickStat: View {
    let title: LocalizedStringKey
    let value: String
    var change: String? = nil
    var isPositiveChange: Bool = true
    var isPrivate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: CashSpacing.xs) {
            Text(title)
                .font(CashTypography.caption)
                .foregroundColor(.secondary)

            PrivacyAmountView(
                amount: value,
                isPrivate: isPrivate,
                font: CashTypography.title3,
                fontWeight: .semibold,
                color: .primary
            )

            if let change = change, !isPrivate {
                HStack(spacing: 2) {
                    Image(systemName: isPositiveChange ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(change)
                        .font(CashTypography.caption2)
                }
                .foregroundColor(isPositiveChange ? CashColors.success : CashColors.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CashSpacing.md)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CashRadius.medium))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            GlassMetricCard(
                title: "Net Worth",
                value: "$12,345.67",
                icon: "banknote",
                subtitle: "+5.2% this month",
                valueColor: CashColors.primary
            )

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Transactions")
                        .font(.headline)

                    GlassListRow(
                        title: "Grocery Store",
                        subtitle: "Dec 30, 2025",
                        leading: { GlassIconCircle(icon: "cart.fill", color: CashColors.expense) },
                        trailing: { GlassAmountBadge(amount: "-$52.30", isPositive: false) }
                    )

                    GlassDivider()

                    GlassListRow(
                        title: "Salary",
                        subtitle: "Dec 28, 2025",
                        leading: { GlassIconCircle(icon: "briefcase.fill", color: CashColors.income) },
                        trailing: { GlassAmountBadge(amount: "+$3,500", isPositive: true) }
                    )
                }
            }

            HStack(spacing: 12) {
                GlassQuickStat(
                    title: "This Month",
                    value: "$2,150",
                    change: "+12%",
                    isPositiveChange: true
                )

                GlassQuickStat(
                    title: "Expenses",
                    value: "$1,480",
                    change: "-5%",
                    isPositiveChange: false
                )
            }

            GlassProgressBar(progress: 0.65)
                .padding(.horizontal)

            HStack {
                GlassChip(label: "All", isSelected: true)
                GlassChip(label: "Income", icon: "arrow.down.left")
                GlassChip(label: "Expense", icon: "arrow.up.right")
            }

            GlassFloatingButton(icon: "plus") {}

            Button("Primary Action") {}
                .buttonStyle(.glassPrimary)

            Button("Secondary Action") {}
                .buttonStyle(.glassSecondary)
        }
        .padding()
    }
    .cashBackground()
}
