//
//  CashUITests.swift
//  CashUITests
//
//  Created by Michele Broggi on 25/11/25.
//

import XCTest

final class CashUITests: XCTestCase {

    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests
    
    @MainActor
    func testAppLaunches() throws {
        XCTAssertTrue(app.windows.count > 0)
    }
    
    @MainActor
    func testMainWindowExists() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }
    
    // MARK: - Sidebar Tests
    
    @MainActor
    func testSidebarExists() throws {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testNetWorthItemExists() throws {
        let netWorthLabel = app.staticTexts["Net Worth"]
        XCTAssertTrue(netWorthLabel.waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testForecastItemExists() throws {
        let forecastLabel = app.staticTexts["Forecast"]
        XCTAssertTrue(forecastLabel.waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testScheduledItemExists() throws {
        let scheduledLabel = app.staticTexts["Scheduled"]
        XCTAssertTrue(scheduledLabel.waitForExistence(timeout: 5))
    }
    
    // MARK: - Navigation Tests
    
    @MainActor
    func testNavigateToNetWorth() throws {
        let netWorthLabel = app.staticTexts["Net Worth"]
        if netWorthLabel.waitForExistence(timeout: 5) {
            netWorthLabel.click()
            
            let netWorthTitle = app.staticTexts["Net Worth"].firstMatch
            XCTAssertTrue(netWorthTitle.exists)
        }
    }
    
    @MainActor
    func testNavigateToForecast() throws {
        let forecastLabel = app.staticTexts["Forecast"]
        if forecastLabel.waitForExistence(timeout: 5) {
            forecastLabel.click()
            
            let segmentedControl = app.segmentedControls.firstMatch
            XCTAssertTrue(segmentedControl.waitForExistence(timeout: 3))
        }
    }
    
    @MainActor
    func testNavigateToScheduled() throws {
        let scheduledLabel = app.staticTexts["Scheduled"]
        if scheduledLabel.waitForExistence(timeout: 5) {
            scheduledLabel.click()
            
            let scheduledTitle = app.staticTexts["Scheduled Transactions"]
            XCTAssertTrue(scheduledTitle.waitForExistence(timeout: 3))
        }
    }
    
    // MARK: - Menu Tests
    
    @MainActor
    func testFileMenuExists() throws {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.exists)
        
        let fileMenu = menuBar.menuBarItems["File"]
        XCTAssertTrue(fileMenu.exists)
    }
    
    @MainActor
    func testImportOFXMenuExists() throws {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.exists)
        
        let fileMenu = menuBar.menuBarItems["File"]
        XCTAssertTrue(fileMenu.exists)
        fileMenu.click()
        
        // Look for Import OFX menu item
        let importOFXItem = app.menuItems["Import OFX..."]
        XCTAssertTrue(importOFXItem.waitForExistence(timeout: 2))
        
        // Close menu
        app.typeKey(.escape, modifierFlags: [])
    }
    
    // MARK: - Forecast View Tests
    
    @MainActor
    func testForecastPeriodSelector() throws {
        let forecastLabel = app.staticTexts["Forecast"]
        guard forecastLabel.waitForExistence(timeout: 5) else {
            XCTFail("Forecast not found in sidebar")
            return
        }
        forecastLabel.click()
        
        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 3))
    }
    
    @MainActor
    func testForecastSummaryCards() throws {
        let forecastLabel = app.staticTexts["Forecast"]
        guard forecastLabel.waitForExistence(timeout: 5) else {
            XCTFail("Forecast not found in sidebar")
            return
        }
        forecastLabel.click()
        
        let currentBalanceLabel = app.staticTexts["Current Balance"]
        let projectedBalanceLabel = app.staticTexts["Projected Balance"]
        
        XCTAssertTrue(currentBalanceLabel.waitForExistence(timeout: 3))
        XCTAssertTrue(projectedBalanceLabel.waitForExistence(timeout: 3))
    }
    
    // MARK: - Keyboard Shortcut Tests
    
    @MainActor
    func testCmdNOpensDialog() throws {
        app.typeKey("n", modifierFlags: .command)
        
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        
        let cancelButton = sheet.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.click()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}

// MARK: - Scheduled Transactions UI Tests

final class ScheduledTransactionsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    @MainActor
    func testScheduledViewShowsEmptyState() throws {
        let scheduledLabel = app.staticTexts["Scheduled"]
        guard scheduledLabel.waitForExistence(timeout: 5) else {
            XCTFail("Scheduled not found in sidebar")
            return
        }
        scheduledLabel.click()
        
        let noScheduledLabel = app.staticTexts["No scheduled transactions"]
        let addButton = app.buttons["Add"]
        
        XCTAssertTrue(noScheduledLabel.waitForExistence(timeout: 3) || addButton.waitForExistence(timeout: 3))
    }
    
    @MainActor
    func testAddScheduledTransactionButton() throws {
        let scheduledLabel = app.staticTexts["Scheduled"]
        guard scheduledLabel.waitForExistence(timeout: 5) else {
            XCTFail("Scheduled not found in sidebar")
            return
        }
        scheduledLabel.click()
        
        let addButton = app.buttons["Add"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.click()
            
            let sheet = app.sheets.firstMatch
            XCTAssertTrue(sheet.waitForExistence(timeout: 3))
            
            let cancelButton = sheet.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.click()
            }
        }
    }
}

// MARK: - Account UI Tests

final class AccountUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    @MainActor
    func testAddAccountDialog() throws {
        let netWorthLabel = app.staticTexts["Net Worth"]
        if netWorthLabel.waitForExistence(timeout: 5) {
            netWorthLabel.click()
        }
        
        app.typeKey("n", modifierFlags: .command)
        
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        
        let cancelButton = sheet.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.click()
        }
    }
    
    @MainActor
    func testAddAccountDialogHasTypeGroups() throws {
        let netWorthLabel = app.staticTexts["Net Worth"]
        if netWorthLabel.waitForExistence(timeout: 5) {
            netWorthLabel.click()
        }
        
        app.typeKey("n", modifierFlags: .command)
        
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        
        // Check for category picker (the new simplified UI)
        let categoryPicker = sheet.popUpButtons["Category"]
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 2))
        
        let cancelButton = sheet.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.click()
        }
    }
}

// MARK: - Import OFX UI Tests

final class ImportOFXUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    @MainActor
    func testImportOFXMenuOpensFilePicker() throws {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.exists)
        
        let fileMenu = menuBar.menuBarItems["File"]
        XCTAssertTrue(fileMenu.exists)
        fileMenu.click()
        
        let importOFXItem = app.menuItems["Import OFX..."]
        guard importOFXItem.waitForExistence(timeout: 2) else {
            XCTFail("Import OFX menu item not found")
            return
        }
        importOFXItem.click()
        
        // File picker should open
        let openPanel = app.dialogs.firstMatch
        XCTAssertTrue(openPanel.waitForExistence(timeout: 3))
        
        // Cancel the file picker
        let cancelButton = openPanel.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.click()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}
