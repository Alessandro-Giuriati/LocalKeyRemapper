//
//  GlobalShortcutController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

/// Coordinates global shortcut registration, local persistence,
/// validation, and protection from normal remapping rules.
///
/// This controller stores only configured shortcuts.
/// It never receives, records, or logs normal keyboard input.
@MainActor
final class GlobalShortcutController {

    private let shortcutManager:
        GlobalShortcutRegistering

    private let appPreferencesController:
        AppPreferencesControlling

    private let remappingEngine:
        RemappingEngine

    /// Loads the active profile's stored rules whenever an effective shortcut
    /// configuration must be validated for runtime registration.
    ///
    /// The provider returns configured rules only. It does not inspect
    /// keyboard input or perform event-time work.
    private let configuredRulesProvider:
        () throws -> [RemapRule]

    /// Resolves the effective shortcut configuration currently persisted for
    /// the active profile.
    ///
    /// When absent, the application-wide stored default remains the effective
    /// configuration. This preserves compatibility with existing tests and
    /// call sites that do not use profiles.
    private let effectiveConfigurationProvider:
        (() throws -> RemappingShortcutConfiguration)?

    /// Supplies the shortcut configuration that Rules-related editors should
    /// use for validation and warning presentation.
    ///
    /// Runtime registration never uses this provider.
    private let rulesEditorShortcutConfigurationProvider:
        (() -> RemappingShortcutConfiguration)?

    private let actionHandler:
        (
            GlobalShortcutAction
        ) -> Void

    /// Indicates that active global registrations are temporarily
    /// suspended while a configuration window records a shortcut.
    private var isCaptureSuspended = false

    /// The effective configuration most recently applied to Carbon and to the
    /// remapping engine's reserved combinations.
    ///
    /// This value is runtime-only and is never persisted independently.
    private var appliedEffectiveConfiguration:
        RemappingShortcutConfiguration?

    /// The application-wide default shortcut configuration currently stored in
    /// local application preferences.
    private var storedDefaultConfiguration:
        RemappingShortcutConfiguration
    {
        appPreferencesController
            .preferences
            .shortcutConfiguration
    }

    /// The shortcut configuration exposed to Rules-related editors.
    ///
    /// Tests and call sites that do not provide a Rules-editor scope retain the
    /// original behavior and receive the stored application default.
    var configuredConfiguration:
        RemappingShortcutConfiguration
    {
        rulesEditorShortcutConfigurationProvider?()
            ?? storedDefaultConfiguration
    }

    init(
        shortcutManager:
            GlobalShortcutRegistering,
        appPreferencesController:
            AppPreferencesControlling,
        remappingEngine:
            RemappingEngine = RemappingEngine(),
        configuredRulesProvider:
            @escaping () throws -> [RemapRule] = {
                []
            },
        effectiveConfigurationProvider:
            (() throws -> RemappingShortcutConfiguration)? = nil,
        rulesEditorShortcutConfigurationProvider:
            (() -> RemappingShortcutConfiguration)? = nil,
        actionHandler:
            @escaping (
                GlobalShortcutAction
            ) -> Void
    ) {
        self.shortcutManager =
            shortcutManager

        self.appPreferencesController =
            appPreferencesController

        self.remappingEngine =
            remappingEngine

        self.configuredRulesProvider =
            configuredRulesProvider

        self.effectiveConfigurationProvider =
            effectiveConfigurationProvider

        self.rulesEditorShortcutConfigurationProvider =
            rulesEditorShortcutConfigurationProvider

        self.actionHandler =
            actionHandler
    }

    /// Registers and protects the effective configuration currently persisted
    /// for the active profile.
    func start() throws {
        isCaptureSuspended =
            false

        let effectiveConfiguration =
            try resolvePersistedEffectiveConfiguration()

        do {
            try applyRegistration(
                for:
                    effectiveConfiguration
            )

            applyReservation(
                for:
                    effectiveConfiguration
            )

            appliedEffectiveConfiguration =
                effectiveConfiguration
        } catch {
            shortcutManager.unregister()

            applyReservation(
                for:
                    .disabled
            )

            appliedEffectiveConfiguration =
                nil

            throw error
        }
    }

    /// Compatibility operation for callers that use one shortcut configuration
    /// as both the stored default and the effective runtime configuration.
    func setConfiguration(
        _ newConfiguration:
            RemappingShortcutConfiguration
    ) throws {
        try applyConfiguration(
            defaultConfiguration:
                newConfiguration,
            effectiveConfiguration:
                newConfiguration,
            persistingWith: {
                [appPreferencesController] in

                try appPreferencesController
                    .setShortcutConfiguration(
                        newConfiguration
                    )
            }
        )
    }

    /// Compatibility operation used by existing tests and non-profile call
    /// sites.
    ///
    /// The supplied configuration is treated as both the new default and the
    /// effective runtime configuration.
    func applyConfiguration(
        _ newConfiguration:
            RemappingShortcutConfiguration,
        persistingWith persistence:
            () throws -> Void
    ) throws {
        try applyConfiguration(
            defaultConfiguration:
                newConfiguration,
            effectiveConfiguration:
                newConfiguration,
            persistingWith:
                persistence
        )
    }

    /// Applies the application-wide default and the active profile's effective
    /// configuration as one coordinated operation.
    ///
    /// The default configuration participates in persistence and structural
    /// validation. Only the effective configuration is registered with Carbon
    /// and reserved inside the remapping engine.
    ///
    /// If registration or persistence fails, the previous effective
    /// registration and reservation are restored whenever possible.
    func applyConfiguration(
        defaultConfiguration:
            RemappingShortcutConfiguration,
        effectiveConfiguration:
            RemappingShortcutConfiguration,
        previousEffectiveConfiguration:
            RemappingShortcutConfiguration? = nil,
        persistingWith persistence:
            () throws -> Void
    ) throws {
        // The default must remain structurally valid even when the active
        // profile currently uses an override.
        try GlobalShortcutConfigurationPolicy
            .validate(
                defaultConfiguration
            )

        // Validate the configuration that will actually become active before
        // touching Carbon registrations or reserved combinations.
        try validate(
            effectiveConfiguration
        )

        let previousRuntimeConfiguration =
            try resolvePreviousEffectiveConfiguration(
                explicitPreviousConfiguration:
                    previousEffectiveConfiguration
            )

        let effectiveConfigurationChanged =
            previousRuntimeConfiguration
                != effectiveConfiguration

        if effectiveConfigurationChanged {
            do {
                try register(
                    effectiveConfiguration
                )

                applyReservation(
                    for:
                        effectiveConfiguration
                )
            } catch {
                restoreRegistrationAndReservation(
                    for:
                        previousRuntimeConfiguration
                )

                throw error
            }
        }

        do {
            try persistence()
        } catch {
            if effectiveConfigurationChanged {
                restoreRegistrationAndReservation(
                    for:
                        previousRuntimeConfiguration
                )
            }

            throw error
        }

        appliedEffectiveConfiguration =
            effectiveConfiguration
    }

    /// Compatibility operation for code that still edits
    /// one optional toggle shortcut.
    func setShortcut(
        _ newShortcut:
            KeyCombination?
    ) throws {
        let configuration:
            RemappingShortcutConfiguration

        if let newShortcut {
            configuration =
                .toggle(
                    newShortcut
                )
        } else {
            configuration =
                .disabled
        }

        try setConfiguration(
            configuration
        )
    }

    /// Temporarily removes active Carbon registrations while
    /// a configuration window records a shortcut.
    func beginShortcutCapture() {
        guard
            !isCaptureSuspended
        else {
            return
        }

        isCaptureSuspended =
            true

        shortcutManager.unregister()
    }

    /// Restores the effective runtime configuration after capture ends.
    ///
    /// Unsaved Home edits do not participate in this operation. The previously
    /// applied runtime configuration remains authoritative until Home Save
    /// succeeds.
    func endShortcutCapture() throws {
        guard
            isCaptureSuspended
        else {
            return
        }

        isCaptureSuspended =
            false

        let effectiveConfiguration =
            try resolvePreviousEffectiveConfiguration(
                explicitPreviousConfiguration:
                    nil
            )

        do {
            try applyRegistration(
                for:
                    effectiveConfiguration
            )

            applyReservation(
                for:
                    effectiveConfiguration
            )

            appliedEffectiveConfiguration =
                effectiveConfiguration
        } catch {
            shortcutManager.unregister()

            applyReservation(
                for:
                    .disabled
            )

            appliedEffectiveConfiguration =
                nil

            throw error
        }
    }

    /// Removes all shortcut registrations, the Carbon event handler,
    /// and every protected application combination.
    func stop() {
        isCaptureSuspended =
            false

        appliedEffectiveConfiguration =
            nil

        shortcutManager.stop()

        applyReservation(
            for:
                .disabled
        )
    }

    private func resolvePersistedEffectiveConfiguration()
        throws -> RemappingShortcutConfiguration
    {
        if let effectiveConfigurationProvider {
            return try effectiveConfigurationProvider()
        }

        return storedDefaultConfiguration
    }

    private func resolvePreviousEffectiveConfiguration(
        explicitPreviousConfiguration:
            RemappingShortcutConfiguration?
    ) throws -> RemappingShortcutConfiguration {
        if let appliedEffectiveConfiguration {
            return appliedEffectiveConfiguration
        }

        if let explicitPreviousConfiguration {
            return explicitPreviousConfiguration
        }

        return try resolvePersistedEffectiveConfiguration()
    }

    private func applyRegistration(
        for configuration:
            RemappingShortcutConfiguration
    ) throws {
        try validate(
            configuration
        )

        try register(
            configuration
        )
    }

    private func register(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws {
        try shortcutManager.register(
            configuration.registrations,
            actionHandler:
                actionHandler
        )
    }

    /// Validates both the shortcut structure and its interaction with the
    /// active profile's stored remapping rules.
    private func validate(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws {
        try GlobalShortcutConfigurationPolicy
            .validate(
                configuration
            )

        // Turning effective shortcuts off can never conflict with a rule.
        // Avoid loading rules in this case so Off remains available even if
        // rule storage is temporarily unavailable.
        guard
            !configuration
                .registrations
                .isEmpty
        else {
            return
        }

        let configuredRules =
            try configuredRulesProvider()

        try RemappingShortcutRuleConflictPolicy
            .validate(
                rules:
                    configuredRules,
                shortcutConfiguration:
                    configuration
            )
    }

    private func applyReservation(
        for configuration:
            RemappingShortcutConfiguration
    ) {
        remappingEngine
            .replaceReservedCombinations(
                configuration
                    .reservedCombinations
            )
    }

    /// Restores a configuration that was already active before the attempted
    /// transaction.
    ///
    /// Rule-conflict validation is intentionally not repeated here because the
    /// profiles store may temporarily contain the proposed active profile until
    /// the outer Home transaction completes its rollback.
    private func restoreRegistrationAndReservation(
        for configuration:
            RemappingShortcutConfiguration
    ) {
        do {
            try GlobalShortcutConfigurationPolicy
                .validate(
                    configuration
                )

            try register(
                configuration
            )

            applyReservation(
                for:
                    configuration
            )

            appliedEffectiveConfiguration =
                configuration
        } catch {
            shortcutManager.unregister()

            applyReservation(
                for:
                    .disabled
            )

            appliedEffectiveConfiguration =
                nil
        }
    }
}
