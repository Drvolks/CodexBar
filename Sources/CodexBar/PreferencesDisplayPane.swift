import CodexBarCore
import SwiftUI

@MainActor
struct DisplayPane: View {
    private static let maxOverviewProviders = SettingsStore.mergedOverviewProviderLimit

    static func overviewProviderLimitText(limit: Int = Self.maxOverviewProviders) -> String {
        L("overview_choose_providers", String(limit))
    }

    @State private var isOverviewProviderPopoverPresented = false
    @State private var isMergedIconMetricsPopoverPresented = false
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(contentSpacing: 12) {
                    Text(L("section_menu_bar"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    PreferenceToggleRow(
                        title: L("merge_icons_title"),
                        subtitle: L("merge_icons_subtitle"),
                        binding: self.$settings.mergeIcons)
                    self.mergedIconMetricsSelector
                    PreferenceToggleRow(
                        title: L("switcher_shows_icons_title"),
                        subtitle: L("switcher_shows_icons_subtitle"),
                        binding: self.$settings.switcherShowsIcons)
                        .disabled(!self.settings.mergeIcons)
                        .opacity(self.settings.mergeIcons ? 1 : 0.5)
                    PreferenceToggleRow(
                        title: L("show_most_used_provider_title"),
                        subtitle: L("show_most_used_provider_subtitle"),
                        binding: self.$settings.menuBarShowsHighestUsage)
                        .disabled(!self.settings.mergeIcons)
                        .opacity(self.settings.mergeIcons ? 1 : 0.5)
                    PreferenceToggleRow(
                        title: L("hide_critters_title"),
                        subtitle: L("hide_critters_subtitle"),
                        binding: self.$settings.menuBarHidesCritters)
                    PreferenceToggleRow(
                        title: L("menu_bar_shows_percent_title"),
                        subtitle: L("menu_bar_shows_percent_subtitle"),
                        binding: self.$settings.menuBarShowsBrandIconWithPercent)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("display_mode_title"))
                                .font(.body)
                            Text(L("display_mode_subtitle"))
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Picker(L("Display mode"), selection: self.$settings.menuBarDisplayMode) {
                            ForEach(MenuBarDisplayMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                    }
                    .disabled(!self.settings.menuBarShowsBrandIconWithPercent)
                    .opacity(self.settings.menuBarShowsBrandIconWithPercent ? 1 : 0.5)
                }

                Divider()

                SettingsSection(contentSpacing: 12) {
                    Text(L("section_menu_content"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    PreferenceToggleRow(
                        title: L("show_usage_as_used_title"),
                        subtitle: L("show_usage_as_used_subtitle"),
                        binding: self.$settings.usageBarsShowUsed)
                    PreferenceToggleRow(
                        title: L("show_quota_warning_markers_title"),
                        subtitle: L("show_quota_warning_markers_subtitle"),
                        binding: self.$settings.quotaWarningMarkersVisible)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("weekly_progress_work_days_title"))
                                .font(.body)
                            Text(L("weekly_progress_work_days_subtitle"))
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Picker(L("weekly_progress_work_days_title"), selection: self.$settings.weeklyProgressWorkDays) {
                            Text(L("Off")).tag(nil as Int?)
                            Text(L("4 days")).tag(4 as Int?)
                            Text(L("5 days")).tag(5 as Int?)
                            Text(L("7 days")).tag(7 as Int?)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 100)
                    }
                    PreferenceToggleRow(
                        title: L("show_reset_time_as_clock_title"),
                        subtitle: L("show_reset_time_as_clock_subtitle"),
                        binding: self.$settings.resetTimesShowAbsolute)
                    PreferenceToggleRow(
                        title: L("show_provider_changelog_links_title"),
                        subtitle: L("show_provider_changelog_links_subtitle"),
                        binding: self.$settings.providerChangelogLinksEnabled)
                    PreferenceToggleRow(
                        title: L("show_credits_extra_usage_title"),
                        subtitle: L("show_credits_extra_usage_subtitle"),
                        binding: self.$settings.showOptionalCreditsAndExtraUsage)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("multi_account_layout_title"))
                                .font(.body)
                            Text(L("multi_account_layout_subtitle"))
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Picker(L("multi_account_layout_title"), selection: self.$settings.multiAccountMenuLayout) {
                            ForEach(MultiAccountMenuLayout.allCases) { layout in
                                Text(layout.label).tag(layout)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                    }
                    self.overviewProviderSelector
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .onAppear {
                self.reconcileOverviewSelection()
            }
            .onChange(of: self.settings.mergeIcons) { _, isEnabled in
                guard isEnabled else {
                    self.isOverviewProviderPopoverPresented = false
                    self.isMergedIconMetricsPopoverPresented = false
                    return
                }
                self.reconcileOverviewSelection()
            }
            .onChange(of: self.activeProvidersInOrder) { _, _ in
                if self.activeProvidersInOrder.isEmpty {
                    self.isOverviewProviderPopoverPresented = false
                    self.isMergedIconMetricsPopoverPresented = false
                }
                self.reconcileOverviewSelection()
            }
        }
    }

    private var mergedIconMetricsSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text(L("merged_icon_metrics_title"))
                    .font(.body)
                Spacer(minLength: 0)
                if self.showsMergedIconMetricsConfigureButton {
                    Button(L("configure")) {
                        self.isMergedIconMetricsPopoverPresented = true
                    }
                    .offset(y: 1)
                    .popover(isPresented: self.$isMergedIconMetricsPopoverPresented, arrowEdge: .bottom) {
                        self.mergedIconMetricsPopover
                    }
                }
            }

            if !self.settings.mergeIcons {
                Text(L("merged_icon_metrics_enable_merge_icons_hint"))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else if self.activeProvidersInOrder.isEmpty {
                Text(L("merged_icon_metrics_no_providers_hint"))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                Text(self.mergedIconMetricsSelectionSummary)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
    }

    private var mergedIconMetricsPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("merged_icon_metrics_choose_providers"))
                .font(.headline)
            Text(L("merged_icon_metrics_hint"))
                .font(.footnote)
                .foregroundStyle(.tertiary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(self.activeProvidersInOrder, id: \.self) { provider in
                        let isSelected = self.mergedIconMetricProviders.contains(provider)
                        HStack(alignment: .center, spacing: 8) {
                            Toggle(
                                isOn: Binding(
                                    get: { self.mergedIconMetricProviders.contains(provider) },
                                    set: { shouldSelect in
                                        self.settings.setMergedMenuBarIconProvider(
                                            provider,
                                            isSelected: shouldSelect)
                                    })) {
                                Text(self.providerDisplayName(provider))
                                    .font(.body)
                            }
                            .toggleStyle(.checkbox)
                            .disabled(!isSelected && self.mergedIconMetricProviders.count >= Self
                                .maxIconMetricProviders)

                            Spacer(minLength: 0)

                            Picker(
                                L("merged_icon_metric_picker_label"),
                                selection: self.metricPreferenceBinding(for: provider))
                            {
                                ForEach(self.metricOptions(for: provider)) { option in
                                    Text(option.title).tag(option.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 150)
                            .disabled(!isSelected)
                            .opacity(isSelected ? 1 : 0.45)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)

            Text(L("merged_icon_metrics_limit_hint", String(Self.maxIconMetricProviders)))
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 360)
    }

    private var overviewProviderSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text(L("overview_tab_providers_title"))
                    .font(.body)
                Spacer(minLength: 0)
                if self.showsOverviewConfigureButton {
                    Button(L("configure")) {
                        self.isOverviewProviderPopoverPresented = true
                    }
                    .offset(y: 1)
                    .popover(isPresented: self.$isOverviewProviderPopoverPresented, arrowEdge: .bottom) {
                        self.overviewProviderPopover
                    }
                }
            }

            if !self.settings.mergeIcons {
                Text(L("overview_enable_merge_icons_hint"))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else if self.activeProvidersInOrder.isEmpty {
                Text(L("overview_no_providers_hint"))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                Text(self.overviewProviderSelectionSummary)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
    }

    private var overviewProviderPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.overviewProviderLimitText())
                .font(.headline)
            Text(L("overview_rows_follow_order"))
                .font(.footnote)
                .foregroundStyle(.tertiary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(self.activeProvidersInOrder, id: \.self) { provider in
                        Toggle(
                            isOn: Binding(
                                get: { self.overviewSelectedProviders.contains(provider) },
                                set: { shouldSelect in
                                    self.setOverviewProviderSelection(provider: provider, isSelected: shouldSelect)
                                })) {
                            Text(self.providerDisplayName(provider))
                                .font(.body)
                        }
                        .toggleStyle(.checkbox)
                        .disabled(
                            !self.overviewSelectedProviders.contains(provider) &&
                                self.overviewSelectedProviders.count >= Self.maxOverviewProviders)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(12)
        .frame(width: 280)
    }

    private var activeProvidersInOrder: [UsageProvider] {
        self.store.enabledProviders()
    }

    private var overviewSelectedProviders: [UsageProvider] {
        self.settings.resolvedMergedOverviewProviders(
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }

    private var showsOverviewConfigureButton: Bool {
        self.settings.mergeIcons && !self.activeProvidersInOrder.isEmpty
    }

    private static let maxIconMetricProviders = SettingsStore.mergedMenuBarIconProviderLimit

    private var showsMergedIconMetricsConfigureButton: Bool {
        self.settings.mergeIcons && !self.activeProvidersInOrder.isEmpty
    }

    private var mergedIconMetricProviders: [UsageProvider] {
        let active = Set(self.activeProvidersInOrder)
        return self.settings.mergedMenuBarIconProviders.filter { active.contains($0) }
    }

    private var mergedIconMetricsSelectionSummary: String {
        let selectedNames = self.mergedIconMetricProviders.map { provider in
            "\(self.providerDisplayName(provider)) · \(self.selectedMetricTitle(for: provider))"
        }
        guard !selectedNames.isEmpty else { return L("merged_icon_metrics_no_providers_selected") }
        return selectedNames.joined(separator: ", ")
    }

    private var overviewProviderSelectionSummary: String {
        let selectedNames = self.overviewSelectedProviders.map(self.providerDisplayName)
        guard !selectedNames.isEmpty else { return L("overview_no_providers_selected") }
        return selectedNames.joined(separator: ", ")
    }

    private func providerDisplayName(_ provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }

    private func metricPreferenceBinding(for provider: UsageProvider) -> Binding<String> {
        Binding(
            get: {
                self.settings
                    .menuBarMetricPreference(for: provider, snapshot: self.store.snapshot(for: provider))
                    .rawValue
            },
            set: { rawValue in
                guard let preference = MenuBarMetricPreference(rawValue: rawValue) else { return }
                self.settings.setMenuBarMetricPreference(preference, for: provider)
            })
    }

    private func selectedMetricTitle(for provider: UsageProvider) -> String {
        let rawValue = self.settings
            .menuBarMetricPreference(for: provider, snapshot: self.store.snapshot(for: provider))
            .rawValue
        return self.metricOptions(for: provider).first(where: { $0.id == rawValue })?.title
            ?? MenuBarMetricPreference.automatic.label
    }

    private func metricOptions(for provider: UsageProvider) -> [DisplayPaneMetricOption] {
        if provider == .openrouter {
            return [
                DisplayPaneMetricOption(id: MenuBarMetricPreference.automatic.rawValue, title: L("automatic")),
                DisplayPaneMetricOption(
                    id: MenuBarMetricPreference.primary.rawValue,
                    title: L("primary_api_key_limit")),
            ]
        }
        if SettingsStore.isBalanceOnlyProvider(provider) {
            return [
                DisplayPaneMetricOption(id: MenuBarMetricPreference.automatic.rawValue, title: L("Automatic")),
            ]
        }

        let metadata = self.store.metadata(for: provider)
        let snapshot = self.store.snapshot(for: provider)
        var options: [DisplayPaneMetricOption] = [
            DisplayPaneMetricOption(id: MenuBarMetricPreference.automatic.rawValue, title: L("automatic")),
            DisplayPaneMetricOption(
                id: MenuBarMetricPreference.primary.rawValue,
                title: String(format: L("metric_primary"), metadata.sessionLabel)),
            DisplayPaneMetricOption(
                id: MenuBarMetricPreference.secondary.rawValue,
                title: String(format: L("metric_secondary"), metadata.weeklyLabel)),
        ]
        if self.settings.menuBarMetricSupportsTertiary(for: provider, snapshot: snapshot) {
            let tertiaryTitle = metadata.opusLabel ?? MenuBarMetricPreference.tertiary.label
            options.append(DisplayPaneMetricOption(
                id: MenuBarMetricPreference.tertiary.rawValue,
                title: String(format: L("metric_tertiary"), tertiaryTitle)))
        }
        if self.settings.menuBarMetricSupportsExtraUsage(for: provider, snapshot: snapshot) {
            options.append(DisplayPaneMetricOption(
                id: MenuBarMetricPreference.extraUsage.rawValue,
                title: MenuBarMetricPreference.extraUsage.label))
        }
        if self.settings.menuBarMetricSupportsAverage(for: provider) {
            options.append(DisplayPaneMetricOption(
                id: MenuBarMetricPreference.average.rawValue,
                title: String(format: L("metric_average"), metadata.sessionLabel, metadata.weeklyLabel)))
        }
        return options
    }

    private func setOverviewProviderSelection(provider: UsageProvider, isSelected: Bool) {
        _ = self.settings.setMergedOverviewProviderSelection(
            provider: provider,
            isSelected: isSelected,
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }

    private func reconcileOverviewSelection() {
        _ = self.settings.reconcileMergedOverviewSelectedProviders(
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }
}

private struct DisplayPaneMetricOption: Identifiable {
    let id: String
    let title: String
}
