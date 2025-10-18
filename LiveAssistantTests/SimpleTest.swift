//
//  SimpleTest.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Testing

@testable import LiveAssistant

/// Simple test to verify test setup is working.
@Suite("Simple Tests")
struct SimpleTest {
    @Test
    func testBasicFunctionality() {
        #expect(true)
    }

    @Test
    func testStringComparison() {
        let str1 = "Hello"
        let str2 = "Hello"
        #expect(str1 == str2)
    }
}