//
//  myskuUITests.swift
//  myskuUITests
//
//  Created by Ulisse Mini on 1/26/25.
//

import XCTest

final class myskuUITests: XCTestCase {
    
    // Declare app as an instance variable
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        // Allow screenshots to be taken even when tests fail
        continueAfterFailure = false
        
        // Initialize and configure the instance variable 'app'
        app = XCUIApplication()
        app.launchArguments = ["-UITests", "-ResetState"]
        app.launchEnvironment = ["UITests": "true"]
        // Note: app.launch() is NOT called here, but in each test.
    }
    
    override func tearDownWithError() throws {
        // Cleanup after test
    }
    
    // MARK: - Test Flows (Example Refactor)
    
    @MainActor
    func testDemoLogin() throws {
        // Launch the app. Due to setUpWithError, it will launch with "-ResetState".
        // Your app's code should handle this argument to ensure a logged-out state.
        app.launch()

        takeScreenshot(app: app, named: "Launch Screen before Login")

        // Perform login
        loginWithDemoMode(app: app)

        // Assert successful login (e.g., map view appears)
        // Replace "MapViewIdentifier" with the actual accessibility identifier of your map view
        let mapView = app.otherElements["MapViewIdentifier"]
        XCTAssertTrue(mapView.waitForExistence(timeout: 5.0), "Map view did not appear after login")
        takeScreenshot(app: app, named: "Map View after Login")
    }
    
    @MainActor
    func testSettingsNavigationAndLogout() throws {
        // Launch the app - ensures clean state (logged out)
        app.launch()

        // --- Precondition: Log in first ---
        // Since the app starts logged out, we need to log in for THIS test.
        loginWithDemoMode(app: app)

        // Wait for settings button to confirm login state
        let settingsButtonInitial = app.buttons["Settings"]
        XCTAssertTrue(settingsButtonInitial.waitForExistence(timeout: 5.0), "Settings button didn't appear after login precondition")
        takeScreenshot(app: app, named: "Logged In before Settings Test")
        // --- End Precondition ---


        // Navigate to settings
        settingsButtonInitial.tap()
        takeScreenshot(app: app, named: "Settings View")

        // Find and tap logout (assuming it's visible now)
        let logoutButton = app.buttons["Logout"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 2.0), "Logout button not found in settings")
        logoutButton.tap()

        // Assert logout was successful (e.g., login button reappears)
        let loginButton = app.buttons["Continue with Discord"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5.0), "Login button did not reappear after logout")
        takeScreenshot(app: app, named: "Login Screen after Logout")
    }
    
    // MARK: - Helper Functions
    
    private func loginWithDemoMode(app: XCUIApplication) {
        // Find login button
        let loginButton = app.buttons["Continue with Discord"]
        if !loginButton.waitForExistence(timeout: 5.0) { // Increased timeout slightly for robustness
            takeScreenshot(app: app, named: "Login Button Not Found")
            XCTFail("Login button not found")
            return // Added return
        }
        
        // Long press to activate demo mode
        loginButton.press(forDuration: 3.5)
        
        // Click Yes on the alert
        let alert = app.alerts["Continue in demo mode?"]
        if !alert.waitForExistence(timeout: 2.0) {
            takeScreenshot(app: app, named: "Demo Mode Alert Not Found")
            XCTFail("Demo mode alert not shown")
            return // Added return
        }
        
        alert.buttons["Yes"].tap()
        
        // Wait for UI to update after demo mode activation (e.g., wait for Settings button)
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5.0), "Settings button did not appear after demo mode activation")
    }
    
    private func takeScreenshot(app: XCUIApplication, named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
