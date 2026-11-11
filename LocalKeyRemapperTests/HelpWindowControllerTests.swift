import AppKit
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class HelpWindowControllerTests: XCTestCase {
    func testCopyButtonsPutTheDisplayedAddressesOnThePasteboardAsPlainText() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        let controller = HelpWindowController(textScale: 1, pasteboard: pasteboard)
        let stack = try XCTUnwrap(controller.window?.contentView as? NSStackView)
        let grid = try XCTUnwrap(stack.views.first as? NSGridView)
        let expectedAddresses = [
            "https://localkeyremapper.github.io",
            "https://localkeyremapper.github.io/install.html",
            "localkeyremapper@gmail.com",
            "https://github.com/Alessandro-Giuriati/LocalKeyRemapper/issues",
            "https://github.com/Alessandro-Giuriati/LocalKeyRemapper/security/advisories/new",
            "https://localkeyremapper.github.io/support-the-project.html"
        ]
        XCTAssertEqual(grid.numberOfRows, expectedAddresses.count)

        for (row, expectedAddress) in expectedAddresses.prefix(grid.numberOfRows).enumerated() {
            let address = try XCTUnwrap(
                grid.cell(atColumnIndex: 1, rowIndex: row).contentView as? NSTextField
            )
            let button = try XCTUnwrap(
                grid.cell(atColumnIndex: 2, rowIndex: row).contentView as? NSButton
            )
            XCTAssertEqual(address.stringValue, expectedAddress)
            XCTAssertFalse(address.isEditable)
            XCTAssertFalse(address.allowsEditingTextAttributes)
            button.performClick(nil)
            XCTAssertEqual(pasteboard.string(forType: .string), expectedAddress)
            XCTAssertEqual(button.title, "Copied")
        }
    }
}
