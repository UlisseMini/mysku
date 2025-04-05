//
//  myskuUITests.swift
//  myskuUITests
//
//  Created by Ulisse Mini on 1/26/25.
//

import XCTest

final class myskuUITests: XCTestCase {
    
    override func setUpWithError() throws {
        // Allow screenshots to be taken even when tests fail
        continueAfterFailure = false
        
        // Reset app state for clean launch
        let app = XCUIApplication()
        app.launchArguments = ["-UITests", "-ResetUserDefaults"]
        app.launchEnvironment = ["UITests": "true"]
    }
    
    override func tearDownWithError() throws {
        // Cleanup after test
    }
    
    // MARK: - Main Test Flow
    
    @MainActor
    func testFullAppFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Take screenshot of initial launch screen
        takeScreenshot(app: app, named: "Initial Launch Screen")

        // Logout if needed
        logoutIfNeeded(app: app)
        
        // Take screenshot of (what should be) the login screen
        takeScreenshot(app: app, named: "Login screen")
        
        // Login using demo mode
        loginWithDemoMode(app: app)
        
        // Take screenshot after demo mode activation
        takeScreenshot(app: app, named: "After Demo Mode Activation")
        
        // Check for main tab bar
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2.0), "Tab bar not found after login")
        
        // Take screenshot of main screen with tab bar
        takeScreenshot(app: app, named: "Main Screen with Tab Bar")
        
        // Navigate through each tab and take screenshots
        if let tabs = tabBar.buttons.allElementsBoundByIndex as? [XCUIElement] {
            for (index, tab) in tabs.enumerated() {
                // Take screenshot before tab tap
                takeScreenshot(app: app, named: "Before Tab \(index) Tap")
                
                // Tap the tab
                tab.tap()
                
                // Wait for UI to update and take screenshot
                XCTAssertTrue(app.waitForExistence(timeout: 1.0), "UI did not update after tab tap")
                takeScreenshot(app: app, named: "After Tab \(index) Tap")
                
                // Wait for content to load and take final screenshot
                XCTAssertTrue(app.waitForExistence(timeout: 1.0), "Content did not load after tab tap")
                takeScreenshot(app: app, named: "Tab \(index) Content Loaded")
            }
        }
        
        // Final screenshot of the app state
        takeScreenshot(app: app, named: "Final App State")
    }
    
    // MARK: - Helper Functions
    
    private func loginWithDemoMode(app: XCUIApplication) {
        // Find login button
        let loginButton = app.buttons["Continue with Discord"]
        if !loginButton.waitForExistence(timeout: 2.0) {
            // Take screenshot before failing
            takeScreenshot(app: app, named: "Login Button Not Found")
            XCTFail("Login button not found")
            return
        }
        
        // Long press to activate demo mode
        loginButton.press(forDuration: 3.5)
        
        // Click Yes on the alert
        let alert = app.alerts["Continue in demo mode?"]
        if !alert.waitForExistence(timeout: 2.0) {
            // Take screenshot before failing
            takeScreenshot(app: app, named: "Demo Mode Alert Not Found")
            XCTFail("Demo mode alert not shown")
            return
        }
        
        alert.buttons["Yes"].tap()
        
        // Wait for UI to update after demo mode activation
        XCTAssertTrue(app.waitForExistence(timeout: 1.0), "UI did not update after demo mode activation")
    }
    
    private func logoutIfNeeded(app: XCUIApplication) {
        // Look for settings button
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 2.0) {
            settingsButton.tap()
            
            // Look for logout button at the bottom
            let logoutButton = app.buttons["Logout"]
            if logoutButton.waitForExistence(timeout: 2.0) {
                logoutButton.tap()
            } else {
                // If logout button not found, try scrolling to bottom
                let scrollView = app.scrollViews.firstMatch
                if scrollView.exists {
                    scrollView.swipeUp(velocity: .fast)
                    if logoutButton.waitForExistence(timeout: 2.0) {
                        logoutButton.tap()
                    }
                }
            }
        }
    }
    
    private func takeScreenshot(app: XCUIApplication, named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
