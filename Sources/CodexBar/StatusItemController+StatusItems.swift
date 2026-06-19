import AppKit
import CodexBarCore

extension StatusItemController {
    var fallbackProvider: UsageProvider? {
        // Intentionally uses availability-filtered list: fallback activates when no provider
        // can actually work, ensuring at least a codex icon is always visible.
        self.store.enabledProviders().isEmpty ? .codex : nil
    }

    func isEnabled(_ provider: UsageProvider) -> Bool {
        self.store.isEnabled(provider)
    }

    func refreshMenusForLoginStateChange() {
        #if DEBUG
        guard !self.isReleasedForTesting else { return }
        #endif
        self.invalidateMenus()
        if self.shouldMergeIcons {
            guard !self.isMergedMenuOpen else { return }
            self.attachMenus()
        } else {
            self.attachMenus(fallback: self.fallbackProvider)
        }
    }

    func attachMenus() {
        if self.mergedMenu == nil {
            self.mergedMenu = self.makeMenu()
        }
        if self.statusItem.menu !== self.mergedMenu {
            self.statusItem.menu = self.mergedMenu
        }
        self.prepareAttachedClosedMenusIfNeeded()
    }

    func attachMenus(fallback: UsageProvider? = nil) {
        for provider in UsageProvider.allCases {
            // Only access/create the status item if it's actually needed
            let shouldHaveItem = self.isEnabled(provider) || fallback == provider

            if shouldHaveItem {
                let item = self.lazyStatusItem(for: provider)

                if self.isEnabled(provider) {
                    if self.providerMenus[provider] == nil {
                        self.providerMenus[provider] = self.makeMenu(for: provider)
                    }
                    let menu = self.providerMenus[provider]
                    if item.menu !== menu {
                        item.menu = menu
                    }
                } else if fallback == provider {
                    if self.fallbackMenu == nil {
                        self.fallbackMenu = self.makeMenu(for: nil)
                    }
                    if item.menu !== self.fallbackMenu {
                        item.menu = self.fallbackMenu
                    }
                }
            } else if let item = self.statusItems[provider] {
                item.menu = nil
            }
        }
        self.prepareAttachedClosedMenusIfNeeded()
    }

    func rebuildProviderStatusItems() {
        #if DEBUG
        guard !self.isReleasedForTesting else { return }
        #endif
        let ordered = self.settings.orderedProviders()
        let desired = Set(ordered)
        for provider in Array(self.statusItems.keys) where !desired.contains(provider) {
            self.removeProviderStatusItem(for: provider)
        }

        if self.shouldMergeIcons {
            for provider in Array(self.statusItems.keys) {
                self.removeProviderStatusItem(for: provider)
            }
            return
        }
        let fallback = self.fallbackProvider
        let force = self.store.debugForceAnimation
        for provider in ordered where self.isEnabled(provider) || fallback == provider || force {
            _ = self.lazyStatusItem(for: provider)
        }
    }

    func removeProviderStatusItem(for provider: UsageProvider) {
        if let menu = self.providerMenus.removeValue(forKey: provider) {
            let menuID = ObjectIdentifier(menu)
            if menuID == self.providerSwitcherShortcutMenuID {
                self.removeProviderSwitcherShortcutMonitor()
            }
            self.clearMergedSwitcherContentCache(for: menu)
            self.removeMenuLifecycleState(menuID)
        }

        guard let item = self.statusItems.removeValue(forKey: provider) else { return }
        item.menu = nil
        self.lastAppliedProviderIconRenderSignatures.removeValue(forKey: provider)
        self.statusBar.removeStatusItem(item)
    }

    func isVisible(_ provider: UsageProvider) -> Bool {
        self.store.debugForceAnimation || self.isEnabled(provider)
            || self.fallbackProvider == provider
    }
}
