//
//  LocalKeyRemapperUITests.swift
//  LocalKeyRemapperUITests
//
//  Created by Alessandro Giuriati on 5/18/26.
//

import XCTest

final class LocalKeyRemapperUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testApplicationMenusAndHelpWindow() {
        let app = XCUIApplication()
        app.launch()

        let menus = app.menuBars.firstMatch.menuBarItems
        XCTAssertFalse(menus["Edit"].exists)

        let viewMenu = menus["View"]
        viewMenu.click()
        for title in ["Increase Text Size", "Decrease Text Size", "Reset Text Size"] {
            XCTAssertTrue(viewMenu.menuItems[title].exists)
        }
        for title in ["Show Tab Bar", "Show All Tabs", "Enter Full Screen"] {
            XCTAssertFalse(viewMenu.menuItems[title].exists)
        }
        app.typeKey(.escape, modifierFlags: [])

        let helpMenu = menus["Help"]
        helpMenu.click()
        helpMenu.menuItems["Help & Contact…"].click()

        let helpWindow = app.windows["Help & Contact"]
        XCTAssertTrue(helpWindow.waitForExistence(timeout: 5))
        for title in [
            "Copy Website", "Copy Installation Guide", "Copy Email",
            "Copy Bugs & Feedback", "Copy Private Security Report", "Copy Donations"
        ] {
            XCTAssertTrue(helpWindow.buttons[title].exists)
        }
        XCTAssertTrue(helpWindow.staticTexts["localkeyremapper@gmail.com"].exists)
        XCTAssertTrue(helpWindow.staticTexts["https://localkeyremapper.github.io"].exists)
        XCTAssertEqual(helpWindow.links.count, 0)

        helpMenu.click()
        helpMenu.menuItems["Help & Contact…"].click()
        XCTAssertEqual(app.windows.matching(identifier: "Help & Contact").count, 1)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
