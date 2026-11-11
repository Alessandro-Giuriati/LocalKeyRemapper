import AppKit

/// Displays local help and contact details with a Copy button for each address.
@MainActor
final class HelpWindowController: NSWindowController {
    static let installationGuideAddress = "https://localkeyremapper.github.io/install.html"

    private static let addresses = [
        (label: "Website", value: "https://localkeyremapper.github.io"),
        (label: "Installation Guide", value: installationGuideAddress),
        (label: "Email", value: "localkeyremapper@gmail.com"),
        (label: "Bugs & Feedback", value: "https://github.com/Alessandro-Giuriati/LocalKeyRemapper/issues"),
        (label: "Private Security Report",
         value: "https://github.com/Alessandro-Giuriati/LocalKeyRemapper/security/advisories/new"),
        (label: "Donations", value: "https://localkeyremapper.github.io/support-the-project.html")
    ]

    private let textFields: [NSTextField]
    private let copyButtons: [NSButton]
    private let pasteboard: NSPasteboard
    private let grid: NSGridView
    private let contentPadding: CGFloat = 20
    private weak var lastCopiedButton: NSButton?

    init(textScale: CGFloat, pasteboard: NSPasteboard = .general) {
        let labels = Self.addresses.map { NSTextField(labelWithString: $0.label) }
        let values = Self.addresses.map { address in
            let field = NSTextField(labelWithString: address.value)
            field.lineBreakMode = .byTruncatingMiddle
            field.toolTip = address.value
            return field
        }
        let copyButtons = Self.addresses.enumerated().map { index, address in
            let button = NSButton(title: "Copy", target: nil, action: nil)
            button.bezelStyle = .rounded
            button.tag = index
            button.setAccessibilityLabel("Copy \(address.label)")
            return button
        }
        let grid = NSGridView(views: labels.indices.map { index in
            [labels[index], values[index], copyButtons[index]] as [NSView]
        })
        grid.xPlacement = .leading
        grid.column(at: 1).xPlacement = .fill
        grid.columnSpacing = 18
        grid.rowSpacing = 10
        self.textFields = labels + values
        self.copyButtons = copyButtons
        self.pasteboard = pasteboard
        self.grid = grid

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Help & Contact"
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        super.init(window: window)

        for button in copyButtons {
            button.target = self
            button.action = #selector(copyAddress(_:))
        }

        let content = NSStackView(views: [grid])
        content.orientation = .vertical
        content.alignment = .leading
        content.edgeInsets = NSEdgeInsets(
            top: contentPadding, left: contentPadding,
            bottom: contentPadding, right: contentPadding
        )
        window.contentView = content
        applyTextScale(textScale)
        window.center()
        window.initialFirstResponder = copyButtons.first
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        lastCopiedButton?.title = "Copy"
        lastCopiedButton = nil
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    func applyTextScale(_ scale: CGFloat) {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize * scale)
        for field in textFields {
            field.font = font
        }
        for button in copyButtons {
            button.font = font
        }
        grid.column(at: 1).width = 360 * scale
        grid.column(at: 2).width = 80 * scale
        let gridSize = grid.fittingSize
        window?.setContentSize(NSSize(
            width: ceil(gridSize.width) + 2 * contentPadding,
            height: ceil(gridSize.height) + 2 * contentPadding
        ))
    }

    @objc
    private func copyAddress(_ sender: NSButton) {
        let address = Self.addresses[sender.tag].value
        pasteboard.clearContents()
        guard pasteboard.writeObjects([address as NSString]) else {
            return
        }

        lastCopiedButton?.title = "Copy"
        sender.title = "Copied"
        lastCopiedButton = sender
    }
}
