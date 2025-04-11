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
        app.launchArguments = ["-UITests", "-ResetState", "-AutoDemo"]
        app.launchEnvironment = ["UITests": "true"]
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
        // Check if the Map tab button exists and is selected
        let mapTabButton = app.buttons["Map"] // Tab bar buttons are often identified by their label
        XCTAssertTrue(mapTabButton.waitForExistence(timeout: 5.0), "Map tab button did not appear after login")
        XCTAssertTrue(mapTabButton.isSelected, "Map tab was not selected after login")
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
        
        // Take screenshot of the settings view when first entering
        takeScreenshot(app: app, named: "Settings View Top")
        
        // Do a single long swipe to scroll down to see more sections
        app.swipeUp()
        takeScreenshot(app: app, named: "Settings View Middle")
        
        // Do another swipe to reach the bottom (hopefully showing account section)
        app.swipeUp()
        takeScreenshot(app: app, named: "Settings View Bottom")
        
        // If needed, do one more swipe to ensure we see the account section
        app.swipeUp()
        takeScreenshot(app: app, named: "Settings View Account Section")
        
        // Find the logout button
        let logoutButton = app.buttons["Logout"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 1.0), "Logout button not found in settings")
        
        // Perform logout
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
        if !loginButton.waitForExistence(timeout: 5.0) { // Keep check for robustness
            takeScreenshot(app: app, named: "Login Button Not Found (AutoDemo)")
            XCTFail("Login button not found")
            return
        }

        // Simply tap the button - the app should handle AutoDemo logic
        loginButton.tap()

        // Wait for UI to update after demo mode activation (e.g., wait for Settings button)
        // This confirms the AutoDemo logic worked in the app
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5.0), "Settings button did not appear after AutoDemo activation")
    }
    
    private func takeScreenshot(app: XCUIApplication, named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
