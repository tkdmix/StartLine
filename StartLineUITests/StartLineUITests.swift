import XCTest

final class StartLineUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app?.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    func testScheduledCompletionAndEditReturn() {
        launch(
            additionalArguments: [
                "-startline-scheduled-seconds", "3",
            ]
        )

        app.buttons["action.focus"].tap()

        XCTAssertTrue(app.staticTexts["0m 00s"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["action.edit"].exists)
        XCTAssertFalse(app.buttons["action.next"].exists)

        app.buttons["action.edit"].tap()

        XCTAssertTrue(app.buttons["action.focus"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Pomodoro"].exists)
    }

    func testPomodoroAndBreakRequireManualContinuation() {
        launch(
            additionalArguments: [
                "-pomodoroDurationMinutes", "25",
                "-startline-pomodoro-seconds", "3",
                "-startline-break-seconds", "1",
            ]
        )

        app.buttons["Pomodoro"].tap()
        app.buttons["action.focus"].tap()

        XCTAssertTrue(app.buttons["action.next"].waitForExistence(timeout: 6))
        XCTAssertEqual(app.staticTexts["countdown.remaining"].label, "0m 00s")

        app.buttons["action.next"].tap()

        XCTAssertFalse(app.buttons["action.next"].exists)
        XCTAssertTrue(app.buttons["action.next"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["countdown.remaining"].label, "0m 00s")

        app.buttons["action.next"].tap()

        XCTAssertTrue(app.buttons["action.edit"].exists)
        XCTAssertFalse(app.buttons["action.next"].exists)
        XCTAssertTrue(app.staticTexts["Pomodoro"].waitForExistence(timeout: 2))
    }

    func testLayoutStatesInPortraitAndBothLandscapeDirections() {
        launch(
            additionalArguments: [
                "-pomodoroDurationMinutes", "25",
                "-startline-pomodoro-seconds", "60",
            ]
        )

        assertEditLayoutAcrossOrientations()

        XCUIDevice.shared.orientation = .portrait
        let pomodoroButton = app.buttons["Pomodoro"]
        XCTAssertTrue(waitUntilHittable(pomodoroButton))
        pomodoroButton.tap()
        XCTAssertEqual(app.staticTexts["countdown.remaining"].label, "25m 00s")
        assertEditLayoutAcrossOrientations()

        app.buttons["action.focus"].tap()
        for orientation in testedOrientations {
            XCUIDevice.shared.orientation = orientation

            XCTAssertTrue(app.staticTexts["StartLine"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.buttons["action.edit"].isHittable)
            XCTAssertTrue(app.staticTexts["countdown.remaining"].exists)
        }
    }

    func testDarkAppearanceCoreStates() {
        launch(
            additionalArguments: [
                "-AppleInterfaceStyle", "Dark",
                "-pomodoroDurationMinutes", "25",
                "-startline-pomodoro-seconds", "3",
            ]
        )

        XCTAssertTrue(app.buttons["Pomodoro"].isHittable)
        app.buttons["Pomodoro"].tap()
        XCTAssertEqual(app.staticTexts["countdown.remaining"].label, "25m 00s")

        app.buttons["action.focus"].tap()
        XCTAssertTrue(app.buttons["action.edit"].waitForExistence(timeout: 2))
    }

    func testScheduledRingPhaseTransitions() {
        launch(
            additionalArguments: [
                "-startline-scheduled-seconds", "65",
            ]
        )

        app.buttons["action.focus"].tap()

        XCTAssertTrue(app.staticTexts["countdown.ring.normal"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["countdown.ring.warning"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["countdown.ring.imminent"].waitForExistence(timeout: 55))
        XCTAssertTrue(app.staticTexts["0m 00s"].waitForExistence(timeout: 12))
    }

    func testSmallCoffeeTipPurchase() {
        launch(
            additionalArguments: [
                "-startline-tip-test-price", "¥200",
                "-startline-tip-test-result", "success",
            ]
        )

        app.buttons["About StartLine"].tap()

        let purchaseButton = app.buttons["tip.purchase"]
        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 5))
        XCTAssertTrue(purchaseButton.label.contains("Small Coffee"))
        XCTAssertTrue(purchaseButton.label.contains("¥200"))

        purchaseButton.tap()

        let status = app.staticTexts["tip.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Thank you for supporting StartLine.")
    }

    func testSmallCoffeeTipPendingAndFailureStates() {
        launchTipTest(result: "pending")
        XCTAssertEqual(
            app.staticTexts["tip.status"].label,
            "Purchase pending approval."
        )

        app.terminate()

        launchTipTest(result: "failure")
        XCTAssertEqual(
            app.staticTexts["tip.status"].label,
            "The purchase couldn’t be completed. Please try again."
        )
    }

    func testSmallCoffeeTipCancellation() {
        launch(
            additionalArguments: [
                "-startline-tip-test-price", "¥200",
                "-startline-tip-test-result", "cancelled",
            ]
        )

        app.buttons["About StartLine"].tap()

        let purchaseButton = app.buttons["tip.purchase"]
        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 5))
        purchaseButton.tap()

        XCTAssertFalse(app.staticTexts["tip.status"].exists)
        XCTAssertTrue(purchaseButton.isHittable)
    }

    func testSmallCoffeeTipUnavailableAndRetry() {
        launch(
            additionalArguments: [
                "-startline-tip-test-price", "¥200",
                "-startline-tip-test-unavailable-once",
            ]
        )

        app.buttons["About StartLine"].tap()

        let retryButton = app.buttons["tip.retry"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tip.purchase"].exists)

        retryButton.tap()

        let purchaseButton = app.buttons["tip.purchase"]
        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 5))
        XCTAssertTrue(purchaseButton.label.contains("Small Coffee"))
        XCTAssertTrue(purchaseButton.label.contains("¥200"))
    }

    func testSmallCoffeeTipLayoutAcrossOrientations() {
        launch(
            additionalArguments: [
                "-startline-tip-test-price", "¥200",
                "-startline-tip-test-result", "success",
            ]
        )

        app.buttons["About StartLine"].tap()

        let purchaseButton = app.buttons["tip.purchase"]
        for orientation in testedOrientations {
            XCUIDevice.shared.orientation = orientation

            for _ in 0..<4 where !purchaseButton.isHittable {
                app.swipeUp()
            }

            XCTAssertTrue(purchaseButton.isHittable)
            XCTAssertTrue(purchaseButton.label.contains("Small Coffee"))
            XCTAssertTrue(purchaseButton.label.contains("¥200"))
        }
    }

    private func launchTipTest(result: String) {
        launch(
            additionalArguments: [
                "-startline-tip-test-price", "¥200",
                "-startline-tip-test-result", result,
            ]
        )

        app.buttons["About StartLine"].tap()

        let purchaseButton = app.buttons["tip.purchase"]
        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 5))
        purchaseButton.tap()
        XCTAssertTrue(app.staticTexts["tip.status"].waitForExistence(timeout: 5))
    }

    private func launch(additionalArguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ] + additionalArguments
        app.launch()

        XCTAssertTrue(app.staticTexts["StartLine"].waitForExistence(timeout: 5))
    }

    private var testedOrientations: [UIDeviceOrientation] {
        [
            .portrait,
            .landscapeLeft,
            .landscapeRight,
        ]
    }

    private func assertEditLayoutAcrossOrientations() {
        for orientation in testedOrientations {
            XCUIDevice.shared.orientation = orientation

            XCTAssertTrue(app.staticTexts["StartLine"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.buttons["Pomodoro"].isHittable)
            XCTAssertTrue(app.buttons["action.focus"].isHittable)
            XCTAssertTrue(app.staticTexts["countdown.remaining"].exists)
        }
    }

    private func waitUntilHittable(
        _ element: XCUIElement,
        timeout: TimeInterval = 3
    ) -> Bool {
        XCTWaiter.wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "isHittable == true"),
                    object: element
                ),
            ],
            timeout: timeout
        ) == .completed
    }
}
