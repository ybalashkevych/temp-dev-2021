//
//  TextAnalysisServiceTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 18/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Testing

@testable import LiveAssistant

/// Tests for TextAnalysisService.
@Suite
struct TextAnalysisServiceTests {
    // MARK: - Question Detection Tests

    @Test
    func detectsQuestionWithQuestionMark() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "How are you?")

        // Assert
        #expect(result.isQuestion == true)
        #expect(result.normalizedText == "How are you?")
    }

    @Test
    func detectsQuestionWithQuestionWords() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act & Assert
        let questions = [
            "what is this",
            "where are we",
            "when does it start",
            "why is that",
            "who are you",
            "how does it work",
            "can you help",
            "would you like",
            "should we go",
            "is this correct",
        ]

        for question in questions {
            let result = await service.analyze(text: question)
            #expect(result.isQuestion == true, "'\(question)' should be detected as a question")
        }
    }

    @Test
    func doesNotDetectStatementAsQuestion() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "This is a statement")

        // Assert
        #expect(result.isQuestion == false)
    }

    // MARK: - Text Normalization Tests

    @Test
    func normalizesTextByAddingPeriod() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "this is a test")

        // Assert
        #expect(result.normalizedText.hasSuffix("."))
        #expect(result.normalizedText.first?.isUppercase == true)
    }

    @Test
    func normalizesQuestionByAddingQuestionMark() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "what is this")

        // Assert
        #expect(result.normalizedText.hasSuffix("?"))
        #expect(result.normalizedText.first?.isUppercase == true)
    }

    @Test
    func preservesExistingPunctuation() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "Hello world!")

        // Assert
        #expect(result.normalizedText == "Hello world!")
    }

    @Test
    func capitalizesFirstLetter() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "hello world")

        // Assert
        #expect(result.normalizedText.hasPrefix("H"))
    }

    // MARK: - Sentence Detection Tests

    @Test
    func detectsSingleSentence() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "This is a single sentence.")

        // Assert
        #expect(result.sentences.count == 1)
        #expect(result.sentences.first == "This is a single sentence.")
    }

    @Test
    func detectsMultipleSentences() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "First sentence. Second sentence. Third sentence.")

        // Assert
        #expect(result.sentences.count == 3)
        #expect(result.sentences[0] == "First sentence.")
        #expect(result.sentences[1] == "Second sentence.")
        #expect(result.sentences[2] == "Third sentence.")
    }

    @Test
    func handlesEmptyText() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "")

        // Assert
        #expect(result.sentences.isEmpty)
        #expect(result.isQuestion == false)
        #expect(result.normalizedText.isEmpty)
    }

    @Test
    func trimsWhitespace() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "  hello world  ")

        // Assert
        #expect(result.text == "hello world")
        #expect(result.normalizedText.hasPrefix("H"))
    }

    // MARK: - Edge Cases

    @Test
    func handlesTextWithOnlyQuestionMark() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "?")

        // Assert
        #expect(result.isQuestion == true)
    }

    @Test
    func handlesVeryShortText() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "Hi")

        // Assert
        #expect(result.text == "Hi")
        #expect(result.normalizedText == "Hi")
        #expect(result.sentences.count == 1)
    }

    @Test
    func handlesTextWithMultipleQuestionMarks() async throws {
        // Arrange
        let service = TextAnalysisService()

        // Act
        let result = await service.analyze(text: "What is this???")

        // Assert
        #expect(result.isQuestion == true)
    }
}
