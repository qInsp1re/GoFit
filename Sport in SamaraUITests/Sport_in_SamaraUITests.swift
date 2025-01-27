//
//  Sport_in_SamaraUITests.swift
//  Sport in SamaraUITests
//
//  Created by Matvey on 18.10.2023.
//

import XCTest

final class Sport_in_SamaraUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
  }

    override func tearDownWithError() throws {
    
    }

    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
