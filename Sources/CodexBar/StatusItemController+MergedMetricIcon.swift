import AppKit
import CodexBarCore

extension StatusItemController {
    func mergedIconAnimationProviders() -> [UsageProvider] {
        let selected = self.mergedMenuBarIconProvidersForDisplay()
        guard selected.isEmpty else { return selected }
        return [self.primaryProviderForUnifiedIcon()]
    }

    func mergedMenuBarIconMetricBars(phase: Double?) -> [IconRenderer.MergedMetricBar] {
        let providers = self.mergedMenuBarIconProvidersForDisplay()
        guard !providers.isEmpty else { return [] }
        let showUsed = self.settings.usageBarsShowUsed
        let needsAnimation = self.needsMenuBarIconAnimation()
        return providers.enumerated().map { index, provider in
            let snapshot = self.store.snapshot(for: provider)
            let window = self.menuBarMetricWindow(for: provider, snapshot: snapshot)
            let animatedPercent: Double? = if let phase, needsAnimation, self.shouldAnimate(provider: provider) {
                max(
                    self.animationPattern.value(
                        phase: phase + Double(index) * self.animationPattern.secondaryOffset),
                    Self.loadingPercentEpsilon)
            } else {
                nil
            }
            let percent = animatedPercent ?? window.map {
                showUsed ? $0.usedPercent : $0.remainingPercent
            }
            return IconRenderer.MergedMetricBar(
                style: self.store.style(for: provider),
                percent: percent,
                stale: animatedPercent == nil && self.store.isStale(provider: provider))
        }
    }

    func mergedMenuBarIconStatusIndicator() -> ProviderStatusIndicator {
        self.mergedMenuBarIconProvidersForDisplay()
            .map { self.store.statusIndicator(for: $0) }
            .max(by: { Self.statusIndicatorRank($0) < Self.statusIndicatorRank($1) })
            ?? .none
    }

    static func statusIndicatorRank(_ indicator: ProviderStatusIndicator) -> Int {
        switch indicator {
        case .none: 0
        case .unknown: 1
        case .maintenance: 2
        case .minor: 3
        case .major: 4
        case .critical: 5
        }
    }

    func mergedMenuBarIconWarningFlashActive() -> Bool {
        self.mergedMenuBarIconProvidersForDisplay().contains {
            self.quotaWarningFlashActive(provider: $0)
        }
    }

    /// Renders the merged metric icon when the user selected providers for it.
    /// Returns `nil` when the merged metric icon does not apply, so the caller falls through
    /// to the single-provider icon paths.
    func applyMergedMenuBarMetricIconIfNeeded(
        phase: Double?,
        button: NSStatusBarButton,
        needsAnimation: Bool) -> Bool?
    {
        let providers = self.mergedMenuBarIconProvidersForDisplay()
        guard !providers.isEmpty else { return nil }
        return self.applyMergedMenuBarMetricIcon(
            providers: providers,
            phase: phase,
            button: button,
            needsAnimation: needsAnimation)
    }

    @discardableResult
    func applyMergedMenuBarMetricIcon(
        providers: [UsageProvider],
        phase: Double?,
        button: NSStatusBarButton,
        needsAnimation: Bool)
        -> Bool
    {
        let metrics = self.mergedMenuBarIconMetricBars(phase: phase)
        guard !metrics.isEmpty else { return false }

        let warningFlash = self.mergedMenuBarIconWarningFlashActive()
        let statusIndicator = self.mergedMenuBarIconStatusIndicator()
        let metricSignature = zip(providers, metrics).map { provider, metric in
            let preference = self.settings.menuBarMetricPreference(
                for: provider,
                snapshot: self.store.snapshot(for: provider))
            return [
                provider.rawValue,
                "style=\(metric.style.rawValue)",
                "percent=\(Self.iconSignatureValue(metric.percent))",
                "stale=\(metric.stale ? "1" : "0")",
                "pref=\(preference.rawValue)",
            ].joined(separator: ":")
        }.joined(separator: "||")
        let signature = [
            "mode=mergedMetrics",
            "metrics=\(metricSignature)",
            "showUsed=\(self.settings.usageBarsShowUsed ? "1" : "0")",
            "status=\(statusIndicator.rawValue)",
            "warningFlash=\(warningFlash ? "1" : "0")",
            "anim=\(needsAnimation ? "1" : "0")",
            "hideCritters=\(self.settings.menuBarHidesCritters ? "1" : "0")",
        ].joined(separator: "|")
        if self.shouldSkipMergedIconRender(signature) {
            self.noteIconPerfRender(skipped: true)
            return true
        }

        let image = IconRenderer.makeMergedMetricIcon(
            metrics: metrics,
            statusIndicator: statusIndicator,
            hideCritters: self.settings.menuBarHidesCritters)
        self.setButtonContent(
            image: warningFlash ? Self.quotaWarningFlashImage(base: image) : image,
            title: nil,
            for: button)
        self.noteIconPerfRender(skipped: false)
        return false
    }
}
