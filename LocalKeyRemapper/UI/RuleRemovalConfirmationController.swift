//
//  RuleRemovalConfirmationController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/19/26.
//

import AppKit

/// Represents every confirmation related to rule removal.
///
/// Keeping these requests centralized ensures that every removal
/// entry point uses the same wording and behavior.
nonisolated enum RuleRemovalConfirmationRequest:
    Equatable
{
    /// Confirms that the user wants to enable removal confirmations.
    case enablePreference

    /// Confirms that the user wants to disable removal confirmations.
    case disablePreference

    /// Confirms that the user wants to remove one remapping rule.
    case removeRule

    var messageText:
        String
    {
        switch self {
        case .enablePreference:
            return "Enable removal confirmations?"

        case .disablePreference:
            return "Disable removal confirmations?"

        case .removeRule:
            return "Remove this rule?"
        }
    }

    var informativeText:
        String
    {
        switch self {
        case .enablePreference:
            return "LocalKeyRemapper will ask for confirmation before removing each remapping rule."

        case .disablePreference:
            return "Remapping rules will be removed from the editor immediately without asking for confirmation."

        case .removeRule:
            return "The rule will be removed from the editor. Save your rules to make the change permanent."
        }
    }

    var confirmationButtonTitle:
        String
    {
        switch self {
        case .enablePreference:
            return "Enable"

        case .disablePreference:
            return "Disable"

        case .removeRule:
            return "Remove"
        }
    }

    var isDestructive:
        Bool
    {
        switch self {
        case .enablePreference:
            return false

        case .disablePreference,
             .removeRule:
            return true
        }
    }
}

/// Presents confirmation requests to the user.
///
/// The protocol allows tests to provide a predictable mock presenter
/// without displaying real AppKit dialogs.
@MainActor
protocol RuleRemovalConfirmationPresenting:
    AnyObject
{
    func confirm(
        _ request:
            RuleRemovalConfirmationRequest
    ) -> Bool
}

/// Displays native macOS confirmation dialogs.
@MainActor
final class AppKitRuleRemovalConfirmationPresenter:
    RuleRemovalConfirmationPresenting
{
    func confirm(
        _ request:
            RuleRemovalConfirmationRequest
    ) -> Bool {
        let alert = NSAlert()

        alert.messageText =
            request.messageText

        alert.informativeText =
            request.informativeText

        alert.alertStyle =
            .warning

        alert.addButton(
            withTitle:
                request.confirmationButtonTitle
        )

        alert.addButton(
            withTitle:
                "Cancel"
        )

        if request.isDestructive {
            alert.buttons
                .first?
                .hasDestructiveAction =
                    true
        }

        return alert.runModal()
            == .alertFirstButtonReturn
    }
}

/// Centralizes the decision about whether a preference change
/// or rule removal may continue.
///
/// This controller does not modify preferences or rules directly.
/// It only returns whether the requested operation was confirmed.
@MainActor
final class RuleRemovalConfirmationController {
    private let presenter:
        RuleRemovalConfirmationPresenting

    /// Creates the production controller with the native AppKit presenter.
    convenience init() {
        self.init(
            presenter:
                AppKitRuleRemovalConfirmationPresenter()
        )
    }

    /// Creates a controller with an injected presenter.
    ///
    /// Tests use this initializer to avoid displaying real dialogs.
    init(
        presenter:
            RuleRemovalConfirmationPresenting
    ) {
        self.presenter =
            presenter
    }

    /// Returns whether a requested confirmation-preference change
    /// should be applied.
    ///
    /// Every real change requires explicit confirmation. Requesting
    /// the already active value does not display a dialog.
    func shouldApplyPreferenceChange(
        from currentValue:
            Bool,
        to requestedValue:
            Bool
    ) -> Bool {
        guard currentValue != requestedValue else {
            return true
        }

        let request:
            RuleRemovalConfirmationRequest =
                requestedValue
                    ? .enablePreference
                    : .disablePreference

        return presenter.confirm(
            request
        )
    }

    /// Returns whether the requested rule removal should continue.
    ///
    /// When confirmation is disabled, removal proceeds immediately.
    /// When confirmation is enabled, the presenter must approve it.
    func shouldRemoveRule(
        confirmationRequired:
            Bool
    ) -> Bool {
        guard confirmationRequired else {
            return true
        }

        return presenter.confirm(
            .removeRule
        )
    }
}
