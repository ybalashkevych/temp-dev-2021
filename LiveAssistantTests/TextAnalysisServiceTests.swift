//
//  TextAnalysisServiceTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Testing

@testable import LiveAssistant

/// Tests for TextAnalysisService demonstrating service testing patterns.
@Suite
struct TextAnalysisServiceTests {
    
    // MARK: - Test Setup
    
    private func createService() -> TextAnalysisService {
        TextAnalysisService()
    }
    
    // MARK: - Text Analysis Tests
    
    @Test
    func analyzePositiveText() async {
        // Arrange
        let service = createService()
        let text = "This is amazing! I love this feature."
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.sentiment == .positive)
        #expect(result.confidence > 0.0)
        #expect(result.confidence <= 1.0)
        #expect(!result.keywords.isEmpty)
    }
    
    @Test
    func analyzeNegativeText() async {
        // Arrange
        let service = createService()
        let text = "This is terrible! I hate this bug."
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.sentiment == .negative)
        #expect(result.confidence > 0.0)
        #expect(result.confidence <= 1.0)
        #expect(!result.keywords.isEmpty)
    }
    
    @Test
    func analyzeNeutralText() async {
        // Arrange
        let service = createService()
        let text = "The weather is okay today."
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.sentiment == .neutral)
        #expect(result.confidence > 0.0)
        #expect(result.confidence <= 1.0)
    }
    
    @Test
    func analyzeEmptyText() async {
        // Arrange
        let service = createService()
        let text = ""
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.sentiment == .neutral)
        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
        #expect(result.keywords.isEmpty)
    }
    
    @Test
    func analyzeWhitespaceText() async {
        // Arrange
        let service = createService()
        let text = "   \n\t   "
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.sentiment == .neutral)
        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
        #expect(result.keywords.isEmpty)
    }
    
    // MARK: - Keyword Extraction Tests
    
    @Test
    func extractKeywordsFromTechnicalText() async {
        // Arrange
        let service = createService()
        let text = "I'm working on a SwiftUI app with Core Data and Combine framework."
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(!result.keywords.isEmpty)
        #expect(result.keywords.contains { $0.lowercased().contains("swift") })
        #expect(result.keywords.contains { $0.lowercased().contains("data") })
    }
    
    @Test
    func extractKeywordsFromLongText() async {
        // Arrange
        let service = createService()
        let text = "This is a very long text about software development, programming, coding, debugging, testing, and deployment. It contains many technical terms and concepts."
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(!result.keywords.isEmpty)
        #expect(result.keywords.count > 0)
    }
    
    // MARK: - Confidence Score Tests
    
    @Test
    func confidenceScoreIsValid() async {
        // Arrange
        let service = createService()
        let text = "I absolutely love this!"
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
    }
    
    @Test
    func confidenceScoreVariesByText() async {
        // Arrange
        let service = createService()
        let clearText = "I absolutely love this!"
        let ambiguousText = "Maybe it's okay."
        
        // Act
        let clearResult = await service.analyze(clearText)
        let ambiguousResult = await service.analyze(ambiguousText)
        
        // Assert
        #expect(clearResult.confidence > ambiguousResult.confidence)
    }
    
    // MARK: - Sentiment Analysis Tests
    
    @Test
    func sentimentAnalysisForDifferentTexts() async {
        // Arrange
        let service = createService()
        
        let positiveTexts = [
            "This is fantastic!",
            "I love it!",
            "Amazing work!",
            "Perfect solution!"
        ]
        
        let negativeTexts = [
            "This is awful!",
            "I hate it!",
            "Terrible work!",
            "This is broken!"
        ]
        
        let neutralTexts = [
            "This is okay.",
            "It works.",
            "The weather is fine.",
            "No comment."
        ]
        
        // Act & Assert - Positive texts
        for text in positiveTexts {
            let result = await service.analyze(text)
            #expect(result.sentiment == .positive)
        }
        
        // Act & Assert - Negative texts
        for text in negativeTexts {
            let result = await service.analyze(text)
            #expect(result.sentiment == .negative)
        }
        
        // Act & Assert - Neutral texts
        for text in neutralTexts {
            let result = await service.analyze(text)
            #expect(result.sentiment == .neutral)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test
    func analyzePerformance() async {
        // Arrange
        let service = createService()
        let text = "This is a test text for performance analysis."
        
        // Act
        let startTime = Date()
        let result = await service.analyze(text)
        let endTime = Date()
        
        // Assert
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 1.0) // Should complete within 1 second
        #expect(result.sentiment != nil)
    }
    
    // MARK: - Edge Cases Tests
    
    @Test
    func analyzeTextWithSpecialCharacters() async {
        // Arrange
        let service = createService()
        let text = "This is a test with special characters: @#$%^&*()_+-=[]{}|;':\",./<>?"
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.sentiment != nil)
        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
    }
    
    @Test
    func analyzeTextWithNumbers() async {
        // Arrange
        let service = createService()
        let text = "I have 123 items and 45.67% success rate."
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.sentiment != nil)
        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
    }
    
    @Test
    func analyzeTextWithEmojis() async {
        // Arrange
        let service = createService()
        let text = "This is great! 😊🎉🚀"
        
        // Act
        let result = await service.analyze(text)
        
        // Assert
        #expect(result.sentiment == .positive)
        #expect(result.confidence > 0.0)
    }
    
    // MARK: - Consistency Tests
    
    @Test
    func analyzeConsistency() async {
        // Arrange
        let service = createService()
        let text = "This is a consistent test text."
        
        // Act
        let result1 = await service.analyze(text)
        let result2 = await service.analyze(text)
        
        // Assert - Results should be consistent
        #expect(result1.sentiment == result2.sentiment)
        #expect(abs(result1.confidence - result2.confidence) < 0.1) // Allow small variance
    }
}