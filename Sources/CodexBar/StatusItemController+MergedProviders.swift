import AppKit
import CodexBarCore

extension StatusItemController {
    var shouldMergeIcons: Bool {
        guard self.settings.mergeIcons else { return false }
        return self.store.enabledProvidersForDisplay().count > 1
    }

    func mergedStatusItemProvidersForDisplay() -> [UsageProvider] {
        guard self.settings.mergeIcons else { return [] }
        let enabledProviders = self.store.enabledProvidersForDisplay()
        guard enabledProviders.count > 1 else { return [] }
        return enabledProviders
    }

    func mergedMenuBarIconProvidersForDisplay() -> [UsageProvider] {
        guard self.shouldMergeIcons else { return [] }
        let selectedProviders = Set(self.settings.mergedMenuBarIconProviders)
        return self.mergedStatusItemProvidersForDisplay().filter { selectedProviders.contains($0) }
    }

    func isMergedMenu(_ menu: NSMenu) -> Bool {
        guard self.shouldMergeIcons else { return false }
        if menu === self.mergedMenu { return true }
        if menu === self.fallbackMenu { return false }
        return self.menuProviders[ObjectIdentifier(menu)] == nil
    }

    func mergedIconStyle() -> IconStyle {
        let iconProviders = self.mergedMenuBarIconProvidersForDisplay()
        if iconProviders.count > 1 { return .combined }
        if let provider = iconProviders.first {
            return self.store.style(for: provider)
        }
        let displayProviders = self.mergedStatusItemProvidersForDisplay()
        let availableProviders = displayProviders.filter { self.store.isEnabled($0) }
        let providers = availableProviders.isEmpty ? displayProviders : availableProviders
        if providers.count > 1 { return .combined }
        if let provider = providers.first {
            return self.store.style(for: provider)
        }
        return .codex
    }
}
