import AppKit
import CodexBarCore

extension StatusItemController {
    func resolvedMenuProvider(enabledProviders: [UsageProvider]? = nil) -> UsageProvider? {
        let enabled = enabledProviders ??
            (self.shouldMergeIcons
                ? self.mergedStatusItemProvidersForDisplay()
                : self.store.enabledProvidersForDisplay())
        if enabled.isEmpty { return .codex }
        if let selected = self.selectedMenuProvider, enabled.contains(selected) {
            return selected
        }
        // Prefer an available provider so the default menu content matches the status icon.
        // Falls back to first display provider when all lack credentials.
        return enabled.first(where: { self.store.isProviderAvailable($0) }) ?? enabled.first
    }

    func includesOverviewTab(enabledProviders: [UsageProvider]) -> Bool {
        !self.settings.resolvedMergedOverviewProviders(
            activeProviders: enabledProviders,
            maxVisibleProviders: Self.maxOverviewProviders).isEmpty
    }

    func resolvedSwitcherSelection(
        enabledProviders: [UsageProvider],
        includesOverview: Bool) -> ProviderSwitcherSelection
    {
        if includesOverview, self.settings.mergedMenuLastSelectedWasOverview {
            return .overview
        }
        return .provider(self.resolvedMenuProvider(enabledProviders: enabledProviders) ?? .codex)
    }

    func menuProvider(for menu: NSMenu) -> UsageProvider? {
        if let provider = self.menuProviders[ObjectIdentifier(menu)] {
            return provider
        }
        if self.isMergedMenu(menu) {
            return self.resolvedMenuProvider(enabledProviders: self.mergedStatusItemProvidersForDisplay())
        }
        if self.shouldMergeIcons {
            return self.resolvedMenuProvider(enabledProviders: self.mergedStatusItemProvidersForDisplay())
        }
        if menu === self.fallbackMenu {
            return nil
        }
        return self.store.enabledProvidersForDisplay().first ?? .codex
    }
}
