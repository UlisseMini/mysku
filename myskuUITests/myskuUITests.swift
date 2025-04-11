// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

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
        takeScreenshot(app: app, named: "Map view")
        
        // Find and click settings button
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2.0), "Settings button not found")
        settingsButton.tap()
        
        // Take screenshot after clicking settings
        takeScreenshot(app: app, named: "Settings View")
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
