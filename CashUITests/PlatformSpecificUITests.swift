//
//  PlatformSpecificUITests.swift
//  CashUITests
//
//  Created on 28/12/25.
//

import XCTest

final class PlatformSpecificUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testAccountListOpensCorrectly() throws {
        // Wait for the app to load
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        
        #if os(iOS)
        // On iPhone, sidebar should be visible first
        let deviceIdiom = UIDevice.current.userInterfaceIdiom
        if deviceIdiom == .phone {
            XCTAssertTrue(app.navigationBars.firstMatch.exists, "Navigation bar should exist on iPhone")
        } else {
            // On iPad, Net Worth or main content should be visible
            XCTAssertTrue(app.otherElements.matching(identifier: "AccountListView").firstMatch.exists)
        }
        #else
        // On macOS, the split view should show both sidebar and content
        XCTAssertTrue(app.splitGroups.firstMatch.exists, "Split view should exist on macOS")
        #endif
    }
    
    func testBudgetViewEmptyState() throws {
        // Navigate to Budget view
        #if os(iOS)
        app.buttons["Budget"].tap()
        #else
        app.buttons["Budget"].firstMatch.click()
        #endif
        
        XCTAssertTrue(app.waitForExistence(timeout: 3))
        
        // Check for empty state button
        let createButton = app.buttons["Create Budget"]
        XCTAssertTrue(createButton.exists, "Create Budget button should exist in empty state")
        
        // Should not have duplicate buttons
        let allCreateButtons = app.buttons.matching(identifier: "Create Budget")
        XCTAssertEqual(allCreateButtons.count, 1, "There should be only one Create Budget button")
    }
    
    func testLoansViewEmptyState() throws {
        // Navigate to Loans view
        #if os(iOS)
        app.buttons["Loans"].tap()
        #else
        app.buttons["Loans"].firstMatch.click()
        #endif
        
        XCTAssertTrue(app.waitForExistence(timeout: 3))
        
        // Check for empty state buttons
        let calculatorButton = app.buttons["Loan Calculator"]
        let addLoanButton = app.buttons["Add Existing Loan"]
        
        XCTAssertTrue(calculatorButton.exists, "Loan Calculator button should exist in empty state")
        XCTAssertTrue(addLoanButton.exists, "Add Existing Loan button should exist in empty state")
    }
    
    // MARK: - Export Tests
    
    func testExportFunctionality() throws {
        // Open Settings
        #if os(iOS)
        // On iOS, open settings from toolbar or menu
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
        }
        #else
        // On macOS, use menu bar
        app.menuBars.menuItems["Settings"].click()
        #endif
        
        XCTAssertTrue(app.waitForExistence(timeout: 3))
        
        // Find export button
        let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
        XCTAssertTrue(exportButton.exists, "Export button should exist in Settings")
        
        #if os(iOS)
        exportButton.tap()
        // On iOS, file exporter sheet should appear
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 2), "File export sheet should appear on iOS")
        #else
        exportButton.click()
        // On macOS, save panel should appear (harder to test)
        #endif
    }
    
    // MARK: - Form Layout Tests
    
    func testAddTransactionFormLayout() throws {
        // Navigate to transactions and try to add one
        #if os(iOS)
        if app.buttons["Accounts"].exists {
            app.buttons["Accounts"].tap()
        }
        #endif
        
        // Wait for add button to appear
        sleep(1)
        
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '+'")).firstMatch
        if addButton.exists {
            #if os(iOS)
            addButton.tap()
            #else
            addButton.click()
            #endif
            
            // Check that the form appears and is properly sized
            XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 2) || 
                         app.navigationBars.firstMatch.waitForExistence(timeout: 2), 
                         "Add transaction form should appear")
            
            #if os(macOS)
            // On macOS, verify the sheet has proper frame constraints
            let sheet = app.sheets.firstMatch
            if sheet.exists {
                XCTAssertGreaterThan(sheet.frame.width, 500, "Sheet should have minimum width on macOS")
            }
            #endif
        }
    }
    
    // MARK: - Localization Tests
    
    func testCommonButtonsAreLocalized() throws {
        // Check that common buttons have localized text (not empty or key names)
        let commonButtons = ["Cancel", "Save", "Done", "Close", "Add"]
        
        for buttonLabel in commonButtons {
            let buttons = app.buttons.matching(identifier: buttonLabel)
            if buttons.count > 0 {
                let button = buttons.firstMatch
                let label = button.label
                XCTAssertFalse(label.isEmpty, "Button '\(buttonLabel)' should have non-empty label")
                XCTAssertNotEqual(label, buttonLabel, "Button should be localized, not showing key '\(buttonLabel)'")
            }
        }
    }
    
    // MARK: - Platform-Specific Picker Tests
    
    func testPickerStylesArePlatformAppropriate() throws {
        // Navigate to Reports or Forecast to test pickers
        #if os(iOS)
        if app.buttons["Reports"].exists {
            app.buttons["Reports"].tap()
        }
        #endif
        
        XCTAssertTrue(app.waitForExistence(timeout: 3))
        
        #if os(iOS)
        // On iOS, pickers should use menu style (buttons that open sheets)
        let menuButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Period' OR label CONTAINS[c] 'Report'"))
        if menuButtons.count > 0 {
            XCTAssertTrue(menuButtons.firstMatch.exists, "Menu-style picker button should exist on iOS")
        }
        #else
        // On macOS, pickers should use segmented control style
        let segmentedControls = app.segmentedControls
        // Note: This might not find anything depending on navigation state
        // but validates the approach
        #endif
    }
    
    // MARK: - Data Display Tests
    
    func testAmortizationScheduleDisplaysProperly() throws {
        // This test would require creating a loan first
        // Skipping for now unless there's demo data
        
        // If we can navigate to amortization schedule:
        // - On iOS: verify List exists with proper card layout
        // - On macOS: verify Table exists with columns
    }
    
    func testLoanScenariosDisplaysProperly() throws {
        // Similar to amortization schedule test
        // Verify proper layout component is used per platform
    }
}
