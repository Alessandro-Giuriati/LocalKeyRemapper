import AppKit

/// Routes local key capture and history shortcuts for Rules and Modifier Exceptions.
@MainActor
final class RemappingEditorWindow: NSWindow {
    var flagsChangedHandler: ((NSEvent) -> Void)?
    var keyDownHandler: ((NSEvent) -> Bool)?
    weak var undoButton: NSButton?
    weak var redoButton: NSButton?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.charactersIgnoringModifiers?.lowercased() == "z"
        else {
            return super.performKeyEquivalent(with: event)
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let button: NSButton?
        switch modifiers {
        case .command:
            button = undoButton
        case [.command, .shift]:
            button = redoButton
        default:
            button = nil
        }

        guard let button, button.isEnabled else {
            return super.performKeyEquivalent(with: event)
        }

        button.performClick(nil)
        return true
    }

    override func sendEvent(
        _ event: NSEvent
    ) {
        if event.type == .flagsChanged {
            flagsChangedHandler?(event)
        }

        if event.type == .keyDown,
           keyDownHandler?(event) == true {
            return
        }

        super.sendEvent(event)
    }
}
