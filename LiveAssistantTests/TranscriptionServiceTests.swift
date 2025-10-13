//
//  TranscriptionServiceTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Speech
import Testing
@testable import LiveAssistant

/// Tests for the enhanced TranscriptionService with custom vocabulary and smart filtering.
@Suite("TranscriptionService Tests")
struct TranscriptionServiceTests {
    
    // MARK: - Configuration Tests
    
    @Test("Default configuration has expected values")
    func testDefaultConfiguration() {
        let config = TranscriptionConfiguration.default
        
        #expect(config.recognitionMode == .cloudFirst)
        #expect(config.taskHint == .unspecified)
        #expect(config.partialResultConfidenceThreshold == 0.5)
        #expect(config.finalResultConfidenceThreshold == 0.3)
        #expect(config.addsPunctuation == true)
        #expect(config.shouldReportPartialResults == true)
        #expect(!config.customVocabulary.isEmpty)
    }
    
    @Test("High accuracy configuration has higher thresholds")
    func testHighAccuracyConfiguration() {
        let config = TranscriptionConfiguration.highAccuracy
        
        #expect(config.recognitionMode == .cloudOnly)
        #expect(config.partialResultConfidenceThreshold == 0.7)
        #expect(config.finalResultConfidenceThreshold == 0.5)
        #expect(config.partialResultThrottleInterval == 0.5)
    }
    
    @Test("High speed configuration has lower thresholds")
    func testHighSpeedConfiguration() {
        let config = TranscriptionConfiguration.highSpeed
        
        #expect(config.recognitionMode == .cloudOnly)
        #expect(config.partialResultConfidenceThreshold == 0.3)
        #expect(config.finalResultConfidenceThreshold == 0.2)
        #expect(config.partialResultThrottleInterval == 0.1)
    }
    
    @Test("Privacy configuration uses on-device only")
    func testPrivacyConfiguration() {
        let config = TranscriptionConfiguration.privacy
        
        #expect(config.recognitionMode == .onDeviceOnly)
    }
    
    // MARK: - Vocabulary Service Tests
    
    @Test("Vocabulary service loads all categories")
    func testVocabularyServiceLoadsAllCategories() {
        let service = VocabularyService.shared
        
        #expect(!service.allVocabulary.isEmpty)
        #expect(service.allVocabulary.count > 100) // Should have 100+ terms
        
        for category in VocabularyCategory.allCases {
            let vocab = service.vocabulary(for: category)
            #expect(!vocab.isEmpty, "Category \(category) should have vocabulary")
        }
    }
    
    @Test("Vocabulary service includes technical terms")
    func testVocabularyIncludesTechnicalTerms() {
        let service = VocabularyService.shared
        let allTerms = service.allVocabulary
        
        // Test programming languages
        #expect(allTerms.contains("Swift"))
        #expect(allTerms.contains("Python"))
        #expect(allTerms.contains("JavaScript"))
        
        // Test frameworks
        #expect(allTerms.contains("SwiftUI"))
        #expect(allTerms.contains("React"))
        #expect(allTerms.contains("UIKit"))
        
        // Test tools
        #expect(allTerms.contains("Xcode"))
        #expect(allTerms.contains("VSCode"))
        #expect(allTerms.contains("Git"))
        
        // Test cloud services
        #expect(allTerms.contains("AWS"))
        #expect(allTerms.contains("Azure"))
        #expect(allTerms.contains("Firebase"))
        
        // Test concepts
        #expect(allTerms.contains("MVVM"))
        #expect(allTerms.contains("async await") || allTerms.contains("async/await"))
        #expect(allTerms.contains("REST API"))
        
        // Test companies
        #expect(allTerms.contains("Apple"))
        #expect(allTerms.contains("Google"))
        #expect(allTerms.contains("Microsoft"))
    }
    
    @Test("Categorized vocabulary returns all terms")
    func testCategorizedVocabulary() {
        let service = VocabularyService.shared
        let categorized = service.categorizedVocabulary
        
        #expect(categorized.count == VocabularyCategory.allCases.count)
        
        let totalTerms = categorized.values.reduce(0) { $0 + $1.count }
        #expect(totalTerms == service.allVocabulary.count)
    }
    
    // MARK: - Transcription Quality Tests
    
    @Test("Transcription quality from empty results")
    func testTranscriptionQualityFromEmptyResults() {
        let quality = TranscriptionQuality.from(
            results: [],
            recognitionMode: "Cloud",
            startTime: Date(),
            endTime: Date()
        )
        
        #expect(quality.averageConfidence == 0.0)
        #expect(quality.totalSegments == 0)
        #expect(quality.sentenceCompletionRate == 0.0)
    }
    
    @Test("Transcription quality calculates averages correctly")
    func testTranscriptionQualityCalculation() {
        let results = [
            TranscriptionResult(
                text: "Hello world.",
                startTime: 0.0,
                endTime: 1.0,
                confidence: 0.8,
                isFinal: true
            ),
            TranscriptionResult(
                text: "How are you?",
                startTime: 1.0,
                endTime: 2.5,
                confidence: 0.9,
                isFinal: true
            ),
            TranscriptionResult(
                text: "Testing",
                startTime: 2.5,
                endTime: 3.0,
                confidence: 0.7,
                isFinal: false
            )
        ]
        
        let quality = TranscriptionQuality.from(
            results: results,
            recognitionMode: "Cloud-First",
            startTime: Date(),
            endTime: Date()
        )
        
        #expect(quality.totalSegments == 3)
        #expect(quality.finalSegments == 2)
        #expect(quality.partialSegments == 1)
        #expect(abs(quality.averageConfidence - 0.8) < 0.001) // Floating point comparison
        #expect(quality.minimumConfidence == 0.7)
        #expect(quality.maximumConfidence == 0.9)
        #expect(abs(quality.sentenceCompletionRate - (2.0 / 3.0)) < 0.001) // Floating point comparison
    }
    
    @Test("Transcription quality tracks duration correctly")
    func testTranscriptionQualityDuration() {
        let results = [
            TranscriptionResult(
                text: "Test one.",
                startTime: 0.0,
                endTime: 2.0,
                confidence: 0.8,
                isFinal: true
            ),
            TranscriptionResult(
                text: "Test two.",
                startTime: 2.0,
                endTime: 4.0,
                confidence: 0.9,
                isFinal: true
            )
        ]
        
        let quality = TranscriptionQuality.from(
            results: results,
            recognitionMode: "Cloud",
            startTime: Date(),
            endTime: Date()
        )
        
        #expect(quality.averageSegmentDuration == 2.0)
        #expect(quality.totalDuration == 4.0)
    }
    
    // MARK: - Recognition Mode Tests
    
    @Test("Recognition mode enum has all cases")
    func testRecognitionModeEnum() {
        let modes: [RecognitionMode] = [
            .cloudFirst,
            .onDeviceFirst,
            .cloudOnly,
            .onDeviceOnly
        ]
        
        for mode in modes {
            #expect(!mode.rawValue.isEmpty)
        }
    }
    
    // MARK: - Vocabulary Category Tests
    
    @Test("Vocabulary category enum has all cases")
    func testVocabularyCategoryEnum() {
        let categories: [VocabularyCategory] = [
            .programmingLanguages,
            .frameworksLibraries,
            .developmentTools,
            .cloudInfrastructure,
            .conceptsPatterns,
            .companiesProducts
        ]
        
        #expect(categories.count == VocabularyCategory.allCases.count)
        
        for category in categories {
            #expect(!category.rawValue.isEmpty)
        }
    }
    
    // MARK: - Configuration Edge Cases
    
    @Test("Configuration with empty vocabulary")
    func testConfigurationWithEmptyVocabulary() {
        let config = TranscriptionConfiguration(
            recognitionMode: .cloudFirst,
            taskHint: .unspecified,
            partialResultConfidenceThreshold: 0.5,
            finalResultConfidenceThreshold: 0.3,
            partialResultThrottleInterval: 0.3,
            minimumSegmentDuration: 1.5,
            addsPunctuation: true,
            shouldReportPartialResults: true,
            customVocabulary: []
        )
        
        #expect(config.customVocabulary.isEmpty)
    }
    
    @Test("Configuration with custom vocabulary subset")
    func testConfigurationWithCustomVocabulary() {
        let customTerms = ["Swift", "Xcode", "iOS"]
        let config = TranscriptionConfiguration(
            recognitionMode: .cloudFirst,
            taskHint: .unspecified,
            partialResultConfidenceThreshold: 0.5,
            finalResultConfidenceThreshold: 0.3,
            partialResultThrottleInterval: 0.3,
            minimumSegmentDuration: 1.5,
            addsPunctuation: true,
            shouldReportPartialResults: true,
            customVocabulary: customTerms
        )
        
        #expect(config.customVocabulary.count == 3)
        #expect(config.customVocabulary.contains("Swift"))
    }
}

